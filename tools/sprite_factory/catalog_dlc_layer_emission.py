"""Restore source-mask emission omitted by the SCVI importer's parallax graph.

Static review only: native parallax animation and Fresnel remain unqualified.
Opaque source surfaces also retain their native opacity classification.
"""
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_bake import chunks, append_png, write_glb, linear_to_srgb
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials


def restore(path, target, table):
    doc, binary = chunks(path)
    rows = {r['name']: r for r in inspect_materials(table)}
    binary = bytearray(binary)
    receipts = []
    for material in doc['materials']:
        row = rows[material['name']]
        if row['alpha_type'] == 'Opaque':
            material['alphaMode'] = 'OPAQUE'
            material.pop('alphaCutoff', None)
            material['pbrMetallicRoughness'].setdefault('baseColorFactor', [1, 1, 1, 1])[3] = 1
        shaders = {s['name'] for s in row['shaders']}
        if not shaders & {'Eye', 'EyeClearCoat', 'InsideEmissionParallax'}:
            continue
        powers = [row['floats'].get(f'EmissionIntensityLayer{i}', 0) for i in range(1, 5)]
        if not any(powers):
            continue
        mask_path = table.parent / Path(row['textures']['LayerMaskMap']).with_suffix('.png').name
        mask = Image.open(mask_path).convert('RGBA')
        peak = max([1.0] + [max(row['colors'][f'EmissionColorLayer{i}'][:3]) * power
                           for i, power in enumerate(powers, 1) if power])
        glow = Image.new('RGB', mask.size)
        for i, (channel, power) in enumerate(zip(mask.split(), powers), 1):
            colour = row['colors'].get(f'EmissionColorLayer{i}', [0, 0, 0, 1])
            layer = Image.new('RGB', mask.size, tuple(linear_to_srgb(v * power / peak) for v in colour[:3]))
            scale = row['floats'].get(f'LayerMaskScale{i}', 1)
            glow = Image.composite(layer, glow, channel.point(lambda v: min(255, round(v * 2 * scale))))
        packed = BytesIO()
        glow.save(packed, format='PNG')
        old = material['pbrMetallicRoughness']['baseColorTexture']
        sampler = doc['textures'][old['index']].get('sampler', 0)
        index = append_png(doc, binary, packed.getvalue(), material['name'] + '_source_layer_emission', sampler)
        # Native layer-mask UVs repeat over raw UV0. Do not inherit the
        # unrelated full-graph atlas transform or generated diffuse UV1.
        material['emissiveTexture'] = {'index': index}
        material['emissiveFactor'] = [1, 1, 1]
        material.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': peak}
        if 'KHR_materials_emissive_strength' not in doc.setdefault('extensionsUsed', []):
            doc['extensionsUsed'].append('KHR_materials_emissive_strength')
        receipts.append({'material': material['name'], 'mask_sha256': hashlib.sha256(mask_path.read_bytes()).hexdigest(),
                         'strength': peak, 'policy': 'static source-mask emission; parallax not reconstructed'})
    target.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, doc, binary)
    compare(path, target)
    return receipts


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--intake', type=Path, required=True)
    p.add_argument('--source-root', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    intake = json.loads(args.intake.read_text())
    models = {r['species']: r['models'][0] for r in json.loads(Path(__file__).with_name('catalog_remaining_final_dlc_intake.json').read_text())['entries']}
    for row in intake['entries']:
        model = args.source_root / models[row['species']]
        for variant, record in row['variants'].items():
            source = Path(record['path'])
            if hashlib.sha256(source.read_bytes()).hexdigest() != record['sha256']:
                raise ValueError('Input candidate changed')
            table = model.with_suffix('.trmtr')
            if variant == 'shiny':
                table = table.with_stem(table.stem + '_rare')
            if hashlib.sha256(table.read_bytes()).hexdigest() != record['table_sha256']:
                raise ValueError('Pinned material table changed')
            target = args.output / row['species'] / variant / 'model.glb'
            record['layer_emission_receipt'] = restore(source, target, table)
            record['path'] = str(target.resolve())
            record['sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
        compare(Path(row['variants']['normal']['path']), Path(row['variants']['shiny']['path']))
    intake['runtime_approved'] = False
    (args.output / 'status-complete.json').write_text(json.dumps(intake, indent=2) + '\n')


if __name__ == '__main__':
    main()
