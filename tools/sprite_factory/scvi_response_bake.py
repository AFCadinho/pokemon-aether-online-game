"""Bake the supported SCVI shadow-colour graph, without modifying source files."""
import hashlib
from pathlib import Path


def bake(output, exclude=()):
    import bpy
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 1
    materials = {m.name: m for o in scene.objects if o.type == 'MESH' for m in o.data.materials if m and m.name not in exclude}
    maps, inputs = [], []
    for index, (name, original) in enumerate(sorted(materials.items())):
        # Work on a material copy; PBR export still sees the untouched graph.
        material = original.copy()
        tree = material.node_tree
        groups = [n for n in tree.nodes if n.type == 'GROUP' and 'BaseColorBake' in n.outputs]
        if len(groups) != 1:
            raise ValueError('Unsupported response graph: ' + name)
        group = groups[0]
        group.node_tree = group.node_tree.copy()
        graph = group.node_tree
        for required in ('Color Ramp', 'Mix.006', 'Mix (Legacy).040'):
            if required not in graph.nodes:
                raise ValueError('Unsupported response graph: ' + required)
        ramp = graph.nodes['Color Ramp'].color_ramp
        values = [[e.position, list(e.color)] for e in ramp.elements]
        if ramp.interpolation != 'EASE' or values != [[0.5, [1.0]*4], [1.0, [0.0, 0.0, 0.0, 1.0]]]:
            raise ValueError('Unsupported response ramp: ' + name)
        source = {}
        for key in ('IOR', 'SpecularMaskMap'):
            socket = group.inputs.get(key)
            if socket is None or socket.is_linked:
                raise ValueError('Unsupported response specular: ' + name)
            source[key] = {'value': float(socket.default_value), 'links': []}
        inputs.append({'material': name, 'inputs': source})
        factor = next(s for s in graph.nodes['Mix.006'].inputs if s.name == 'Factor' and s.type == 'VALUE')
        for link in list(factor.links):
            graph.links.remove(link)
        graph.interface.new_socket(name='ResponseColor', in_out='OUTPUT', socket_type='NodeSocketColor')
        go = next(n for n in graph.nodes if n.type == 'GROUP_OUTPUT' and n.is_active_output)
        graph.links.new(graph.nodes['Mix (Legacy).040'].outputs['Color'], go.inputs['ResponseColor'])
        out = next(n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
        emission = tree.nodes.new('ShaderNodeEmission')
        tree.links.new(group.outputs['ResponseColor'], emission.inputs['Color'])
        tree.links.new(emission.outputs[0], out.inputs['Surface'])
        size = max((max(n.image.size) for n in tree.nodes if n.type == 'TEX_IMAGE' and n.image), default=512)
        if not 1 <= size <= 4096:
            raise ValueError('Unsupported response texture size')
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_plane_add()
        plane = bpy.context.object
        plane.data.materials.append(material)
        record = {'material': name, 'ramp': values, 'interpolation': ramp.interpolation}
        for endpoint in (0, 1):
            factor.default_value = endpoint
            image = bpy.data.images.new('ResponseEndpoint', width=size, height=size, alpha=False)
            target = tree.nodes.new('ShaderNodeTexImage')
            target.image = image
            tree.nodes.active = target
            bpy.ops.object.bake(type='EMIT')
            path = output / f'{index}-{endpoint}.png'
            image.filepath_raw, image.file_format = str(path), 'PNG'
            image.save()
            record[str(endpoint)] = str(path)
            record[str(endpoint) + '_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            tree.nodes.remove(target)
            bpy.data.images.remove(image)
        mesh = plane.data
        bpy.data.objects.remove(plane, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        bpy.data.materials.remove(material)
        bpy.data.node_groups.remove(graph)
        maps.append(record)
    return {'schema': 1, 'maps': maps, 'inputs': inputs}
