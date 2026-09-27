"""Source-semantic export profiles. Recognition is not shader implementation."""
import hashlib
from pathlib import Path
from scvi_material_probe import inspect_materials, eligible

LAYERED = 'scvi_nondirectional_layered_displacement_v1'
UNLIT = 'scvi_unlit_layered_displacement_v1'
LIT = 'scvi_standard_displacement_review_v1'
UNLIT_UV2 = 'scvi_unlit_layered_displacement_uv2_v1'
REFRACTION_UNSUPPORTED = 'scvi_transparent_refraction_unimplemented'
TRANSPARENT_PROBE = 'scvi_source_alpha_diagnostic_v1'


def classify(material, *, transparent_review=False, displacement_review=False):
    shaders = material.get('shaders', [])
    # Check native semantics before Blender/GLB baking can flatten the surface
    # to opaque. Runtime StandardMaterial3D transparency alone is not evidence
    # that a source Transparent/TransparentInner graph has been reproduced.
    if any(s.get('name') in ('Transparent', 'TransparentInner') or
           s.get('values', {}).get('RefractionMode') not in (None, '', 'None')
           for s in shaders):
        floats = material.get('floats', {})
        fresnel_min = floats.get('FresnelAlphaMin', 1.0)
        fresnel_max = floats.get('FresnelAlphaMax', 1.0)
        if transparent_review and material.get('alpha_type') in ('Blend', 'Add', 'BlendPreMultiAlpha') and all(
                s.get('name') in ('Transparent', 'TransparentInner') and
                s.get('values', {}).get('RefractionMode') in (None, '', 'None', 'Thin')
                for s in shaders) and 0.0 <= fresnel_min <= 1.0 and 0.0 <= fresnel_max <= 1.0:
            return {'material': material['name'], 'profile': TRANSPARENT_PROBE,
                    'export_supported': True, 'source_alpha_type': material['alpha_type'],
                    'source_refraction': any(s['values'].get('RefractionMode') == 'Thin' for s in shaders),
                    'source_fresnel_alpha_min': fresnel_min,
                    'source_fresnel_alpha_max': fresnel_max,
                    'visual_review_required': True}
        return {'material': material['name'], 'profile': REFRACTION_UNSUPPORTED,
                'export_supported': False,
                'reason': 'Native transparency/refraction is not implemented by the opaque response profile'}
    values = shaders[0].get('values', {}) if len(shaders) == 1 else {}
    unlit = (len(shaders) == 1 and shaders[0]['name'] == 'Unlit' and
             values.get('EnableBaseColorMap') == 'True' and values.get('EnableDisplacementMap') == 'True' and
             values.get('NumMaterialLayer') == '5' and values.get('NumRequiredUV') in ('1', '2') and
             {'BaseColorMap','LayerMaskMap','DisplacementMap'} <= material.get('textures', {}).keys())
    if (displacement_review and len(shaders) == 1 and shaders[0]['name'] == 'Standard'
            and values.get('EnableDisplacementMap') == 'True'
            and values.get('NumRequiredUV') in ('1', '2')
            and values.get('NumMaterialLayer') == '5'
            and values.get('EnableParallaxMap') in (None, 'False')
            and material.get('alpha_type') == 'Opaque'
            and {'BaseColorMap', 'LayerMaskMap', 'DisplacementMap'} <= material.get('textures', {}).keys()):
        return {'material': material['name'], 'profile': LIT,
                'alpha_test': values.get('EnableAlphaTest') == 'True',
                'export_supported': True, 'requires_effect_payload': True,
                'use_uv2': values['NumRequiredUV'] == '2', 'visual_review_required': True,
                'requirements': ['baked_pbr', 'native_displacement', 'auxiliary_uv_animation']}
    if eligible(material) or unlit:
        values = material['shaders'][0]['values']
        return {'material': material['name'], 'profile': (UNLIT_UV2 if values.get('NumRequiredUV') == '2' else UNLIT) if unlit else LAYERED,
                'alpha_test': values.get('EnableAlphaTest') == 'True',
                'export_supported': True, 'requires_effect_payload': True,
                'requirements': ['layer_mask_opacity', 'displacement_uv1' if unlit and values.get('NumRequiredUV') == '1' else 'displacement_uv2',
                                 'auxiliary_uv_animation', 'unlit_lighting']}
    shaders = material.get('shaders', [])
    unsupported = any(s.get('name') == 'NonDirectional' or
        s.get('values', {}).get('EnableDisplacementMap') == 'True' for s in shaders)
    return {'material': material['name'],
            'profile': 'unreviewed_source_shader' if unsupported else 'existing_graph_validation_required',
            'export_supported': not unsupported}


def read_profiles(path, digest, *, transparent_review=False, displacement_review=False):
    path = Path(path)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise ValueError('Material source changed')
    return [classify(m, transparent_review=transparent_review, displacement_review=displacement_review) for m in inspect_materials(path)]


def unsupported(profiles):
    return [p for p in profiles if not p['export_supported']]
