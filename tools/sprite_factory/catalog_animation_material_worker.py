"""Bake the connected native Principled colour graph for held Biochao normals.

Runs only in a disposable Blender process. It never saves a source Blend or
chooses shiny colours. Shader mixes and unconnected colour inputs remain holds.
"""

import hashlib
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import isolate
from blender_action_state import select_action


def input_values(node):
    result = {}
    for socket in node.inputs:
        if socket.is_linked or not hasattr(socket, 'default_value'):
            continue
        value = socket.default_value
        result[socket.identifier] = tuple(value) if hasattr(value, '__len__') and not isinstance(value, str) else value
    return result


def restore_inputs(node, values):
    for socket in node.inputs:
        if socket.identifier in values:
            socket.default_value = values[socket.identifier]
    actual = input_values(node)
    if any(key not in actual or actual[key] != value for key, value in values.items()):
        raise ValueError('Authored shader inputs changed while cloning the graph')


def replace_uv(tree):
    for node in list(tree.nodes):
        if node.type == 'GROUP' and node.node_tree:
            # Assigning a copied group resets its instance colour parameters.
            # Keep every authored unlinked input while making disposable edits.
            values = input_values(node)
            node.node_tree = node.node_tree.copy()
            restore_inputs(node, values)
            replace_uv(node.node_tree)
        if node.type == 'TEX_COORD':
            links = [link for link in list(tree.links) if link.from_node == node
                     and link.from_socket.name == 'UV']
            if links:
                uv = tree.nodes.new('ShaderNodeUVMap')
                uv.uv_map = 'SourceUV'
                for link in links:
                    tree.links.new(uv.outputs['UV'], link.to_socket)


def colour_sockets(tree, shader_socket):
    node = shader_socket.node
    if node.type == 'BSDF_PRINCIPLED':
        colour = node.inputs['Base Color']
        if len(colour.links) != 1:
            raise ValueError('Native Base Color is not connected unambiguously')
        alpha = node.inputs['Alpha']
        if not alpha.is_linked:
            constant = tree.nodes.new('ShaderNodeValue')
            constant.outputs[0].default_value = alpha.default_value
            alpha_source = constant.outputs[0]
        elif len(alpha.links) == 1:
            alpha_source = alpha.links[0].from_socket
        else:
            raise ValueError('Native alpha is ambiguous')
        return colour.links[0].from_socket, alpha_source
    if node.type != 'GROUP' or not node.node_tree:
        raise ValueError('Native surface is not a single Principled shader path')
    graph = node.node_tree
    outputs = [n for n in graph.nodes if n.type == 'GROUP_OUTPUT' and n.is_active_output]
    if len(outputs) != 1:
        raise ValueError('Native group output is ambiguous')
    socket = outputs[0].inputs.get(shader_socket.name)
    if socket is None or len(socket.links) != 1:
        raise ValueError('Native shader group output is not connected')
    colour, alpha = colour_sockets(graph, socket.links[0].from_socket)
    values = input_values(node)
    for name, kind, source in [('PAO_SourceColour', 'NodeSocketColor', colour),
                               ('PAO_SourceAlpha', 'NodeSocketFloat', alpha)]:
        graph.interface.new_socket(name=name, in_out='OUTPUT', socket_type=kind)
        graph.links.new(source, outputs[0].inputs[name])
    restore_inputs(node, values)
    return node.outputs['PAO_SourceColour'], node.outputs['PAO_SourceAlpha']


def bake(job):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Native Blend source changed')
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False, load_ui=False)
    rig, _ = isolate(source)
    select_action(rig, bpy.data.actions[job['idle_action']])
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    bpy.context.scene.frame_set(int(rig.animation_data.action.frame_range[0]))
    used = {m.name for obj in bpy.context.scene.objects if obj.type == 'MESH'
            for m in obj.data.materials if m}
    if not {item['name'] for item in job['materials']} <= used:
        raise ValueError('Requested material is not owned by the selected source rig')
    receipts = []
    for item in job['materials']:
        material = bpy.data.materials[item['name']].copy()
        if not material.use_nodes:
            raise ValueError('Native material has no shader graph')
        tree = material.node_tree
        replace_uv(tree)
        outputs = [n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output]
        if len(outputs) != 1 or len(outputs[0].inputs['Surface'].links) != 1:
            raise ValueError('Native material surface is ambiguous')
        surface = outputs[0].inputs['Surface'].links[0].from_socket
        strength = surface.node.inputs.get('EmissionStrength') if surface.node.type == 'GROUP' else surface.node.inputs.get('Emission Strength')
        if strength is None or strength.is_linked or strength.default_value != 0:
            raise ValueError('Native emission cannot be proven disabled: ' + item['name'])
        colour, alpha = colour_sockets(tree, surface)
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.mesh.primitive_plane_add()
        obj = bpy.context.object
        obj.data.uv_layers.active.name = 'SourceUV'
        obj.data.materials.append(material)
        emission = tree.nodes.new('ShaderNodeEmission')
        tree.links.new(emission.outputs['Emission'], outputs[0].inputs['Surface'])
        bpy.context.scene.render.engine = 'CYCLES'
        bpy.context.scene.cycles.samples = 1
        images = []
        for label, socket in [('colour', colour), ('alpha', alpha)]:
            image = bpy.data.images.new(item['name'] + '_' + label, width=512,
                                       height=512, alpha=True, is_data=label == 'alpha')
            node = tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            tree.nodes.active = node
            tree.links.new(socket, emission.inputs['Color'])
            bpy.ops.object.bake(type='EMIT', margin=0)
            images.append(image)
        pixels = list(images[0].pixels)
        alpha_pixels = list(images[1].pixels)
        for i in range(3, len(pixels), 4):
            pixels[i] = max(0.0, min(1.0, alpha_pixels[i - 3]))
        images[0].pixels.foreach_set(pixels)
        images[0].filepath_raw = item['output']
        images[0].file_format = 'PNG'
        images[0].save()
        receipts.append({'material': item['name'], 'native_emission_strength': 0})
        print('NATIVE_COLOUR_BAKED', item['name'], item['output'], flush=True)
    Path(job['receipt']).write_text(json.dumps(receipts, indent=2) + '\n')


if __name__ == '__main__':
    bake(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
