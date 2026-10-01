"""Disposable source-mesh fire bake; review only, no source files are saved.

Keep generated coordinates, source UVs and vertex attributes on real meshes.
This is a static idle-frame approximation of procedural fire, not a recovery
of the original time-varying material animation.
"""
import hashlib
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import isolate
from blender_action_state import select_action
from catalog_animation_material_worker import replace_uv, colour_sockets


def main(job):
    assert hashlib.sha256(Path(job['source']).read_bytes()).hexdigest() == job['source_sha256']
    bpy.ops.wm.open_mainfile(filepath=job['source'], use_scripts=False, load_ui=False)
    rig, selection = isolate(job['source'])
    select_action(rig, bpy.data.actions[job['idle_action']])
    bpy.context.scene.frame_set(1)
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 1
    receipts = []
    for item in job['materials']:
        candidates = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.hide_render
                      and any(o.data.materials[face.material_index]
                              and o.data.materials[face.material_index].name == item['name']
                              for face in o.data.polygons)]
        assert candidates, item['name']
        original = sorted(candidates, key=lambda o: o.name)[0]
        obj = original.copy()
        obj.data = original.data.copy()
        bpy.context.collection.objects.link(obj)
        # Keep the rest-space generated bounds, actual attributes and modifiers.
        obj.hide_render = False
        obj.hide_set(False)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        source_uv = obj.data.uv_layers.active
        assert source_uv is not None
        original_uv_name = source_uv.name
        source_uv.name = 'SourceUV'
        bake_uv = obj.data.uv_layers.new(name='BakeUV', do_init=False)
        x0, y0, x1, y1 = item.get('source_uv_domain', [0, 0, 1, 1])
        for i, corner in enumerate(source_uv.data):
            bake_uv.data[i].uv = ((corner.uv.x-x0)/(x1-x0), (corner.uv.y-y0)/(y1-y0))
        obj.data.uv_layers.active = bake_uv
        bake_uv.active_render = True
        target = None
        for i, material in enumerate(list(obj.data.materials)):
            if material is None:
                continue
            copied = material.copy()
            obj.data.materials[i] = copied
            dummy = bpy.data.images.new('unused', width=512, height=512)
            node = copied.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = dummy
            copied.node_tree.nodes.active = node
            if material.name == item['name']:
                target = copied
        assert target
        tree = target.node_tree
        replace_uv(tree)
        # Explicit named UV nodes must follow the renamed source layer too.
        for node in tree.nodes:
            if node.type == 'UVMAP' and node.uv_map == original_uv_name:
                node.uv_map = 'SourceUV'
        output = next(n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
        colour, alpha, glow = colour_sockets(tree, output.inputs['Surface'].links[0].from_socket, True)
        emission = tree.nodes.new('ShaderNodeEmission')
        tree.links.new(emission.outputs[0], output.inputs['Surface'])
        opacity_material = None
        if item.get('opacity_material'):
            # Evaluate the explicitly selected core opacity graph ON this
            # outer mesh's SourceUV/Generated coordinates, never stretch a
            # baked image across incompatible UV domains.
            opacity_material = bpy.data.materials[item['opacity_material']].copy()
            opacity_tree = opacity_material.node_tree
            replace_uv(opacity_tree)
            for node in opacity_tree.nodes:
                if node.type == 'UVMAP' and node.uv_map == original_uv_name:
                    node.uv_map = 'SourceUV'
            opacity_output = next(n for n in opacity_tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
            _, source_alpha, _ = colour_sockets(opacity_tree, opacity_output.inputs['Surface'].links[0].from_socket, True)
            opacity_emission = opacity_tree.nodes.new('ShaderNodeEmission')
            opacity_tree.links.new(source_alpha, opacity_emission.inputs['Color'])
            opacity_tree.links.new(opacity_emission.outputs[0], opacity_output.inputs['Surface'])
        target_index = next(i for i,m in enumerate(obj.data.materials) if m == target)
        images = []
        for label, socket in [('colour', colour), ('alpha', alpha), ('glow', glow)]:
            image = bpy.data.images.new(item['name']+label, width=512, height=512,
                                        alpha=True, float_buffer=True, is_data=label == 'alpha')
            node = tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            tree.nodes.active = node
            tree.links.new(socket, emission.inputs['Color'])
            if label == 'alpha' and opacity_material:
                node = opacity_tree.nodes.new('ShaderNodeTexImage')
                node.image = image
                opacity_tree.nodes.active = node
                obj.data.materials[target_index] = opacity_material
            bpy.ops.object.bake(type='EMIT', margin=2)
            obj.data.materials[target_index] = target
            images.append(image)
        pixels, opacity, glow_pixels = [list(im.pixels) for im in images]
        peak = max(v for i,v in enumerate(glow_pixels) if i % 4 != 3)
        strength = max(1.0, peak)
        # PNG clips emission above one; normalize first to preserve its hues.
        images[2].pixels.foreach_set([v/strength if i % 4 != 3 else v
                                     for i,v in enumerate(glow_pixels)])
        for i in range(3, len(pixels), 4):
            pixels[i] = max(0, min(1, opacity[i-3]))
        images[0].pixels.foreach_set(pixels)
        for image, path in [(images[0], item['output']), (images[2], item['glow_output'])]:
            image.filepath_raw = path
            image.file_format = 'PNG'
            image.save()
        receipts.append({'material': item['name'], 'mesh': original.name,
                         'source_uv_domain': [x0,y0,x1,y1],
                         'other_visible_meshes': [o.name for o in candidates[1:]],
                         'static_frame': 1, 'glow_peak': peak,
                         'glow_normalization': strength,
                         'opacity_material': item.get('opacity_material'),
                         'source_mesh_bake': True})
        bpy.data.objects.remove(obj, do_unlink=True)
    Path(job['receipt']).write_text(json.dumps(receipts, indent=2)+'\n')


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
