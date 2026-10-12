"""Bake the authored Unown normal/shiny graph, preserving source texture resolution.

Blender worker; never changes source Blend files or existing qualification outputs.
The palette selector is bound by explicit graph links, including the eye driver.
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


def bake(job):
    source = Path(job['source'])
    assert sha(source) == job['source_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    assert set(job['materials']) == {'body', 'eye'}
    originals = {name: bpy.data.materials[name] for name in job['materials']}
    reference = json.loads(Path(job['palette_reference']).read_text())
    assert sha(job['palette_reference']) == job['palette_reference_sha256']
    shared = {i['name']:i['packed_sha256'] for i in reference['images'] if i['name'].startswith('pm0201_11_00_')}
    for image in bpy.data.images:
        if image.name in shared:
            assert image.packed_file and hashlib.sha256(image.packed_file.data).hexdigest()==shared[image.name]
    bindings = {'body': [('Mix (Legacy)', 'Mix (Legacy).010')],
                'eye': [('Mix (Legacy).001', 'Mix (Legacy).010'), ('Mix (Legacy).002', 'Mix (Legacy).009')]}
    palettes = {}
    for name, material in originals.items():
        assert 'Mix (Legacy).011' not in material.node_tree.nodes
        refnodes={n['name']:n for n in reference['materials'][name]['nodes']}
        palettes[name]=[]
        for normal_node, shiny_node in bindings[name]:
            node=material.node_tree.nodes[normal_node]
            assert node.type=='MIX_RGB' and node.blend_type=='MIX' and not node.inputs['Color2'].is_linked
            palettes[name].append((node.inputs['Color2'],list(node.inputs['Color2'].default_value),refnodes[shiny_node]['inputs']['Color2']))
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.mesh.primitive_plane_add()
    plane = bpy.context.object
    plane.data.uv_layers.active.name = 'UVMap'
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 1
    records = []
    out = Path(job['output']); out.mkdir(parents=True, exist_ok=True)
    for variant, selected in [('normal', 0.0), ('shiny', 1.0)]:
        for items in palettes.values():
            for socket, normal, shiny in items: socket.default_value = normal if variant=='normal' else shiny
        for name, authored in originals.items():
            inputs = [bpy.data.images[n] for n in material_images(authored.node_tree)]
            size = [max(i.size[axis] for i in inputs) for axis in (0, 1)]
            assert 0 < min(size) <= max(size) <= 4096
            material = authored.copy(); tree = material.node_tree
            principled, = [n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED']
            base, = list(principled.inputs['Base Color'].links)
            output, = [n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL']
            emission = tree.nodes.new('ShaderNodeEmission')
            tree.links.new(base.from_socket, emission.inputs['Color'])
            tree.links.new(emission.outputs[0], output.inputs['Surface'])
            plane.data.materials.clear(); plane.data.materials.append(material)
            image = bpy.data.images.new('recovery_'+variant+'_'+name, width=size[0], height=size[1], alpha=True)
            image.colorspace_settings.name = 'sRGB'
            node = tree.nodes.new('ShaderNodeTexImage'); node.image = image
            for n in tree.nodes: n.select = False
            node.select = True; tree.nodes.active = node
            bpy.ops.object.bake(type='EMIT', margin=0)
            path = out/(variant+'-'+name+'.png')
            image.filepath_raw = str(path); image.file_format = 'PNG'; image.save()
            records.append({'variant':variant, 'material':name, 'path':str(path),
                'sha256':sha(path), 'size':size, 'selector':selected,
                'source_images': {i.name: {'size':list(i.size), 'sha256':hashlib.sha256(i.packed_file.data).hexdigest()} for i in inputs}})
            bpy.data.materials.remove(material); bpy.data.images.remove(image)
    (out/'bake.json').write_text(json.dumps({'source_sha256':job['source_sha256'],
        'worker_sha256':sha(__file__), 'policy':'shared-unown-source-palette-v1', 'palette_reference_sha256':job['palette_reference_sha256'], 'textures':records}, indent=2)+'\n')


if __name__ == '__main__':
    bake(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
