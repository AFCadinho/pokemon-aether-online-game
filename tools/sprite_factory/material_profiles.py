"""Source-semantic export profiles. Recognition is not shader implementation."""
import hashlib
from pathlib import Path
from scvi_material_probe import inspect_materials, eligible

LAYERED = 'scvi_nondirectional_layered_displacement_v1'
UNLIT = 'scvi_unlit_layered_displacement_v1'


def classify(material):
    shaders = material.get('shaders', [])
    values = shaders[0].get('values', {}) if len(shaders) == 1 else {}
    unlit = (len(shaders) == 1 and shaders[0]['name'] == 'Unlit' and
             values.get('EnableBaseColorMap') == 'True' and values.get('EnableDisplacementMap') == 'True' and
             values.get('NumMaterialLayer') == '5' and values.get('NumRequiredUV') == '1' and
             {'BaseColorMap','LayerMaskMap','DisplacementMap'} <= material.get('textures', {}).keys())
    if eligible(material) or unlit:
        values = material['shaders'][0]['values']
        return {'material': material['name'], 'profile': UNLIT if unlit else LAYERED,
                'alpha_test': values.get('EnableAlphaTest') == 'True',
                'export_supported': True, 'requires_effect_payload': True,
                'requirements': ['layer_mask_opacity', 'displacement_uv1' if unlit else 'displacement_uv2',
                                 'auxiliary_uv_animation', 'unlit_lighting']}
    shaders = material.get('shaders', [])
    unsupported = any(s.get('name') == 'NonDirectional' or
        s.get('values', {}).get('EnableDisplacementMap') == 'True' for s in shaders)
    return {'material': material['name'],
            'profile': 'unreviewed_source_shader' if unsupported else 'existing_graph_validation_required',
            'export_supported': not unsupported}


def read_profiles(path, digest):
    path = Path(path)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise ValueError('Material source changed')
    return [classify(m) for m in inspect_materials(path)]


def unsupported(profiles):
    return [p for p in profiles if not p['export_supported']]
