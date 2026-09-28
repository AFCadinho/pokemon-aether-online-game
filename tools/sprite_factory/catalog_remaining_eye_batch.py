"""Apply the official eye-layer bake to remaining-catalog review GLBs.

Outputs are local diagnostics only. The input receipt pins every original GLB;
unchanged species and any unsupported material are reported separately.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re

from catalog_remaining_eye_bake import repair


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--normal-root', type=Path, required=True)
    parser.add_argument('--shiny-review-root', type=Path, required=True)
    parser.add_argument('--shiny-simple-root', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preserve-original', action='append', default=[],
                        help='Species whose original eyes passed visual review')
    parser.add_argument('--body-albedo', action='append', default=[], metavar='SPECIES:MATERIAL',
                        help='Restore a specified official plain body albedo for visual review')
    args = parser.parse_args()
    source = {row['species']: row for row in json.loads(args.candidates.read_text())['entries']}
    rows = [row for row in json.loads(args.receipt.read_text())['entries']
            if row['status'] == 'normal_shiny_technical_candidate']
    preserved = set(args.preserve_original)
    body_albedo = {}
    for requested in args.body_albedo:
        species, separator, material = requested.partition(':')
        if not separator or not species or not material:
            parser.error('--body-albedo expects SPECIES:MATERIAL')
        body_albedo.setdefault(species, set()).add(material)
    if preserved - {row['species'] for row in rows}:
        parser.error('Preserved species must belong to the 156-pair cohort')
    if body_albedo.keys() - {row['species'] for row in rows}:
        parser.error('Body albedo species must belong to the 156-pair cohort')
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for row in rows:
        species = row['species']
        record = {'species': species, 'status': 'repaired_for_review'}
        try:
            identifier = re.search(r'pm\d{4}', source[species]['source']['member'])[0]
            resource = args.material_root / identifier / f'{identifier}_00_00'
            normal = args.normal_root / f'{row["national_dex"]:04d}-{species}' / 'model.glb'
            shiny = args.shiny_review_root / species / 'model.glb'
            if not shiny.is_file():
                shiny = args.shiny_simple_root / species / 'model.glb'
            if digest(normal) != row['normal_glb_sha256'] or digest(shiny) != row['shiny_glb_sha256']:
                raise ValueError('Original GLB differs from pinned receipt')
            if species in preserved:
                record['status'] = 'retained_original_eye_after_visual_review'
                for variant, glb in [('normal', normal), ('shiny', shiny)]:
                    record[variant] = {'path': str(glb.resolve()), 'sha256': digest(glb),
                                       'eye_materials': [], 'cleared_false_emission': [],
                                       'reason': 'Original eye appearance preferred in visual review'}
                results.append(record)
                (args.output / 'status.json').write_text(json.dumps({
                    'schema': 1, 'runtime_approved': False, 'entries': results}, indent=2) + '\n')
                print(species, record['status'], flush=True)
                continue
            for variant, glb in [('normal', normal), ('shiny', shiny)]:
                table = resource / (f'{identifier}_00_00' +
                                    ('_rare.trmtr' if variant == 'shiny' else '.trmtr'))
                table_sha256 = digest(table)
                target = args.output / species / variant / 'model.glb'
                try:
                    changes = repair(glb, target, table, resource,
                                     body_albedo.get(species, ()))
                except ValueError as error:
                    if str(error) != 'No supported eye or emission material matched the GLB':
                        raise
                    changes = {'eye_materials': [], 'cleared_false_emission': [],
                               'restored_body_albedo': []}
                    target = glb
                record[variant] = {'path': str(target.resolve()),
                                   'sha256': digest(target),
                                   'official_material_sha256': table_sha256, **changes}
            if record['normal']['eye_materials'] != record['shiny']['eye_materials']:
                raise ValueError('Normal/shiny eye material list differs')
            if (record['normal']['path'] == str(normal.resolve()) and
                    record['shiny']['path'] == str(shiny.resolve())):
                record['status'] = 'unchanged_no_matching_eye_material'
        except (KeyError, IndexError, OSError, ValueError, TypeError) as error:
            record = {'species': species, 'status': 'held',
                      'reason': type(error).__name__ + ': ' + str(error)}
        results.append(record)
        (args.output / 'status.json').write_text(json.dumps({
            'schema': 1, 'runtime_approved': False, 'entries': results}, indent=2) + '\n')
        print(species, record['status'], flush=True)
    print('EYE_BATCH', len(results), 'processed,',
          sum(r['status'] == 'repaired_for_review' for r in results), 'repaired,',
          sum(r['status'] == 'held' for r in results), 'held')


if __name__ == '__main__':
    main()
