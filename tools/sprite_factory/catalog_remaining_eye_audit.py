"""Audit every remaining-catalog eye material against official source data.

This is a technical review receipt, not an automatic visual approval. It
reports missing eye surfaces, alpha/roughness/highlight gaps, and source-table
provenance for normal and shiny separately.
"""

import argparse
from io import BytesIO
import json
from pathlib import Path
import re

from PIL import Image

from catalog_remaining_eye_bake import chunks
from scvi_material_probe import inspect_materials


def embedded_image(document, binary, texture_index):
    image = document['images'][document['textures'][texture_index]['source']]
    view = document['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    return Image.open(BytesIO(binary[start:start + view['byteLength']])).convert('RGBA')


def audit_variant(glb, table):
    document, binary = chunks(glb)
    official = {row['name']: row for row in inspect_materials(table)
                if any(shader['name'] == 'Eye' for shader in row['shaders'])}
    used = {primitive['material'] for mesh in document.get('meshes', [])
            for primitive in mesh.get('primitives', []) if 'material' in primitive}
    material_by_name = {material.get('name'): (index, material)
                        for index, material in enumerate(document['materials'])}
    rows = []
    for name, row in official.items():
        item = {'material': name, 'issues': []}
        matched = material_by_name.get(name)
        if matched is None:
            item['issues'].append('official_eye_material_absent_from_glb')
            rows.append(item)
            continue
        index, material = matched
        if index not in used:
            item['issues'].append('eye_material_has_no_mesh_primitive')
        pbr = material.get('pbrMetallicRoughness', {})
        texture = pbr.get('baseColorTexture')
        if texture is None:
            item['issues'].append('eye_has_no_base_colour_texture')
        else:
            alpha_min, alpha_max = embedded_image(document, binary, texture['index']).getchannel('A').getextrema()
            item['rendered_alpha_range'] = [alpha_min, alpha_max]
            if alpha_min < 255 and not {'OpacityMap', 'OpacityMap1'} & row['textures'].keys():
                item['issues'].append('eye_opacity_from_albedo_without_source_opacity_map')
        if 'emissiveTexture' in material:
            item['issues'].append('raw_eye_mask_bound_as_emission')
        roughness = row['floats'].get('Roughness')
        if roughness is not None:
            actual = pbr.get('roughnessFactor', 1.0)
            item['source_roughness'] = roughness
            item['rendered_roughness'] = actual
            if abs(actual - roughness) > 0.05:
                item['issues'].append('roughness_differs_from_official_eye_shader')
        highlight = any(shader['values'].get('EnableHighlight') == 'True'
                        for shader in row['shaders'])
        item['official_highlight_enabled'] = highlight
        item['official_highlight_mask'] = 'HighlightMaskMap' in row['textures']
        # Godot's GLB importer did not enable clearcoat even when an earlier
        # trial GLB declared KHR_materials_clearcoat. Report the source gap
        # rather than mistaking the extension for an imported highlight.
        item['glb_clearcoat_extension'] = 'KHR_materials_clearcoat' in material.get('extensions', {})
        if highlight and not item['official_highlight_mask']:
            item['issues'].append('source_highlight_not_runtime_verified')
        rows.append(item)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', type=Path, required=True)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = {row['species']: row for row in json.loads(args.candidates.read_text())['entries']}
    entries = []
    for candidate in json.loads(args.status.read_text())['entries']:
        species = candidate['species']
        identifier = re.search(r'pm\d{4}', source[species]['source']['member'])[0]
        resource = args.material_root / identifier / f'{identifier}_00_00'
        variants = {}
        for variant in ('normal', 'shiny'):
            table = resource / (f'{identifier}_00_00' +
                                ('_rare.trmtr' if variant == 'shiny' else '.trmtr'))
            variants[variant] = audit_variant(candidate[variant]['path'], table)
        entries.append({'species': species, 'status': candidate['status'],
                        'normal': variants['normal'], 'shiny': variants['shiny']})
    result = {'schema': 1, 'scope': 'technical_eye_audit_not_visual_approval',
              'runtime_approved': False, 'entries': entries}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    from collections import Counter
    counts = Counter(issue for entry in entries for variant in ('normal', 'shiny')
                     for material in entry[variant] for issue in material['issues'])
    print(len(entries), 'species', dict(counts))


if __name__ == '__main__':
    main()
