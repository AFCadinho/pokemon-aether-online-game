"""Produce review-only SCVI pairs from the 21 remaining material holds.

The other 17 use ZA materials on an older mesh with different material/UV
bindings. They remain individual holds until a matching ZA mesh is exported.
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys

from catalog_remaining_eye_bake import chunks
from catalog_shiny_151_material_probe import rebuild
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials


SCVI = ('slugma', 'magcargo', 'meowstic-male', 'trevenant')
ZA = ('pidgey', 'farfetchd', 'cubone', 'marowak', 'staryu', 'mawile',
      'manectric', 'sharpedo', 'absol', 'purrloin', 'munna', 'audino',
      'cofagrigus', 'trubbish', 'vanilluxe', 'emolga', 'stunfisk')
ALIASES = {
    'meowstic-male': {'eye_c.001': 'eye_c', 'eye_d.001': 'eye_d'},
    'trevenant': {'eye_a': 'eye', 'eye_b': 'eye'},
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_glb(root, row):
    for folder in ('.tmp/catalog-remaining-normal', '.tmp/catalog-remaining-normal-legacy7',
                   '.tmp/remaining-catalog-intake/rig-recovered-normal'):
        path = root / folder / f"{row['national_dex']:04d}-{row['species']}" / 'model.glb'
        if path.is_file() and digest(path) == row['source']['normal_glb_sha256']:
            return path
    raise ValueError('pinned normal source GLB missing or changed')


def verify_aliases(name, glb):
    doc, _ = chunks(glb)
    mats = {m['name']: m for m in doc['materials']}
    for original, alias in ALIASES.get(name, {}).items():
        material = mats[original]
        tex = doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
        image = doc['images'][tex['source']]['name'].lower()
        if name == 'meowstic-male':
            if f"{alias.removesuffix('_c').removesuffix('_d')}_alb" not in image and 'eye_alb' not in image:
                raise ValueError(original + ': unexpected original eye texture')
        elif name == 'trevenant' and not ('eye_a_alb' in image or 'eye_b_alb' in image):
            raise ValueError(original + ': unexpected original eye texture')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True, exist_ok=False)
    inventory = {r['species']: r for r in json.loads(args.inventory.read_text())['entries']}
    results = []
    for name in SCVI + ZA:
        row = inventory[name]
        result = {'species': name, 'national_dex': row['national_dex'],
                  'resource_id': row['resource_id'], 'runtime_approved': False}
        try:
            source = source_glb(root, row)
            result['source'] = str(source)
            result['source_sha256'] = digest(source)
            if name in ZA:
                result['status'] = 'held'
                result['reason'] = 'ZA material bindings do not match this older normal mesh; matching ZA geometry or a verified UV/material remap is required'
                normal, _ = chunks(source)
                result['exported_materials'] = [m['name'] for m in normal['materials']]
                result['za_tables'] = row['za_tables']
            else:
                verify_aliases(name, source)
                ident = row['resource_id']
                directory = args.material_root / ident / (ident + '_00_00')
                tables = {variant: directory / (ident + '_00_00' + ('_rare' if variant == 'shiny' else '') + '.trmtr')
                          for variant in ('normal', 'shiny')}
                if name in ('slugma', 'magcargo'):
                    normal_eyes = {r['name']: r for r in inspect_materials(tables['normal']) if r['name'] in ('l_eye', 'r_eye')}
                    shiny_eyes = {r['name']: r for r in inspect_materials(tables['shiny']) if r['name'] in ('l_eye', 'r_eye')}
                    for eye in ('l_eye', 'r_eye'):
                        if (normal_eyes[eye]['shaders'] != shiny_eyes[eye]['shaders'] or
                                normal_eyes[eye]['textures'].get('OpacityMap1') !=
                                shiny_eyes[eye]['textures'].get('OpacityMap1')):
                            raise ValueError('authored eye opacity differs between normal and rare')
                result['variants'] = {}
                for variant, table in tables.items():
                    target = args.output / name / variant / 'model.glb'
                    records = rebuild(source, target, table,
                                      aliases=ALIASES.get(name),
                                      opaque_eye_exceptions=('l_eye', 'r_eye') if name in ('slugma', 'magcargo') else ())
                    result['variants'][variant] = {'path': str(target.resolve()),
                                                   'sha256': digest(target),
                                                   'table': str(table), 'table_sha256': digest(table),
                                                   'materials': records}
                result['geometry_motion_sha256'] = compare(
                    args.output / name / 'normal/model.glb',
                    args.output / name / 'shiny/model.glb')
                if result['variants']['normal']['sha256'] == result['variants']['shiny']['sha256']:
                    raise ValueError('no visible normal/rare difference')
                result['status'] = 'review_candidate'
        except (OSError, ValueError, KeyError, IndexError) as exc:
            result['status'] = 'held'
            result['reason'] = str(exc)
        results.append(result)
        print(name, result['status'], result.get('reason', ''), flush=True)
    (args.output / 'status.json').write_text(json.dumps({'schema': 1, 'runtime_approved': False,
                                                        'entries': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
