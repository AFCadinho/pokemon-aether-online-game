#!/usr/bin/env python3
"""Serve the phase-1 export on loopback, without any backend or proxy access."""
from __future__ import annotations

import argparse
import json
import mimetypes
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
POKEMON_ASSET_ROOT = (ROOT / 'assets/sprites/pokemon/gen5').resolve()


class PreviewHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}

    def log_message(self, format, *args):
        # Never log query strings, account data or request payloads.
        pass

    def end_headers(self):
        cache_value = 'public, max-age=31536000, immutable' if urlsplit(self.path).path.startswith('/pokemon-assets/gen5/') else 'no-store'
        self.send_header('Cache-Control', cache_value)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        # Godot's WebAudio mixer uses SharedArrayBuffer-backed worklets.  The
        # export asks the host to opt into this isolated browser context.
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; worker-src 'self' blob:; frame-ancestors 'none'")
        super().end_headers()

    def _json(self, status, value, head=False):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def _serve(self, head=False):
        if urlsplit('//' + self.headers.get('Host', '')).hostname not in {'127.0.0.1', 'localhost', '::1'}:
            self._json(403, {'error': 'Local preview only'}, head)
            return
        path = unquote(urlsplit(self.path).path)
        if path == '/news.json':
            self._json(200, {'items': []}, head)
            return
        if path.startswith('/pokemon-assets/gen5/'):
            relative = path.removeprefix('/pokemon-assets/gen5/')
            target = (POKEMON_ASSET_ROOT / relative).resolve()
            if (not target.is_relative_to(POKEMON_ASSET_ROOT) or target.is_symlink()
                    or not target.is_file() or target.name not in {'animation.json', 'sheet.png'}):
                self.send_error(404)
                return
            body = target.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mimetypes.guess_type(target.name)[0] or 'application/octet-stream')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            if not head:
                self.wfile.write(body)
            return
        if path == '/api/auth/status':
            self._json(200, {
                'available': False, 'mode': 'closed',
                'message': 'Local browser preview: online play will be connected in the next phase.',
            }, head)
            return
        if path == '/api' or path.startswith('/api/'):
            self._json(503, {'error': 'Online play is not connected in this preview'}, head)
            return
        root = Path(self.directory).resolve()
        target = Path(self.translate_path(self.path)).resolve()
        if target.is_dir():
            target = (target / 'index.html').resolve()
        # Do not expose directory listings, dotfiles or symlinks outside export.
        if not target.is_relative_to(root) or any(part.startswith('.') for part in Path(path).parts):
            self.send_error(404)
            return
        if not target.is_file():
            self.send_error(404)
            return
        if head:
            super().do_HEAD()
        else:
            super().do_GET()

    def do_GET(self):
        self._serve()

    def do_HEAD(self):
        self._serve(head=True)

    def do_POST(self):
        self.close_connection = True
        self._json(503, {'error': 'Online play is not connected in this preview'})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8060)
    args = parser.parse_args()
    build = ROOT / 'builds/web'
    if not (build / 'index.html').is_file():
        parser.error('Export Web Local Preview first; builds/web/index.html is missing.')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(PreviewHandler, directory=str(build)))
    print(f'Local web preview: http://127.0.0.1:{server.server_port} (no backend connection)', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
