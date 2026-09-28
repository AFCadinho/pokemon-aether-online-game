"""Restore official albedo where Biochao exported a mask/normal map as colour.

This makes review-only GLBs. It does not grant visual or battle approval.
"""

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re

from PIL import Image

from catalog_remaining_eye_bake import append_png, chunks, write_glb
from catalog_remaining_blastoise_eye import repair as repair_blastoise_eye
from scvi_material_probe import inspect_materials


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def contaminated(image_name):
    return ('_lym' in image_name or
            ('_alb' in image_name and
             any(token in image_name for token in ('_nrm', '_mtl', '_rgn'))))


def official_colour(row, resource):
    """Bake source layer tints into albedo where the glTF graph lost them."""
    textures = row['textures']
    base_path = resource / Path(textures['BaseColorMap']).with_suffix('.png').name
    base = Image.open(base_path).convert('RGBA')
    if 'LayerMaskMap' not in textures:
        return base_path.read_bytes(), False
    colours = [row['colors'].get(f'BaseColorLayer{index}') for index in range(1, 5)]
    if not any(colour and colour[:3] != [1.0, 1.0, 1.0] for colour in colours):
        return base_path.read_bytes(), False
    mask_path = resource / Path(textures['LayerMaskMap']).with_suffix('.png').name
    mask = Image.open(mask_path).convert('RGBA')
    if base.size != mask.size:
        base = base.resize(mask.size, Image.Resampling.BILINEAR)
    original = base.convert('RGB')
    colour = original.copy()
    for channel, tint in zip(mask.split(), colours):
        if tint is None:
            continue
        # Body layers tint the albedo. White is the neutral layer, unlike the
        # Eye shader's absolute iris colours.
        factors = [max(0.0, component) for component in tint[:3]]
        if factors == [1.0, 1.0, 1.0]:
            continue
        channels = [component.point(lambda value, factor=factor:
                                    min(255, round(value * factor)))
                    for component, factor in zip(original.split(), factors)]
        layer = Image.merge('RGB', channels)
        strength = channel.point(lambda value: min(255, value * 2))
        colour = Image.composite(layer, colour, strength)
    colour.putalpha(base.getchannel('A'))
    output = BytesIO()
    colour.save(output, format='PNG', optimize=True)
    return output.getvalue(), True


def repair(source, target, table, resource, clear_all_mask_emission=False):
    document, binary = chunks(source)
    official = {row['name']: row for row in inspect_materials(table)}
    restored = []
    cleared_emission = []
    baked_layers = []
    for material in document['materials']:
        name = material.get('name')
        row = official.get(name)
        if clear_all_mask_emission and row is not None and 'emissiveTexture' in material:
            emission = material['emissiveTexture']
            image = document['images'][document['textures'][emission['index']]['source']]
            if '_lym' in image.get('name', ''):
                material.pop('emissiveTexture', None)
                material.pop('emissiveFactor', None)
                cleared_emission.append(name)
        pbr = material.get('pbrMetallicRoughness', {})
        bound = pbr.get('baseColorTexture')
        if row is None or bound is None:
            continue
        old_texture = document['textures'][bound['index']]
        image_name = document['images'][old_texture['source']].get('name', '')
        if not contaminated(image_name):
            continue
        if 'BaseColorMap' not in row['textures']:
            raise ValueError(f'{name}: contaminated colour has no official albedo')
        path = resource / Path(row['textures']['BaseColorMap']).with_suffix('.png').name
        if not path.is_file():
            raise ValueError(f'{name}: official albedo file missing')
        packed, layered = official_colour(row, resource)
        texture = append_png(document, binary, packed,
                             name + '_official_body_albedo', old_texture.get('sampler', 0))
        pbr['baseColorTexture'] = {**bound, 'index': texture}
        # The corresponding emission binding was also built from the normal,
        # metal or region map by the same faulty Blender graph. Keeping it
        # paints the model yellow even after the base-colour substitution.
        emission = material.get('emissiveTexture')
        if emission is not None:
            emission_image = document['images'][document['textures'][emission['index']]['source']]
            source_name = emission_image.get('name', '')
            no_official_emission = not any(
                value > 0 for key, value in row['floats'].items()
                if key.startswith('EmissionIntensity'))
            if (no_official_emission or '_lym' in source_name or
                    any(token in source_name for token in ('_nrm', '_mtl', '_rgn'))):
                material.pop('emissiveTexture', None)
                material.pop('emissiveFactor', None)
                cleared_emission.append(name)
        if layered:
            baked_layers.append(name)
        restored.append({'material': name, 'bad_image': image_name,
                         'official_albedo': path.name,
                         'baked_source_layers': layered,
                         'shader': [shader['name'] for shader in row['shaders']]})
    if restored or cleared_emission:
        write_glb(target, document, binary)
    return {'path': str((target if restored else source).resolve()),
            'restored': restored, 'cleared_bad_emission': cleared_emission,
            'baked_source_layers': baked_layers}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--eye-status', type=Path, required=True)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--blastoise-sclera-review', action='store_true',
                        help='Include the light-sclera Blastoise eye comparison')
    args = parser.parse_args()
    source = {row['species']: row for row in json.loads(args.candidates.read_text())['entries']}
    rows = json.loads(args.eye_status.read_text())['entries']
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for row in rows:
        species = row['species']
        result = {'species': species, 'status': 'unchanged'}
        try:
            source_entry = source[species].get('source', source[species].get('legacy_source'))
            identifier = re.search(r'pm\d{4}', source_entry['member'])[0]
            resource = args.material_root / identifier / f'{identifier}_00_00'
            for variant in ('normal', 'shiny'):
                input_path = Path(row[variant]['path'])
                if digest(input_path) != row[variant]['sha256']:
                    raise ValueError('Eye-review input hash changed')
                table = resource / (f'{identifier}_00_00' +
                                    ('_rare.trmtr' if variant == 'shiny' else '.trmtr'))
                record = repair(input_path, args.output / species / variant / 'model.glb',
                                table, resource,
                                clear_all_mask_emission=species in {
                                    'magmar', 'jirachi', 'golett'})
                if species == 'blastoise' and args.blastoise_sclera_review:
                    target = args.output / species / variant / 'model.glb'
                    record['blastoise_eye_materials'] = repair_blastoise_eye(
                        record['path'], target, table, resource)
                    record['path'] = str(target.resolve())
                record['sha256'] = digest(record['path'])
                record['official_material_sha256'] = digest(table)
                result[variant] = record
            normal = [r['material'] for r in result['normal']['restored']]
            shiny = [r['material'] for r in result['shiny']['restored']]
            if normal != shiny:
                raise ValueError('Normal/shiny contaminated material lists differ')
            if normal or (species == 'blastoise' and args.blastoise_sclera_review):
                result['status'] = 'repaired_for_review'
        except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
            result = {'species': species, 'status': 'held',
                      'reason': type(error).__name__ + ': ' + str(error)}
        results.append(result)
        (args.output / 'status.json').write_text(json.dumps({
            'schema': 1, 'runtime_approved': False, 'entries': results}, indent=2) + '\n')
        print(species, result['status'], flush=True)
    print('BODY_BATCH', len(results), 'processed,',
          sum(row['status'] == 'repaired_for_review' for row in results), 'repaired,',
          sum(row['status'] == 'held' for row in results), 'held')


if __name__ == '__main__':
    main()
