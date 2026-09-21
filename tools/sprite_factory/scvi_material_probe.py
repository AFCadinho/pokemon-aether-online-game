"""Read-only TRMTR subset for an opt-in layered-surface causal review.

Schema slots are those of the pinned importer's Titan/Model generated readers.
This is not an assertion of full SCVI shader parity.
"""
import struct
from pathlib import Path

from scvi_tracm import _Buffer

POLICY = 'layer-mask-transparency-probe-v1'


def inspect_materials(path):
    data = Path(path).read_bytes()
    view = _Buffer(data)
    materials = []
    # TRMTR has a version field before Materials.
    for table in view.tables(view.u32(0), 1):
        shaders = []
        for shader in view.tables(table, 1):
            shaders.append({'name': view.string(shader, 0), 'values': {
                view.string(value, 0): view.string(value, 1)
                for value in view.tables(shader, 1)}})
        materials.append({'name': view.string(table, 0), 'shaders': shaders,
            'alpha_type': view.string(table, 15),
            'textures': {view.string(tex, 0): view.string(tex, 1)
                         for tex in view.tables(table, 2)},
            'floats': {view.string(value, 0): view.scalar(
                value, 1, lambda offset: struct.unpack_from('<f', data, offset)[0], 0.0)
                for value in view.tables(table, 4)}})
    return materials


def eligible(material):
    shaders = material['shaders']
    if len(shaders) != 1 or shaders[0]['name'] != 'NonDirectional':
        return False
    values = shaders[0]['values']
    return (values.get('EnableBaseColorMap') == 'True'
            and values.get('EnableDisplacementMap') == 'True'
            and values.get('NumMaterialLayer') == '5'
            and values.get('NumRequiredUV') == '2'
            and {'BaseColorMap', 'LayerMaskMap', 'DisplacementMap'} <= material['textures'].keys())


def apply_probe(materials, displacement=False):
    """In-memory opacity intervention, with optional static displacement probe.

    Biochao's authored reference mixes surface -> transparent using LayerMask
    alpha. Apply only to the explicitly opted-in, matching shader signature.
    Native mesh data and the original shader nodes are retained. Optional
    displacement is an unverified interpretation; UV motion and NonDirectional
    lighting are NOT implemented.
    """
    import bpy

    applied = []
    for source in materials:
        if not eligible(source):
            continue
        mat = bpy.data.materials.get(source['name'])
        if mat is None or not mat.node_tree:
            raise ValueError('Probe material missing: ' + source['name'])
        tree = mat.node_tree
        if any(node.label == POLICY for node in tree.nodes):
            raise ValueError('Probe already applied')
        filename = Path(source['textures']['LayerMaskMap']).stem
        masks = [node for node in tree.nodes if node.type == 'TEX_IMAGE' and node.image
                 and Path(node.image.filepath).stem == filename]
        outputs = [node for node in tree.nodes if node.type == 'OUTPUT_MATERIAL' and node.is_active_output]
        if len(masks) != 1 or len(outputs) != 1 or len(outputs[0].inputs['Surface'].links) != 1:
            raise ValueError('Ambiguous mask or material output: ' + source['name'])
        surface = outputs[0].inputs['Surface']
        original = surface.links[0].from_socket
        transparent = tree.nodes.new('ShaderNodeBsdfTransparent')
        mix = tree.nodes.new('ShaderNodeMixShader')
        mix.label = POLICY
        tree.links.new(masks[0].outputs['Alpha'], mix.inputs[0])
        tree.links.new(original, mix.inputs[1])
        tree.links.new(transparent.outputs[0], mix.inputs[2])
        tree.links.new(mix.outputs[0], surface)
        mat.surface_render_method = 'DITHERED'
        record = {'material': mat.name, 'mask': masks[0].image.name,
                        'opacity': '1 - LayerMaskMap.alpha',
                        'scope': 'experimental_not_shader_parity'}
        if displacement:
            # Explicit hypothesis: native height texture, UV2, centered normal
            # displacement. Not a verified reconstruction of the game shader.
            path = Path(source['displacement_image'])
            import hashlib
            if hashlib.sha256(path.read_bytes()).hexdigest() != source['displacement_sha256']:
                raise ValueError('Displacement source changed')
            image = bpy.data.images.load(str(path), check_existing=False)
            image.colorspace_settings.name = 'Non-Color'
            texture = bpy.data.textures.new('SourceDisplacementProbe', type='IMAGE')
            texture.image = image
            affected = []
            for obj in bpy.context.scene.objects:
                if obj.type != 'MESH' or mat not in list(obj.data.materials):
                    continue
                if len(obj.data.materials) != 1 or len(obj.data.uv_layers) != 2:
                    raise ValueError('Displacement probe requires a dedicated two-UV material mesh')
                modifier = obj.modifiers.new('SourceDisplacementProbe', 'DISPLACE')
                modifier.texture = texture
                modifier.texture_coords = 'UV'
                modifier.uv_layer = obj.data.uv_layers[1].name
                modifier.strength = source['floats']['DisplacementHeight']
                modifier.mid_level = 0.5
                affected.append(obj.name)
            if not affected:
                raise ValueError('No displacement probe mesh')
            record['displacement'] = {'meshes': affected, 'midlevel_hypothesis': 0.5,
                                      'strength': source['floats']['DisplacementHeight'], 'uv_index': 1}
        applied.append(record)
    return {'policy': POLICY, 'applied': applied, 'runtime_approved': False,
            'displacement_hypothesis': displacement,
            'unimplemented': ['verified_displacement_semantics', 'UV_motion', 'NonDirectional_lighting']}
