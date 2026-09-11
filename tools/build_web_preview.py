#!/usr/bin/env python3
"""Build the web client; run through ops/worktrees/slot-env SLOT."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MAX_INITIAL_BYTES = 300 * 1024 * 1024


def pack_contains(path: Path, marker: bytes) -> bool:
    overlap = b''
    with path.open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            haystack = overlap + chunk
            if marker in haystack:
                return True
            overlap = haystack[-max(0, len(marker) - 1):]
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    if ROOT.parent.name.startswith('slot-') and os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Run slot builds through ops/worktrees/slot-env SLOT -- COMMAND.')
    output = ROOT / 'builds/web'
    output.mkdir(parents=True, exist_ok=True)
    console_log = output / 'export-console.log'
    with console_log.open('w') as console:
        result = subprocess.run([
            args.godot, '--headless', '--log-file', str(output / 'export.log'), '--path', str(ROOT), '--export-release',
            'Web Local Preview', str(output / 'index.html'),
        ], stdout=console, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        tail = console_log.read_text(errors='replace').splitlines()[-80:]
        raise RuntimeError('Godot web export failed:\n' + '\n'.join(tail))
    files = []
    for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
        path = output / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f'Export is incomplete: missing {name}')
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        files.append({'name': name, 'bytes': path.stat().st_size, 'sha256': digest})
    pck_path = output / 'index.pck'
    required_markers = (
        b'generated/tiled_visuals/route_1/route_1.visual.tscn',
        b'assets/sprites/pokemon/pokemon_home/Pikachu.png',
    )
    forbidden_markers = (
        b'assets/sprites/pokemon/gen5/front/pikachu/sheet.png.import',
        b'generated/tiled_visuals/pewter_city/pewter_city.visual.tscn.remap',
    )
    for marker in required_markers:
        if not pack_contains(pck_path, marker):
            raise RuntimeError(f'Web pack misses required asset marker: {marker.decode()}')
    for marker in forbidden_markers:
        if pack_contains(pck_path, marker):
            raise RuntimeError(f'Web pack contains excluded asset marker: {marker.decode()}')

    initial_bytes = sum(item['bytes'] for item in files)
    if initial_bytes > MAX_INITIAL_BYTES:
        raise RuntimeError(
            f'Web build is {initial_bytes / 1048576:.1f} MiB; '
            f'the phase-5 budget is {MAX_INITIAL_BYTES / 1048576:.0f} MiB.'
        )
    receipt = {
        'phase': 7, 'accounts': True, 'onlineGameplay': True,
        'chat': True, 'aiSparring': True, 'ranked': False,
        'dynamicPokemonSprites': True,
        'assetProfile': 'demo-maps-full-player-static-home-battle',
        'maxInitialBytes': MAX_INITIAL_BYTES,
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True).strip()),
        'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
        'files': files,
        'initialBytes': initial_bytes,
    }
    (output / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(f"Web preview exported: {receipt['initialBytes'] / 1048576:.1f} MiB before HTTP compression.")
    print('Serve with: python3 tools/serve_web_preview.py')


if __name__ == '__main__':
    main()
