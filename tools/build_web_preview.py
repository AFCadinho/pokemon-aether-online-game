#!/usr/bin/env python3
"""Build phase 1 of the web client; run through ops/worktrees/slot-env SLOT."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    if ROOT.parent.name.startswith('slot-') and os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Run slot builds through ops/worktrees/slot-env SLOT -- COMMAND.')
    output = ROOT / 'builds/web'
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        args.godot, '--headless', '--log-file', str(output / 'export.log'), '--path', str(ROOT), '--export-release',
        'Web Local Preview', str(output / 'index.html'),
    ], check=True)
    files = []
    for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
        path = output / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f'Export is incomplete: missing {name}')
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        files.append({'name': name, 'bytes': path.stat().st_size, 'sha256': digest})
    receipt = {
        'phase': 1, 'onlineGameplay': False,
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True).strip()),
        'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
        'files': files,
        'initialBytes': sum(item['bytes'] for item in files),
    }
    (output / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(f"Web preview exported: {receipt['initialBytes'] / 1048576:.1f} MiB before HTTP compression.")
    print('Serve with: python3 tools/serve_web_preview.py')


if __name__ == '__main__':
    main()
