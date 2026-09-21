"""Explicit source-driven smoke lighting/UV experiment, never saves source assets."""
from pathlib import Path

import bpy

from scvi_material_probe import eligible
from scvi_uv_probe import sample_loop, validate_loop


def prepare(materials, loop):
    validate_loop(loop)
    bindings = []
    for source in materials:
        if not eligible(source):
            continue
        if source['name'] not in sample_loop(loop, 0):
            raise ValueError('No auxiliary UV loop for eligible material')
        mat = bpy.data.materials[source['name']]
        tree = mat.node_tree
        groups = [n for n in tree.nodes if n.type == 'GROUP' and 'Albedo' in n.inputs]
        mixes = [n for n in tree.nodes if n.type == 'MIX_SHADER' and n.label.startswith('layer-mask-')]
        mask_name = Path(source['textures']['LayerMaskMap']).stem
        masks = [n for n in tree.nodes if n.type == 'TEX_IMAGE' and n.image
                 and Path(n.image.filepath).stem == mask_name]
        if len(groups) != 1 or len(mixes) != 1 or len(masks) != 1:
            raise ValueError('Unexpected reviewed shader structure')
        group = groups[0]
        # Copy only this outer group. Other material users retain their shaders.
        group.node_tree = group.node_tree.copy()
        inner = group.node_tree
        bsdfs = [n for n in inner.nodes if n.type == 'BSDF_PRINCIPLED']
        outputs = [n for n in inner.nodes if n.type == 'GROUP_OUTPUT' and n.is_active_output]
        if len(bsdfs) != 1 or len(outputs) != 1 or len(bsdfs[0].inputs['Base Color'].links) != 1:
            raise ValueError('No unambiguous source base colour signal')
        inner.interface.new_socket(name='ReviewBaseColor', in_out='OUTPUT', socket_type='NodeSocketColor')
        inner.links.new(bsdfs[0].inputs['Base Color'].links[0].from_socket,
                        outputs[0].inputs['ReviewBaseColor'])
        emission = tree.nodes.new('ShaderNodeEmission')
        emission.label = 'NonDirectional lighting hypothesis (source colour)'
        emission.inputs['Strength'].default_value = source['floats']['EmissionIntensity']
        tree.links.new(group.outputs['ReviewBaseColor'], emission.inputs['Color'])
        tree.links.new(emission.outputs[0], mixes[0].inputs[1])
        mask = masks[0]
        if mask.inputs['Vector'].is_linked:
            raise ValueError('Preexisting UV transforms need explicit review')
        uv = tree.nodes.new('ShaderNodeUVMap')
        mapping = tree.nodes.new('ShaderNodeMapping')
        mapping.vector_type = 'POINT'
        tree.links.new(uv.outputs['UV'], mapping.inputs['Vector'])
        tree.links.new(mapping.outputs['Vector'], mask.inputs['Vector'])
        meshes = []
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH' or mat not in list(obj.data.materials):
                continue
            modifiers = [m for m in obj.modifiers if m.name == 'SourceDisplacementProbe']
            if len(modifiers) != 1 or len(obj.data.uv_layers) != 2:
                raise ValueError('Expected prepared UV2 displacement probe')
            # Keep the two native UV sets intact. Only an extra, local probe set moves.
            obj.data = obj.data.copy()
            uv.uv_map = obj.data.uv_layers[0].name
            base = [tuple(v.uv) for v in obj.data.uv_layers[1].data]
            layer = obj.data.uv_layers.new(name='ReviewDisplacementUV')
            modifiers[0].uv_layer = layer.name
            meshes.append((obj, layer, base))
        if not meshes:
            raise ValueError('No smoke probe meshes')
        bindings.append((source['name'], mapping, meshes))

    def evaluate(seconds):
        sampled = sample_loop(loop, seconds)
        for name, mapping, meshes in bindings:
            scale_u, scale_v, offset_u, offset_v = sampled[name]['UVScaleOffset']
            mapping.inputs['Scale'].default_value = (scale_u, scale_v, 1)
            mapping.inputs['Location'].default_value = (offset_u, offset_v, 0)
            a, b, c, d = sampled[name]['UVScaleOffset3']
            for obj, layer, base in meshes:
                for target, (u, v) in zip(layer.data, base):
                    target.uv = (u * a + c, v * b + d)
                obj.data.update()
        bpy.context.view_layer.update()
        return sampled

    evaluate(0)
    return evaluate
