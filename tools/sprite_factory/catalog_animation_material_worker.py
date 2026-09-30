"""Bake the connected native Principled colour graph for held Biochao normals.

Runs only in a disposable Blender process. It never saves a source Blend or
chooses shiny colours. Shader mixes and unconnected colour inputs remain holds.
"""

import hashlib
import math
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import isolate
from blender_action_state import select_action


def input_values(node):
    result = {}
    for index, socket in enumerate(node.inputs):
        if socket.is_linked or not hasattr(socket, 'default_value'):
            continue
        value = socket.default_value
        # Blender can renumber interface identifiers when copying a group.
        # Require the same ordered name/type instead; changed input layouts
        # still fail verification rather than silently losing their values.
        result[(index, socket.name, socket.type)] = tuple(value) if hasattr(value, '__len__') and not isinstance(value, str) else value
    return result


def restore_inputs(node, values):
    for index, socket in enumerate(node.inputs):
        key = (index, socket.name, socket.type)
        if key in values:
            socket.default_value = values[key]
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
    if node.type == 'MIX_SHADER':
        branches = [socket.links[0].from_socket if len(socket.links) == 1 else None
                    for socket in (node.inputs[1], node.inputs[2])]
        if not all(branches) or [s.node.type for s in branches] != ['BSDF_PRINCIPLED', 'EMISSION']:
            raise ValueError('Native shader mix is not Principled plus emission')
        colour, alpha, _ = colour_sockets(tree, branches[0])
        lamp = branches[1].node
        glow = tree.nodes.new('ShaderNodeVectorMath')
        glow.operation = 'SCALE'
        for destination, source in [(glow.inputs[0], lamp.inputs['Color']),
                                    (glow.inputs[3], lamp.inputs['Strength'])]:
            if source.is_linked:
                tree.links.new(source.links[0].from_socket, destination)
            else:
                destination.default_value = source.default_value[:3] if hasattr(source.default_value, '__len__') else source.default_value
        # The caller accepts this route only if the emission bake is zero.
        return colour, alpha, glow.outputs[0]
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
        glow = tree.nodes.new('ShaderNodeVectorMath')
        glow.operation = 'SCALE'
        for destination, source in [(glow.inputs[0], node.inputs['Emission Color']),
                                    (glow.inputs[3], node.inputs['Emission Strength'])]:
            if source.is_linked:
                tree.links.new(source.links[0].from_socket, destination)
            else:
                destination.default_value = source.default_value[:3] if hasattr(source.default_value, '__len__') else source.default_value
        return colour.links[0].from_socket, alpha_source, glow.outputs[0]
    if node.type != 'GROUP' or not node.node_tree:
        raise ValueError('Native surface is not a single Principled shader path')
    graph = node.node_tree
    outputs = [n for n in graph.nodes if n.type == 'GROUP_OUTPUT' and n.is_active_output]
    if len(outputs) != 1:
        raise ValueError('Native group output is ambiguous')
    socket = outputs[0].inputs.get(shader_socket.name)
    if socket is None or len(socket.links) != 1:
        raise ValueError('Native shader group output is not connected')
    colour, alpha, glow = colour_sockets(graph, socket.links[0].from_socket)
    values = input_values(node)
    for name, kind, source in [('PAO_SourceColour', 'NodeSocketColor', colour),
                               ('PAO_SourceAlpha', 'NodeSocketFloat', alpha),
                               ('PAO_SourceGlow', 'NodeSocketColor', glow)]:
        graph.interface.new_socket(name=name, in_out='OUTPUT', socket_type=kind)
        graph.links.new(source, outputs[0].inputs[name])
    restore_inputs(node, values)
    return node.outputs['PAO_SourceColour'], node.outputs['PAO_SourceAlpha'], node.outputs['PAO_SourceGlow']


def bake(job):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Native Blend source changed')
    official = None
    if any(item.get('colour_overrides') or item.get('texture_overrides') for item in job['materials']):
        from scvi_material_probe import inspect_materials
        official = []
        for variant in ('normal', 'rare'):
            table = Path(job[variant + '_table'])
            if hashlib.sha256(table.read_bytes()).hexdigest() != job[variant + '_table_sha256']:
                raise ValueError('Official variant table changed')
            official.append({row['name']: row for row in inspect_materials(table)})
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
        for change in item.get('colour_overrides', []):
            if any(rows[item['name']]['colors'].get(change['key']) != change[variant]
                   for rows, variant in zip(official, ('normal', 'rare'))):
                raise ValueError('Colour override differs from official tables')
            nodes = [n for n in tree.nodes if n.type == 'GROUP' and change['key'] in n.inputs]
            if len(nodes) != 1 or nodes[0].inputs[change['key']].is_linked:
                raise ValueError('Rare colour has no unique authored input')
            socket = nodes[0].inputs[change['key']]
            if not all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(socket.default_value, change['normal'])):
                raise ValueError('Rare colour normal baseline differs from source')
            socket.default_value = change['rare']
        for change in item.get('texture_overrides', []):
            normal, rare = Path(change['normal']), Path(change['rare'])
            if any(path != Path(job[variant + '_table']).parent /
                   Path(rows[item['name']]['textures']['BaseColorMap']).with_suffix('.png').name
                   for rows, variant, path in zip(official, ('normal', 'rare'), (normal, rare))):
                raise ValueError('Texture override differs from official tables')
            if (hashlib.sha256(normal.read_bytes()).hexdigest() != change['normal_sha256'] or
                    hashlib.sha256(rare.read_bytes()).hexdigest() != change['rare_sha256']):
                raise ValueError('Rare texture source changed')
            matches = [n for n in tree.nodes if n.type == 'TEX_IMAGE' and n.image
                       and n.image.name.split('.png')[0] == normal.stem]
            if len(matches) != 1:
                raise ValueError('Rare texture lacks a unique authored binding')
            old = matches[0].image
            check = bpy.data.images.load(str(normal), check_existing=False)
            check.colorspace_settings.name = old.colorspace_settings.name
            if list(check.size) != list(old.size) or any(abs(a-b) > 1e-5 for a,b in zip(check.pixels[:],old.pixels[:])):
                raise ValueError('Rare texture normal pixels differ from source')
            image = bpy.data.images.load(str(rare), check_existing=False)
            image.colorspace_settings.name = old.colorspace_settings.name
            matches[0].image = image
        replace_uv(tree)
        outputs = [n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output]
        if len(outputs) != 1 or len(outputs[0].inputs['Surface'].links) != 1:
            raise ValueError('Native material surface is ambiguous')
        surface = outputs[0].inputs['Surface'].links[0].from_socket
        colour, alpha, glow = colour_sockets(tree, surface)
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.mesh.primitive_plane_add()
        obj = bpy.context.object
        domain = item.get('source_uv_domain')
        if domain is None:
            obj.data.uv_layers.active.name = 'SourceUV'
        else:
            # glTF flips Blender's V coordinate. Imported legacy materials can
            # use UVs outside the first tile and non-periodic eye adjustments;
            # baking only [0, 1] then repeating that image loses their faces.
            if (len(domain) != 4 or not all(math.isfinite(v) for v in domain)
                    or domain[2] <= domain[0] or domain[3] <= domain[1]):
                raise ValueError('Invalid native source UV bake domain')
            obj.data.uv_layers.active.name = 'BakeUV'
            source_uv = obj.data.uv_layers.new(name='SourceUV')
            for index, corner in enumerate(obj.data.uv_layers['BakeUV'].data):
                source_uv.data[index].uv = (
                    domain[0] + corner.uv.x * (domain[2] - domain[0]),
                    domain[1] + corner.uv.y * (domain[3] - domain[1]))
            obj.data.uv_layers.active_index = 0
        obj.data.materials.append(material)
        emission = tree.nodes.new('ShaderNodeEmission')
        tree.links.new(emission.outputs['Emission'], outputs[0].inputs['Surface'])
        bpy.context.scene.render.engine = 'CYCLES'
        bpy.context.scene.cycles.samples = 1
        images = []
        for label, socket in [('colour', colour), ('alpha', alpha), ('glow', glow)]:
            image = bpy.data.images.new(item['name'] + '_' + label, width=512,
                                       height=512, alpha=True, is_data=label == 'alpha')
            node = tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            tree.nodes.active = node
            tree.links.new(socket, emission.inputs['Color'])
            bpy.ops.object.bake(type='EMIT', margin=0)
            images.append(image)
        glow_pixels = list(images[2].pixels)
        if any(abs(value) > 1e-6 for i, value in enumerate(glow_pixels) if i % 4 != 3):
            raise ValueError('Native emission is active; separate reconstruction needed: ' + item['name'])
        pixels = list(images[0].pixels)
        alpha_pixels = list(images[1].pixels)
        for i in range(3, len(pixels), 4):
            pixels[i] = max(0.0, min(1.0, alpha_pixels[i - 3]))
        images[0].pixels.foreach_set(pixels)
        images[0].filepath_raw = item['output']
        images[0].file_format = 'PNG'
        images[0].save()
        receipts.append({'material': item['name'], 'native_emission_output_zero': True,
                         **({'source_uv_domain': domain} if domain is not None else {})})
        print('NATIVE_COLOUR_BAKED', item['name'], item['output'], flush=True)
    Path(job['receipt']).write_text(json.dumps(receipts, indent=2) + '\n')


if __name__ == '__main__':
    bake(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
