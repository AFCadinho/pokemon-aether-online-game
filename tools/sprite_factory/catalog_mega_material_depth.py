"""Restore the native material opacity policy on review-only Mega exports."""
import argparse
import copy
import json
from pathlib import Path

from catalog_remaining_eye_bake import chunks, write_glb
from scvi_material_probe import inspect_materials
from phase5_variant_parity import signature


def apply(document, rows):
    source = {row['name']: row for row in rows}
    receipts = []
    for material in document['materials']:
        row = source[material['name']]
        previous = material.get('alphaMode', 'OPAQUE')
        if row['alpha_type'] != 'Opaque':
            # Native translucent/additive surfaces need their separate effect
            # policies; they must never be made opaque by this correction.
            continue
        tested = any(s['values'].get('EnableAlphaTest') == 'True'
                     for s in row['shaders'])
        mode = 'MASK' if tested else 'OPAQUE'
        material['alphaMode'] = mode
        if tested:
            cutoff = row['floats'].get('DiscardValue')
            if cutoff is None or not 0 <= cutoff <= 1:
                raise ValueError('Missing native alpha-test cutoff')
            material['alphaCutoff'] = cutoff
        else:
            material.pop('alphaCutoff', None)
        receipts.append({'material': material['name'], 'before': previous,
                         'after': mode, 'source_alpha_type': row['alpha_type']})
    return receipts


def repair(source, target, table):
    original_signature = signature(source)
    document, binary = chunks(source)
    records = apply(document, inspect_materials(table))
    write_glb(target, document, binary)
    if signature(target) != original_signature:
        raise ValueError('Opacity correction changed mesh, UV, skin or animation data')
    return records


def main():
    from catalog_mega_3d_production import sha, write
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    batch = json.loads(args.status.read_text())
    corrected = []
    for old in batch['entries']:
        row = copy.deepcopy(old)
        row.pop('runtime_scenes', None)
        row['status'] = 'export_candidate'
        row['material_depth_correction'] = {}
        for variant, model in row['variants'].items():
            source = Path(model['path']); table = Path(model['table'])
            if sha(source) != model['sha256'] or sha(table) != model['table_sha256']:
                raise ValueError('Pinned model or table changed')
            target = output / row['showdown_id'] / variant / 'model.glb'
            records = repair(source, target, table)
            model.update(path=str(target), sha256=sha(target))
            row['material_depth_correction'][variant] = records
        corrected.append(row)
        write(output / 'status.json', {**batch, 'entries': corrected,
              'processed': len(corrected), 'runtime_candidates': 0,
              'export_candidates': len(corrected)})
        print(row['showdown_id'], 'opacity_corrected', flush=True)


if __name__ == '__main__':
    main()
