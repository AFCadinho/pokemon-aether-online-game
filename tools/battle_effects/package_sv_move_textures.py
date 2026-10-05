#!/usr/bin/env python3
"""Package the explicitly selected Ember/Water Gun textures, with provenance.

Input is the output of extract_sv_ember.py, never an unchecked game archive.
The PNGs are small tracked game assets, not external runtime dependencies.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

SELECTION = {
    'ember': {
        'ew0052_fire_muzzle': ['cpt_2_fire0005'],
        'ew0052_bullet': ['cpt_2_fire0010', 'cpt_2_dust0702'],
        'ew0052_hit': ['cpt_2_fire0004'],
    },
    'watergun': {
        'ew0055_shot01': ['cpt_2_fire0007', 'cpt_2_water0009', 'cpt_3_smoke0207'],
        'ew0055_hit01': ['cpt_2_water0013'],
    },
}


def package(ember, watergun, output):
    report = {'conversion': 'source-textures-with-authored-motion', 'moves': {}}
    output.mkdir(parents=True, exist_ok=True)
    for move, folder in [('ember', ember), ('watergun', watergun)]:
        source = json.loads((folder / 'manifest.json').read_text())
        assert source['move'] == move and source['conversion'] == 'partial-textures-and-colors'
        records = []
        for part, names in SELECTION[move].items():
            for name in names:
                assert name in source['parts'][part]['textures']
                path = folder / part / (name + '.png')
                image = Image.open(path)
                image.save(output / path.name)
                records.append({'file': path.name, 'source_particle': part + '.ptcl',
                                'source_sha256': source['parts'][part]['source_sha256'],
                                'png_sha256': hashlib.sha256((output / path.name).read_bytes()).hexdigest(),
                                'size': image.size, 'mode': image.mode})
        report['moves'][move] = records
    (output / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PACKAGED_SV_MOVE_TEXTURES count=8 bytes=' + str(sum(p.stat().st_size for p in output.glob('*.png'))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ember', type=Path, required=True)
    parser.add_argument('--watergun', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.ember, args.watergun, args.output)
