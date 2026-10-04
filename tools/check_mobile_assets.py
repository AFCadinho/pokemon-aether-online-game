"""Run the native asset HTTP/cache/media test against a local fixture only."""
import argparse
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import struct
import threading
import zlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    counts = {}

    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))

    icon = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 20, 20, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\xff\0\0\xff' * 20) * 20))
            + chunk(b'IEND', b''))
    payload = {
        'cry with space.ogg': b'fixture-body',
        'home-icons/catalog.json': json.dumps({'normal': {'Pikachu': 'home-icons/icon.png'}, 'shiny': {}}).encode(),
        'home-icons/icon.png': icon,
    }

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            counts[self.path] = counts.get(self.path, 0) + 1
            self.send_response(404 if self.path == '/missing' else 200)
            body = b'x' * 128 if self.path == '/large' else b'fixture-body'
            if self.path.removeprefix('/') in payload:
                body = payload[self.path.removeprefix('/')]
            if self.path == '/mobile-assets/catalog.json':
                body = json.dumps({
                    **{name: {'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}
                       for name, data in payload.items()},
                    'oversized.ogg': {'sha256': 'a' * 64, 'size': 65 * 1024 * 1024},
                }).encode()
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    env = os.environ.copy()
    env['POKEAETHER_MOBILE_FIXTURE_ORIGIN'] = f'http://127.0.0.1:{server.server_port}'
    try:
        result = subprocess.run([args.godot, '--headless', '--path', '.', '--script',
                                 'res://tests/mobile_asset_http_check.gd'],
                                cwd=Path(__file__).resolve().parents[1], env=env, timeout=60)
    finally:
        server.shutdown()
        server.server_close()
    if result.returncode or any(counts.get(path) != 1 for path in (
            '/asset', '/mobile-assets/catalog.json', '/home-icons/catalog.json', '/home-icons/icon.png')):
        raise SystemExit(f'Mobile asset check failed: exit={result.returncode}, requests={counts}')
    print('PASS mobile HTTP coalescing and HOME catalog/image downloads across restart')


if __name__ == '__main__':
    main()
