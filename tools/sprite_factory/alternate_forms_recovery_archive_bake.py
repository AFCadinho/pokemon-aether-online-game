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
    selectors = {}
    for name, material in originals.items():
        tree = material.node_tree
        selector = tree.nodes['Mix (Legacy).011']
        assert selector.type == 'MIX_RGB' and selector.blend_type == 'MIX'
        assert not selector.inputs[0].is_linked
        links = {l.to_socket.name: l.from_node.name for l in tree.links if l.to_node == selector}
        assert links == {'Color1': 'Mix (Legacy)' if name == 'body' else 'Mix (Legacy).002',
                         'Color2': 'Mix (Legacy).010' if name == 'body' else 'Mix (Legacy).009'}
        selectors[name] = selector
    eye_drivers = list(originals['eye'].node_tree.animation_data.drivers)
    assert len(eye_drivers) == 1
    driver = eye_drivers[0]
    assert driver.data_path == 'nodes["Mix (Legacy).011"].inputs[0].default_value'
    assert driver.driver.expression == 'default_value'
    target = driver.driver.variables[0].targets[0]
    assert target.id == originals['body'] and target.data_path == 'node_tree.nodes["Mix (Legacy).011"].inputs[0].default_value'
    # Explicitly select both ends of the archived palette switch without
    # executing any embedded scripts or relying on disabled source drivers.
    originals['eye'].node_tree.animation_data_clear()
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
        for selector in selectors.values(): selector.inputs[0].default_value = selected
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
        'worker_sha256':sha(__file__), 'policy':'authored-unown-palette-switch-v1', 'textures':records}, indent=2)+'\n')


if __name__ == '__main__':
    bake(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
