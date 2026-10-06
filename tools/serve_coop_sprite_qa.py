#!/usr/bin/env python3
"""Serve allowlisted local Pokémon sprites for the co-op platform diagnostic."""
import argparse
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
SPECIES = ('pikachu', 'bulbasaur', 'geodude', 'golbat', 'pidgey', 'charmander', 'rattata', 'squirtle')
COLD = {'bulbasaur', 'golbat', 'charmander', 'squirtle'}
VERSION = '0123456789ab'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8091)
    parser.add_argument('--delay', type=float, default=6.0)
    parser.add_argument('--log', type=Path, required=True)
    args = parser.parse_args()
    icons = {}
    for species in SPECIES:
        for style, directory, name in [('normal', 'pokemon_home', species.capitalize()), ('shiny', 'pokemon_home_shiny', species)]:
            path = ROOT / 'assets/sprites/pokemon' / directory / (name + '.png')
            if not path.is_file():
                raise FileNotFoundError(path)
            icons[f'home-icons/{style}/{species}.png'] = path
    catalog = {name: {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'size': path.stat().st_size}
               for name, path in icons.items()}
    pattern = re.compile(r'^/qa-sprites/(front|back|shiny_front|shiny_back)-' + VERSION + r'/(' + '|'.join(SPECIES) + r')/(animation\.json|sheet\.png)$')
    args.log.parent.mkdir(parents=True, exist_ok=True)
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            status, content, mime = 200, b'', 'application/json'
            delay = 0
            if self.path == '/mobile-assets/catalog.json':
                content = json.dumps(catalog).encode()
            elif self.path.lstrip('/') in icons:
                content = icons[self.path.lstrip('/')].read_bytes()
                mime = 'image/png'
            elif match := pattern.fullmatch(self.path):
                side, species, name = match.groups()
                path = ROOT / 'assets/sprites/pokemon' / side / species / name
                if path.is_file():
                    content = path.read_bytes()
                    mime = 'image/png' if name.endswith('.png') else 'application/json'
                    delay = args.delay if species in COLD and name == 'animation.json' else 0
                else:
                    status = 404
            else:
                status = 404
            with lock, args.log.open('a') as log:
                log.write(json.dumps({'path': self.path, 'status': status, 'bytes': len(content), 'delay': delay}) + '\n')
            if delay:
                time.sleep(delay)
            self.send_response(status)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)

    print(f'Co-op sprite QA listening on http://127.0.0.1:{args.port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
