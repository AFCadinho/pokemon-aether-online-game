"""Explicit source-bound eye material diagnostics, applied in memory before baking."""
import math
from pathlib import Path

from scvi_material_probe import inspect_materials


def eyelid_transform(row, index):
    key = 'UVScaleOffset' + str(index)
    values = row.get('colors', {}).get(key)
    if (not isinstance(values, list) or len(values) != 4
            or not all(math.isfinite(v) for v in values)
            or row.get('floats', {}).get('UVRotation' + str(index)) != 0.0
            or values[0] <= 0 or values[1] <= 0):
        raise ValueError('Unsupported source eyelid UV transform: ' + key)
    sx, sy, tx, ty = values
    # PNG/Blender UVs use bottom origin. Native offset is measured from top.
    return (sx, sy, 1.0), (tx, 1.0 - sy - ty, 0.0)


def apply(table, mode):
    import bpy
    from array import array

    if mode not in ('unreferenced_white_highlight', 'eyelid_source_uv'):
        raise ValueError('Unknown eye material diagnostic')
    records = []
    for row in inspect_materials(table):
        shaders = row['shaders']
        if not shaders or not all(s['name'] in ('Eye', 'EyeClearCoat') for s in shaders):
            continue
        material = bpy.data.materials.get(row['name'])
        if material is None or material.node_tree is None:
            raise ValueError('Source eye material not bound')
        tree = material.node_tree
        groups = [n for n in tree.nodes if n.type == 'GROUP' and 'Lym_color' in n.inputs and 'UpEye_alpha' in n.inputs]
        if len(groups) != 1:
            raise ValueError('Ambiguous source eye group')
        group = groups[0]
        if mode == 'unreferenced_white_highlight':
            if (any(s['values'].get('EyelidType') != 'None' for s in shaders)
                    or {'HighlightMaskMap', 'OpacityMap1'} & row['textures'].keys()):
                raise ValueError('Source explicitly binds an eye mask; cannot remove it')
            socket = group.inputs['Mask']
            if len(socket.links) != 1:
                raise ValueError('Expected one fallback eye mask')
            node = socket.links[0].from_node
            if node.type != 'TEX_IMAGE' or node.image is None:
                raise ValueError('Fallback eye mask is not an image')
            filenames = {Path(name).with_suffix('.png').name for name in row['textures'].values()}
            if node.image.name.split('.png')[0] + '.png' in filenames:
                raise ValueError('Fallback eye mask is actually referenced by the source')
            pixels = array('f', [0]) * len(node.image.pixels)
            node.image.pixels.foreach_get(pixels)
            if not pixels or any(v != 1.0 for v in pixels):
                raise ValueError('Fallback eye mask is not constant white')
            records.append({'material':row['name'], 'mode':mode, 'removed_fallback':node.image.name})
            tree.links.remove(socket.links[0]);socket.default_value = 0.0
        else:
            if any(s['values'].get('EyelidType') != 'All' for s in shaders):
                raise ValueError('UV repair requires both source eyelid layers')
            for prefix, index, channel, colour in (('UpEye',3,'UpperEyelidColorMap','BaseColorLayer7'),
                                                   ('LowEye',4,'LowerEyelidColorMap','BaseColorLayer8')):
                socket = group.inputs[prefix + '_alpha']
                if len(socket.links) != 1:
                    raise ValueError('Source eyelids must be restored before UV repair')
                node = socket.links[0].from_node
                expected = Path(row['textures'][channel]).with_suffix('.png').name
                if (node.type != 'TEX_IMAGE' or node.image is None
                        or node.image.name.split('.png')[0] + '.png' != expected
                        or node.inputs['Vector'].is_linked):
                    raise ValueError('Ambiguous restored eyelid texture')
                scale, offset = eyelid_transform(row, index)
                tint = row['colors'].get(colour)
                if not tint or len(tint) != 4 or not all(math.isfinite(v) for v in tint):
                    raise ValueError('Missing source eyelid colour')
                uv = tree.nodes.new('ShaderNodeTexCoord')
                transform = tree.nodes.new('ShaderNodeVectorMath');transform.operation = 'MULTIPLY_ADD'
                transform.inputs[1].default_value = scale;transform.inputs[2].default_value = offset
                tree.links.new(uv.outputs['UV'], transform.inputs[0]);tree.links.new(transform.outputs['Vector'], node.inputs['Vector'])
                node.extension = 'EXTEND'
                group.inputs[prefix + '_color'].default_value = tint
                records.append({'material':row['name'],'mode':mode,'channel':channel,'source_uv':row['colors']['UVScaleOffset'+str(index)],'source_colour':tint,'edge':'clamp','uv_origin':'bottom'})
    if mode == 'eyelid_source_uv':
        # Bake the unobscured eye once. Source lid textures are embedded as
        # separate native material passes with per-clip UV tracks in Godot.
        for row in records:
            mat = bpy.data.materials[row['material']]
            for group in [n for n in mat.node_tree.nodes if n.type == 'GROUP' and 'UpEye_alpha' in n.inputs]:
                for name in ('UpEye_alpha', 'LowEye_alpha'):
                    socket = group.inputs[name]
                    for link in list(socket.links): mat.node_tree.links.remove(link)
                    socket.default_value = 0.0
    if not records:
        raise ValueError('Eye material diagnostic matched no source material')
    return records
