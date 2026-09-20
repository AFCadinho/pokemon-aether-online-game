"""Disposable glTF probe. Launch Blender with --factory-startup --disable-autoexec.

Only the four reviewed source files in the supplied job are opened. Never saves
blend files or changes source assets. Direct export exposes unsupported material
translation; the optional color bake is an explicitly simplified prototype.
"""
import hashlib
import json
import struct
import sys
import time
from pathlib import Path

import bpy


def bake_color_materials():
    """Extract the imported shader's color/mask/eyelid chain, then plain PBR.

    This prototype retains albedo detail/resolution, but does not translate the
    original roughness/normal/emission shader. It is not visual parity.
    """
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 1
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.margin = 8
    records = []
    prepared = {}
    meshes = [obj for obj in scene.objects if obj.type == 'MESH']
    for obj in meshes:
        for material in obj.data.materials:
            if material.name in prepared:
                continue
            tree = material.node_tree
            group = next(n for n in tree.nodes if n.type == 'GROUP' and 'BaseColorBake' in n.outputs)
            # The supplied BaseColorBake socket differs from the active shader
            # on some materials. Preserve its actual color/layer/eyelid path,
            # substituting only its Eevee-dependent lighting stage.
            graph = group.node_tree.copy()
            group.node_tree = graph
            for required in ('Group.001', 'Mix (Legacy).045', 'Mix (Legacy).040'):
                if required not in graph.nodes:
                    raise ValueError('Unsupported imported shader graph: ' + required)
            graph.links.new(graph.nodes['Group.001'].outputs['Color'], graph.nodes['Mix (Legacy).045'].inputs['Color1'])
            graph.interface.new_socket(name='ProbeAlbedo', in_out='OUTPUT', socket_type='NodeSocketColor')
            group_output = next(n for n in graph.nodes if n.type == 'GROUP_OUTPUT' and n.is_active_output)
            graph.links.new(graph.nodes['Mix (Legacy).040'].outputs['Color'], group_output.inputs['ProbeAlbedo'])
            output_node = next(n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
            size = max((max(n.image.size) for n in tree.nodes if n.type == 'TEX_IMAGE' and n.image), default=512)
            image = bpy.data.images.new('ProbeAlbedo_' + material.name, width=size, height=size, alpha=False)
            target = tree.nodes.new('ShaderNodeTexImage')
            target.image = image
            tree.nodes.active = target
            emission = tree.nodes.new('ShaderNodeEmission')
            tree.links.new(group.outputs['ProbeAlbedo'], emission.inputs['Color'])
            tree.links.new(emission.outputs['Emission'], output_node.inputs['Surface'])
            prepared[material.name] = (material, image)
    # Bake the entire UV-domain shader on a plane so mesh UV coverage,
    # overlapping faces and active bake UV selection cannot discard regions.
    for material, _image in prepared.values():
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_plane_add()
        plane = bpy.context.object
        plane.data.materials.append(material)
        bpy.ops.object.bake(type='EMIT')
        mesh = plane.data
        bpy.data.objects.remove(plane, do_unlink=True)
        bpy.data.meshes.remove(mesh)
    for material, image in prepared.values():
        tree = material.node_tree
        tree.nodes.clear()
        out = tree.nodes.new('ShaderNodeOutputMaterial')
        bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.inputs['Roughness'].default_value = 0.65
        texture = tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        tree.links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
        tree.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
        records.append(dict(material=material.name, albedo_size=list(image.size)))
    return records


def export_entry(entry, output):
    source = Path(entry['source'])
    cfg = entry['manifest']
    if hashlib.sha256(source.read_bytes()).hexdigest() != cfg['source']['sha256']:
        raise ValueError('Unreviewed source: ' + str(source))
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    if bpy.data.libraries:
        raise ValueError('Linked libraries are outside this probe')
    scene = bpy.context.scene
    scene.render.fps = 60
    scene.render.fps_base = 1.0
    rig = scene.objects[cfg['rig']]
    rig.animation_data_create()
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    selected = []
    for name, spec in cfg['actions'].items():
        if not spec:
            continue
        if spec.get('neutral_bones'):
            raise ValueError('Needs explicit neutral-bone baking: ' + name)
        frames = spec['frames']
        if frames != list(range(int(frames[0]), int(frames[-1]) + 1)):
            raise ValueError('Non-contiguous source animation: ' + name)
        action = bpy.data.actions[spec['action']]
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        if hasattr(strip, 'action_slot') and action.slots:
            strip.action_slot = next((s for s in action.slots if s.identifier == spec.get('slot')), action.slots[0])
        strip.action_frame_start = frames[0]
        strip.action_frame_end = frames[-1]
        strip.frame_start = 0
        strip.frame_end = frames[-1] - frames[0]
        track.mute = True
        selected.append(name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scene.objects:
        if obj.type in ('MESH', 'ARMATURE'):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    scene.frame_set(0)
    baked = bake_color_materials() if job.get('bake_colors') else []
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scene.objects:
        if obj.type in ('MESH', 'ARMATURE'):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = output / (cfg['species'] + '.glb')
    started = time.perf_counter()
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='NLA_TRACKS',
        export_frame_range=False, export_force_sampling=True, export_frame_step=1,
        export_optimize_animation_size=True, export_materials='EXPORT',
        export_image_format='AUTO', export_cameras=False, export_lights=False,
        export_yup=True, export_skins=True, export_morph=True)
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    animations = {a.get('name', ''): len(a['channels']) for a in gltf.get('animations', [])}
    if set(animations) != set(selected):
        raise ValueError(f'Exported actions differ: {animations} expected {selected}')
    image_bytes = sum(gltf['bufferViews'][i['bufferView']]['byteLength'] for i in gltf.get('images', []))
    triangles = sum(gltf['accessors'][p['indices']]['count'] // 3 for m in gltf['meshes'] for p in m['primitives'])
    return dict(species=cfg['species'], path=str(path), bytes=len(data),
        compressed_texture_bytes=image_bytes, triangles=triangles,
        materials=len(gltf.get('materials', [])), textures=len(gltf.get('images', [])),
        bones=sum(len(s['joints']) for s in gltf.get('skins', [])),
        animations=animations, export_seconds=time.perf_counter()-started,
        cameras=cfg['cameras'], extensions=gltf.get('extensionsUsed', []),
        source_sha256=cfg['source']['sha256'], baked_albedo=baked,
        material_limitations='Simplified PBR: original normals, roughness, emission and alpha not translated' if baked else 'Direct exporter translation, requires inspection')


job = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
output = Path(job['output'])
output.mkdir(parents=True, exist_ok=False)
results = []
for entry in job['entries']:
    results.append(export_entry(entry, output))
    (output / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
