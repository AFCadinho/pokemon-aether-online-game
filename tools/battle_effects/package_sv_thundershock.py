#!/usr/bin/env python3
"""Package the inspected Thunder Shock subset; approved move assets stay untouched."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

SELECTION = {'ew0084_thunder': ['cpt_3_mask0602'],
             'ew0084_thunder_hit': ['cpt_2_thunder0702', 'cpt_0_circle0005']}


def package(source, output):
    manifest = json.loads((source / 'manifest.json').read_text())
    if manifest['move'] != 'thundershock' or manifest['conversion'] != 'partial-textures-and-colors':
        raise ValueError('Expected inspected Thunder Shock extraction')
    report = {'conversion': 'source-textures-with-authored-3d-motion',
              'native_timeline_converted': False, 'native_simulation_converted': False, 'textures': []}
    output.mkdir(parents=True, exist_ok=True)
    for part, names in SELECTION.items():
        for name in names:
            if name not in manifest['parts'][part]['textures']:
                raise ValueError('Missing source binding ' + name)
            image = Image.open(source / part / (name + '.png'))
            if image.mode != 'L':
                raise ValueError('Selected electric masks must be single channel')
            path = output / (name + '.png')
            image.save(path)
            report['textures'].append({'file': path.name, 'source_particle': part + '.ptcl',
                'source_sha256': manifest['parts'][part]['source_sha256'],
                'png_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'size': image.size, 'mode': image.mode})
    (output / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PACKAGED_THUNDERSHOCK_TEXTURES count=3')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.source, args.output)
