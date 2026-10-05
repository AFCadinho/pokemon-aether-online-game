#!/usr/bin/env python3
"""Package the inspected fire/bubble subset without modifying other move assets."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

SELECTION = {
    'flamethrower': {'ew0053_fire': ['cpt_2_fire0007s', 'cpt_3_flow0703s'],
                    'ew0053_fire_muzzle': ['cpt_2_fire0005', 'cpt_2_fire0008']},
    'bubblebeam': {'ew0061_at_start': ['cpt_0_bubble0202'],
                   'ew0061_beam_bubble': ['cpt_2_bubble0003'],
                   'ew0061_df_hit': ['cpt_2_water0009']},
}


def package(source, output):
    manifest = json.loads((source / 'manifest.json').read_text())
    move = manifest['move']
    if move not in SELECTION or manifest['conversion'] != 'partial-textures-and-colors':
        raise ValueError('Expected inspected fire/bubble extraction')
    report = {'source_move': move, 'conversion': 'source-textures-with-authored-3d-motion',
              'native_timeline_converted': False, 'native_simulation_converted': False, 'textures': []}
    output.mkdir(parents=True, exist_ok=True)
    for part, names in SELECTION[move].items():
        for name in names:
            if name not in manifest['parts'][part]['textures']:
                raise ValueError('Missing source binding ' + name)
            with Image.open(source / part / (name + '.png')) as image:
                expected = 'RGBA' if 'bubble' in name else 'L'
                if image.mode != expected:
                    raise ValueError('Unexpected decoded mask mode')
                path = output / (name + '.png')
                image.save(path)
                report['textures'].append({'file': path.name, 'source_particle': part + '.ptcl',
                    'source_sha256': manifest['parts'][part]['source_sha256'],
                    'png_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'size': image.size, 'mode': image.mode})
    (output / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PACKAGED_%s_TEXTURES count=%d' % (move.upper(), len(report['textures'])))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.source, args.output)
