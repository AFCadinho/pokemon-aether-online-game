"""Run the native asset HTTP/cache/media test against a local fixture only."""
import argparse
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    counts = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            counts[self.path] = counts.get(self.path, 0) + 1
            self.send_response(404 if self.path == '/missing' else 200)
            body = b'x' * 128 if self.path == '/large' else b'fixture-body'
            if self.path == '/mobile-assets/catalog.json':
                body = json.dumps({
                    'cry with space.ogg': {'sha256': hashlib.sha256(b'fixture-body').hexdigest(), 'size': 12},
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
    if result.returncode or counts.get('/asset') != 1:
        raise SystemExit(f'Mobile asset check failed: exit={result.returncode}, requests={counts}')
    print('PASS mobile HTTP coalescing: one download across concurrent callers and restart')


if __name__ == '__main__':
    main()
