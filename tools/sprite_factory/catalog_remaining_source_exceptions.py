"""Narrow review repairs verified against the original Jirachi/Zekrom sources.

These produce visual candidates, never catalog approval.
"""

from copy import deepcopy
import hashlib
from pathlib import Path

from catalog_remaining_eye_bake import append_png, bake_eye, chunks, write_glb
from scvi_material_probe import inspect_materials


# Biochao Gen3.zip / pm0385.blend, SHA-256:
# 27d3f2b3a93bdfca08a545f4fb7a7a4ffe77f6af4c107d5198e64fad90bd1e30
# Both eye node groups bind eye_msk.Color -> Mask and Mask_color = white.
# Their authored layer 2/3 colours and roughness differ from the newer TRMTR.
JIRACHI_LAYERS = {2: 0.08592537045478821, 3: 0.20144319534301758}
JIRACHI_MASK_SHA256 = '35d56c965f846c8af46c900a7fae4390c3f758fe86a5ddda42bf63ef48bbe134'
ZEKROM_OPAQUE = {'body_a', 'body_b_00', 'body_b_01', 'body_b_02', 'body_b_04'}


def repair(species, source, target, table, resource):
    if species not in ('jirachi', 'zekrom'):
        raise ValueError('Unsupported source exception')
    identifier = 'pm0385' if species == 'jirachi' else 'pm0644'
    if not Path(table).name.startswith(identifier + '_00_00'):
        raise ValueError('Source material table does not match species')
    document, binary = chunks(source)
    rows = {row['name']: row for row in inspect_materials(table)}
    changed = []
    if species == 'jirachi':
        mask = resource / 'pm0385_00_00_eye_msk.png'
        if hashlib.sha256(mask.read_bytes()).hexdigest() != JIRACHI_MASK_SHA256:
            raise ValueError('Jirachi source highlight mask changed')
    for material in document['materials']:
        name = material.get('name')
        if species == 'jirachi' and name in ('l_eye', 'r_eye'):
            row = deepcopy(rows[name])
            for index, expected in ((2, 0.2231999933719635), (3, 0.4564000070095062)):
                if any(abs(v - expected) > 1e-6
                       for v in row['colors'][f'BaseColorLayer{index}'][:3]):
                    raise ValueError('Jirachi layer source changed')
                row['colors'][f'BaseColorLayer{index}'] = [JIRACHI_LAYERS[index]] * 3 + [1.0]
            # Keep the official normal/rare layer 1 difference. Reconstruct
            # the source Blender group's final white Mask mix explicitly.
            row['textures']['HighlightMaskMap'] = mask.name
            pbr = material['pbrMetallicRoughness']
            binding = pbr['baseColorTexture']
            old = document['textures'][binding['index']]
            texture = append_png(document, binary, bake_eye(row, resource),
                                 name + '_source_highlight', old.get('sampler', 0))
            pbr['baseColorTexture'] = {**binding, 'index': texture}
            pbr['roughnessFactor'] = 0.5
            changed.append(name)
        elif species == 'zekrom' and name in ZEKROM_OPAQUE:
            row = rows[name]
            if (row['alpha_type'] != 'Opaque' or
                    any(key.startswith('OpacityMap') for key in row['textures'])):
                raise ValueError('Zekrom source no longer declares an opaque body')
            material['alphaMode'] = 'OPAQUE'
            material.pop('alphaCutoff', None)
            pbr = material['pbrMetallicRoughness']
            if 'baseColorFactor' in pbr:
                pbr['baseColorFactor'][3] = 1.0
            changed.append(name)
    expected = {'l_eye', 'r_eye'} if species == 'jirachi' else ZEKROM_OPAQUE
    if set(changed) != expected:
        raise ValueError('Missing or unexpected source exception materials')
    write_glb(target, document, binary)
    return {'policy': species + '-source-material-v1', 'materials': changed,
            'runtime_approved': False}
