"""Blender-only preview baker for the three archived PLA material families.

Preserve the authored shader graph and texture resolution. Shiny overrides are
explicit visual reconstructions, never presented as recovered source palettes.
"""
import hashlib
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import material_images


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def linear(value):
    value /= 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def bake(job):
    assert sha(job['source']) == job['source_sha256']
    bpy.ops.wm.open_mainfile(filepath=job['source'], load_ui=False, use_scripts=False)
    originals = {name: bpy.data.materials[name] for name in job['materials']}
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.mesh.primitive_plane_add()
    plane = bpy.context.object
    plane.data.uv_layers.active.name = 'UVMap'
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 1
    out = Path(job['output']); out.mkdir(parents=True, exist_ok=True)
    records = []
    for name, authored in originals.items():
        inputs = [bpy.data.images[n] for n in material_images(authored.node_tree)]
        size = [max(i.size[axis] for i in inputs) for axis in (0, 1)]
        assert 0 < min(size) <= max(size) <= 4096
        assert all(i.packed_file for i in inputs)
        source_images = {i.name: {'size': list(i.size), 'colorspace': i.colorspace_settings.name,
            'sha256': hashlib.sha256(i.packed_file.data).hexdigest()} for i in inputs}
        for variant in ('normal', 'shiny'):
            material = authored.copy(); tree = material.node_tree
            group, = [n for n in tree.nodes if n.type == 'GROUP']
            group.node_tree = group.node_tree.copy()
            nested = group.node_tree
            for graph in (tree, nested):
                animation = graph.animation_data
                assert animation is None or (animation.action is None and not animation.drivers and not animation.nla_tracks), name
            assert group.inputs['EmissionStrength'].default_value == 0
            palette = {}
            for key, rgb in job['shiny_srgb'].get(name, {}).items():
                socket = group.inputs[key]
                assert key.startswith('BaseColorLayer') and not socket.is_linked
                palette[key] = {'normal_linear': list(socket.default_value), 'shiny_srgb': rgb}
                if variant == 'shiny': socket.default_value = [linear(v) for v in rgb] + [1]
            principled, = [n for n in nested.nodes if n.type == 'BSDF_PRINCIPLED']
            group_output, = [n for n in nested.nodes if n.type == 'GROUP_OUTPUT']
            nested.interface.new_socket(name='PreviewBake', in_out='OUTPUT', socket_type='NodeSocketColor')
            output, = [n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL']
            emitter = tree.nodes.new('ShaderNodeEmission')
            tree.links.new(group.outputs['PreviewBake'], emitter.inputs['Color'])
            tree.links.new(emitter.outputs[0], output.inputs['Surface'])
            plane.data.materials.clear(); plane.data.materials.append(material)
            for channel, socket_name in [('albedo', 'Base Color'), ('alpha', 'Alpha'),
                                          ('roughness', 'Roughness'), ('metallic', 'Metallic'),
                                          ('normal', 'Normal')]:
                if variant == 'shiny' and channel != 'albedo': continue
                source = principled.inputs[socket_name]
                if channel == 'normal':
                    normal, = [n for n in nested.nodes if n.type == 'NORMAL_MAP']
                    assert normal.inputs['Strength'].default_value == 1
                    source = normal.inputs['Color']
                destination = group_output.inputs['PreviewBake']
                for link in list(destination.links): nested.links.remove(link)
                if source.is_linked:
                    nested.links.new(source.links[0].from_socket, destination)
                else:
                    value = source.default_value
                    destination.default_value = list(value) if hasattr(value, '__len__') else [value]*3+[1]
                image = bpy.data.images.new('preview', width=size[0], height=size[1], alpha=True)
                image.colorspace_settings.name = 'sRGB' if channel == 'albedo' else 'Non-Color'
                node = tree.nodes.new('ShaderNodeTexImage'); node.image = image
                for n in tree.nodes: n.select = False
                node.select = True; tree.nodes.active = node
                bpy.ops.object.bake(type='EMIT', margin=0)
                path = out/(variant+'-'+name+'-'+channel+'.png')
                image.filepath_raw = str(path); image.file_format = 'PNG'; image.save()
                records.append({'variant': variant, 'material': name, 'channel': channel,
                    'path': str(path), 'sha256': sha(path), 'size': size,
                    'source_images': source_images, 'palette_reconstruction': palette})
                tree.nodes.remove(node); bpy.data.images.remove(image)
            bpy.data.materials.remove(material); bpy.data.node_groups.remove(nested)
    (out/'bake.json').write_text(json.dumps({'runtime_approved': False,
        'source_sha256': job['source_sha256'], 'worker_sha256': sha(__file__),
        'job_sha256': sha(sys.argv[sys.argv.index('--')+1]), 'textures': records}, indent=2)+'\n')


if __name__ == '__main__':
    bake(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
