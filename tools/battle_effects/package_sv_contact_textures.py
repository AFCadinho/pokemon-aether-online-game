#!/usr/bin/env python3
"""Package the inspected contact-move subset without rewriting approved ranged assets."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

SELECTION = {
    'tackle': {
        'ew0033_at_srash01': ['cpt_2_shock0017'],
        'ew0033_df_hit': ['cpt_2_shock0008', 'cpt_0_circle0007'],
    },
    'scratch': {
        'ew0010_hit': ['cpt_0_blur1601', 'cpt_2_shock0001', 'cpt_3_flow0017'],
    },
    'bite': {
        'ew0044_tooth': ['cpt_0_circle0001'],
        'ew0044_df_hit': ['cpt_0_shock0001', 'cpt_0_flash0602'],
    },
}


def package(source, output):
    output.mkdir(parents=True, exist_ok=True)
    report = {'conversion': 'source-textures-with-authored-3d-motion', 'native_timeline_converted': False,
              'native_bite_mesh_converted': False, 'moves': {}}
    for move, parts in SELECTION.items():
        folder = source / move
        manifest = json.loads((folder / 'manifest.json').read_text())
        if manifest['move'] != move or manifest['conversion'] != 'partial-textures-and-colors':
            raise ValueError('Expected inspected extraction for ' + move)
        records = []
        for part, names in parts.items():
            for name in names:
                if name not in manifest['parts'][part]['textures']:
                    raise ValueError('Missing inspected texture ' + name)
                path = folder / part / (name + '.png')
                image = Image.open(path)
                image.save(output / path.name)
                records.append({'file': path.name, 'source_particle': part + '.ptcl',
                                'source_sha256': manifest['parts'][part]['source_sha256'],
                                'png_sha256': hashlib.sha256((output / path.name).read_bytes()).hexdigest(),
                                'size': image.size, 'mode': image.mode})
        report['moves'][move] = records
    (output / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PACKAGED_CONTACT_TEXTURES count=9')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.source, args.output)
