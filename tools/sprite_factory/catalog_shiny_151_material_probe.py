"""Review-only material reconstruction for the 151 held shiny candidates.

Uses matched source material names, preserves mesh/UV/animation accessors, and
records shader limitations. This tool never admits a model to the catalog.
"""
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re

from PIL import Image, ImageChops, ImageOps

from catalog_remaining_eye_bake import append_png, bake_eye, chunks, write_glb, linear_to_srgb
from catalog_remaining_body_repair import official_colour
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def za_colour(row, resource):
    """Diagnostic translation of the authored Biochao mirrored colour graph.

    IkCharacter eye options identify the eye graph despite its generic shader
    name. The rectangular body textures use mirrored UV scaling; stretching
    their colour bake across the full UV square misplaces facial markings.
    """
    values = row['shaders'][0]['values']
    if values.get('EnableEyeOptions') == 'True':
        eye = {**row, 'shaders': [{'name': 'Eye'}]}
        return bake_eye(eye, resource)
    textures = row['textures']
    scale = row['colors'].get('UVScaleOffset', [1, 1, 0, 0])
    mirrored = all(abs(a-b) < 1e-6 for a,b in zip(scale, [2,1,0,0]))
    if not mirrored and any(abs(a-b) > 1e-6 for a,b in zip(scale, [1,1,0,0])):
        raise ValueError('ZA UV transform requires a separate reconstruction')

    def texture(key):
        image = Image.open(resource / Path(textures[key]).with_suffix('.png').name).convert('RGBA')
        if mirrored and image.width != image.height:
            expanded = Image.new('RGBA', (image.width * 2, image.height))
            expanded.paste(image, (0, 0))
            expanded.paste(ImageOps.mirror(image), (image.width, 0))
            return expanded
        return image

    base = texture('BaseColorMap')
    if 'LayerMaskMap' in textures:
        mask = texture('LayerMaskMap')
        mask = mask.resize(base.size, Image.Resampling.NEAREST)
        original = base.convert('RGB')
        colour = original.copy()
        for i, channel in enumerate(mask.split(), 1):
            tint = row['colors'].get(f'BaseColorLayer{i}')
            if tint is None:
                if channel.getextrema()[1]:
                    raise ValueError('Active ZA layer has no colour')
                continue
            layer = Image.new('RGB', base.size, tuple(linear_to_srgb(v) for v in tint[:3]))
            layer = ImageChops.multiply(original, layer)
            colour = Image.composite(layer, colour, channel.point(lambda v: min(255, 2*v)))
        colour.putalpha(base.getchannel('A'))
        base = colour
    output = BytesIO(); base.save(output, format='PNG')
    return output.getvalue()


def rebuild(source, target, table):
    doc, binary = chunks(source)
    rows = {r['name']: r for r in inspect_materials(table)}
    normal_table = table.with_name(table.name.replace('_rare.trmtr', '.trmtr'))
    normal_rows = {r['name']: r for r in inspect_materials(normal_table)}
    names = [m['name'] for m in doc['materials']]
    mapped = [n if n in rows else re.sub(r'\.\d{3}$', '', n) for n in names]
    if len(mapped) != len(set(mapped)) or any(n not in rows for n in mapped):
        raise ValueError('Source material names do not identify every exported material')
    records = []
    for material, name in zip(doc['materials'], mapped):
        row = rows[name]
        shaders = {s['name'] for s in row['shaders']}
        pbr = material.get('pbrMetallicRoughness', {})
        bound = pbr.get('baseColorTexture')
        if not bound or 'BaseColorMap' not in row['textures']:
            raise ValueError(name + ': missing source albedo binding')
        old_texture = doc['textures'][bound['index']]
        old_image = doc['images'][old_texture['source']]
        stems = [Path(value).stem for value in normal_rows[name]['textures'].values()]
        if not any(stem in old_image.get('name', '') for stem in stems):
            raise ValueError(name + ': exported texture name does not match source table')
        old_view = doc['bufferViews'][old_image['bufferView']]
        start = old_view.get('byteOffset', 0)
        authored = Image.open(BytesIO(binary[start:start + old_view['byteLength']])).convert('RGBA')
        limitations = []
        if 'IkCharacter' in shaders:
            packed = za_colour(row, table.parent)
            limitations.append('ZA layered surface requires visual qualification')
        elif 'Eye' in shaders:
            packed = bake_eye(row, table.parent)
            baked = Image.open(BytesIO(packed)).convert('RGBA')
            # Preserve a separately authored white glint, if unambiguously
            # white-on-black; do not treat an RGB layer mask as a glint.
            rgb = authored.convert('RGB')
            r, g, b = rgb.split()
            neutral = ImageChops.difference(r, g).getbbox() is None and ImageChops.difference(g, b).getbbox() is None
            if neutral and r.getextrema() == (0, 255) and rgb.getpixel((0, 0)) == (0, 0, 0):
                mask = r.resize(baked.size, Image.Resampling.BILINEAR)
                baked = Image.composite(Image.new('RGBA', baked.size, 'white'), baked, mask)
                output = BytesIO(); baked.save(output, format='PNG'); packed = output.getvalue()
            if any(k in row['textures'] for k in ('UpperEyelidColorMap', 'LowerEyelidColorMap')):
                limitations.append('separate eyelid texture layers need pose review')
        else:
            packed, _ = official_colour(row, table.parent)
        index = append_png(doc, binary, packed, name + '_source_albedo', old_texture.get('sampler', 0))
        pbr['baseColorTexture'] = {**bound, 'index': index}
        pbr['baseColorFactor'] = [1, 1, 1, 1]
        material.pop('emissiveTexture', None)
        material.pop('emissiveFactor', None)
        for key, factor in (('Roughness', 'roughnessFactor'), ('Metallic', 'metallicFactor')):
            if key in row['floats']:
                value = row['floats'][key]
                if not 0 <= value <= 1:
                    raise ValueError(name + ': surface scalar outside PBR range')
                pbr[factor] = value
        emission = row['textures'].get('EmissionColorMap')
        intensity = row['floats'].get('EmissionIntensity', 0)
        if emission and intensity > 0:
            ep = table.parent / Path(emission).with_suffix('.png').name
            ei = append_png(doc, binary, ep.read_bytes(), name + '_source_emission', old_texture.get('sampler', 0))
            material['emissiveTexture'] = {**bound, 'index': ei}
            material['emissiveFactor'] = [min(1, intensity)] * 3
            if intensity > 1:
                material.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': intensity}
                if 'KHR_materials_emissive_strength' not in doc.setdefault('extensionsUsed', []):
                    doc['extensionsUsed'].append('KHR_materials_emissive_strength')
        elif 'Unlit' in shaders:
            material.setdefault('extensions', {})['KHR_materials_unlit'] = {}
            if 'KHR_materials_unlit' not in doc.setdefault('extensionsUsed', []):
                doc['extensionsUsed'].append('KHR_materials_unlit')
        if shaders & {'Transparent', 'TransparentInner', 'Iridescence'}:
            limitations.append('source transparency/iridescence needs visual review')
        if any(v > 0 for k,v in row['floats'].items() if k.startswith('EmissionIntensityLayer')):
            limitations.append('layered emission is not reconstructed')
        records.append({'material': material['name'], 'source_material': name,
                        'shader': sorted(shaders), 'limitations': limitations})
    write_glb(target, doc, binary)
    compare(source, target)
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--za', action='store_true', help='Probe missing SCVI tables against ZA materials')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True, exist_ok=False)
    results = []
    for row in json.loads(args.inventory.read_text())['entries']:
        if args.za and ('absent' not in row['reason'] or not row['za_tables']):
            continue
        if not args.za and 'absent' in row['reason']:
            continue
        name, ident = row['species'], row['resource_id']
        folders = [root / '.tmp/catalog-remaining-normal', root / '.tmp/catalog-remaining-normal-legacy7',
                   root / '.tmp/remaining-catalog-intake/rig-recovered-normal']
        source = next((p / f"{row['national_dex']:04d}-{name}/model.glb" for p in folders
                       if (p / f"{row['national_dex']:04d}-{name}/model.glb").is_file()), None)
        result = {'species': name, 'runtime_approved': False}
        try:
            if source is None or sha(source) != row['source']['normal_glb_sha256']:
                raise ValueError('Pinned normal candidate is missing or changed')
            directory = args.material_root / ident / (ident + '_00_00')
            result['variants'] = {}
            for variant in ('normal', 'shiny'):
                table = directory / (ident + '_00_00' + ('_rare' if variant == 'shiny' else '') + '.trmtr')
                target = args.output / name / variant / 'model.glb'
                records = rebuild(source, target, table)
                result['variants'][variant] = {'path': str(target.resolve()), 'sha256': sha(target),
                    'table': str(table), 'table_sha256': sha(table), 'materials': records}
            result['geometry_motion_sha256'] = compare(args.output / name / 'normal/model.glb', args.output / name / 'shiny/model.glb')
            if result['variants']['normal']['sha256'] == result['variants']['shiny']['sha256']:
                raise ValueError('No visible variant difference reconstructed')
            result['source'] = str(source)
            result['status'] = 'review_candidate'
        except (ValueError, KeyError, OSError) as exc:
            result['status'] = 'held'; result['reason'] = str(exc)
        results.append(result)
        print(name, result['status'], result.get('reason', ''), flush=True)
    (args.output / 'status.json').write_text(json.dumps({'runtime_approved': False, 'entries': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
