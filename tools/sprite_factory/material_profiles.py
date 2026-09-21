"""Source-semantic export profiles. Recognition is not shader implementation."""
import hashlib
from pathlib import Path
from scvi_material_probe import inspect_materials, eligible

LAYERED = 'scvi_nondirectional_layered_displacement_v1'


def classify(material):
    if eligible(material):
        values = material['shaders'][0]['values']
        return {'material': material['name'], 'profile': LAYERED,
                'alpha_test': values.get('EnableAlphaTest') == 'True',
                'export_supported': False,
                'requirements': ['layer_mask_opacity', 'displacement_uv2',
                                 'auxiliary_uv_animation', 'nondirectional_lighting']}
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
