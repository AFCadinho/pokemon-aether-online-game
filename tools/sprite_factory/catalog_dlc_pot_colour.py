"""Restore source black/green pot paint lost in static shader-shadow baking.

Only UV pixels whose source pair changes dark paint to green are replaced.
All other baked detail, alpha, response maps, geometry and motion are retained.
"""
from io import BytesIO
import hashlib
import json
from pathlib import Path

from PIL import Image
from catalog_remaining_eye_bake import append_png, chunks, write_glb
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(evidence, sources):
    rows = json.loads((evidence / 'runtime-flat-v2/report.json').read_text())
    intake = json.loads(Path(__file__).with_name('catalog_remaining_final_dlc_intake.json').read_text())['entries']
    checkpoint = json.loads(Path(__file__).with_name('catalog_remaining_dlc_material_checkpoint.json').read_text())
    pins = {r['species']: r for r in checkpoint['entries']}
    result = []
    for row in rows:
        species = row['species'].removesuffix('-shiny')
        if species not in ('poltchageist', 'sinistcha'):
            continue
        source = Path(row['path'])
        assert sha(source) == row['glb_sha256']
        model = sources / next(x['models'][0] for x in intake if x['species'] == species)
        normal = model.with_suffix('.trmtr')
        rare = normal.with_stem(normal.stem + '_rare')
        for variant_name, table in [('normal', normal), ('shiny', rare)]:
            if sha(table) != pins[species]['variants'][variant_name]['material_table_sha256']:
                raise ValueError('Pinned source material table changed')
        tables = [{r['name']: r for r in inspect_materials(t)} for t in (normal, rare)]
        variant = int(row['species'].endswith('-shiny'))
        doc, buffer = chunks(source)
        binary = bytearray(buffer)
        fixes = []
        for material in doc['materials']:
            if not material['name'].startswith('body_'):
                continue
            records = [t[material['name']] for t in tables]
            paths = [model.parent / Path(r['textures']['BaseColorMap']).with_suffix('.png').name for r in records]
            if paths[0] == paths[1]:
                continue
            original = material['pbrMetallicRoughness']['baseColorTexture']
            if original.get('extensions') or original.get('texCoord', 0) != 0:
                raise ValueError('Pot correction requires unchanged native UV0')
            texture = doc['textures'][original['index']]
            image = doc['images'][texture['source']]
            view = doc['bufferViews'][image['bufferView']]
            start = view.get('byteOffset', 0)
            baked = Image.open(BytesIO(buffer[start:start + view['byteLength']])).convert('RGBA')
            raw = [Image.open(p).convert('RGB').resize(baked.size, Image.Resampling.BILINEAR) for p in paths]
            colours = [list(im.get_flattened_data()) for im in raw]
            pixels = list(baked.get_flattened_data())
            count = 0
            for i, (a, b) in enumerate(zip(*colours)):
                if max(a) < 100 and b[1] > b[0] + 5 and b[1] > b[2] + 5 and b[1] > a[1] + 4:
                    pixels[i] = (*colours[variant][i], pixels[i][3])
                    count += 1
            if not count:
                continue
            corrected = Image.new('RGBA', baked.size)
            corrected.putdata(pixels)
            encoded = BytesIO()
            corrected.save(encoded, format='PNG')
            material['pbrMetallicRoughness']['baseColorTexture'] = {
                **original, 'index': append_png(doc, binary, encoded.getvalue(), material['name'] + '_source_pot_paint', texture.get('sampler', 0))}
            fixes.append({'material': material['name'], 'source_paint_pixels': count,
                          'normal_source': str(paths[0]), 'normal_sha256': sha(paths[0]),
                          'rare_source': str(paths[1]), 'rare_sha256': sha(paths[1])})
        if not fixes:
            raise ValueError('No source pot paint recovered')
        output = evidence / 'pot-colour-v1' / row['species'] / 'model.glb'
        if output.exists():
            raise ValueError('Retain previous correction evidence')
        output.parent.mkdir(parents=True)
        write_glb(output, doc, binary)
        parity = compare(source, output)
        receipt = {'previous_glb_sha256': row['glb_sha256'], 'glb_sha256': sha(output),
                   'geometry_motion_signature': parity, 'source_paint_fixes': fixes,
                   'normal_table_sha256': sha(normal), 'rare_table_sha256': sha(rare)}
        output.with_name('receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        result.append({**row, 'path': str(output), 'glb_sha256': sha(output), 'pot_colour': receipt})
        print('SOURCE_POT_COLOUR', row['species'], flush=True)
    (evidence / 'pot-colour-v1/stage.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    args = parser.parse_args()
    run(args.evidence_root.resolve(), args.source_root.resolve())
