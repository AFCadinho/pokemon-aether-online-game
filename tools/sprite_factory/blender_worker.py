"""Trusted worker: always launched with --factory-startup --disable-autoexec.

Never executes text blocks or saves a .blend. Inspection does not render.
"""
import bpy
import json
import math
import sys
import time
from pathlib import Path
from mathutils import Vector


def bounds():
    points = []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            points.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
            evaluated.to_mesh_clear()
    return [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)] if points else []


def inspect():
    scene = bpy.context.scene
    warnings = []
    images = []
    for im in bpy.data.images:
        if im.type == 'RENDER_RESULT':
            continue
        embedded = bool(im.packed_file or im.packed_files)
        path = bpy.path.abspath(im.filepath) if im.filepath else ''
        missing = not embedded and im.source == 'FILE' and not Path(path).is_file()
        if missing:
            warnings.append('missing_texture:' + im.name)
        if im.source not in ('FILE', 'GENERATED', 'VIEWER'):
            warnings.append('unsupported_texture_source:' + im.name)
        images.append(dict(name=im.name, source=im.source, embedded=embedded,
                           path=path, missing=missing, size=list(im.size)))
    objects = []
    for obj in scene.objects:
        ad = obj.animation_data
        nla = [] if not ad else [dict(name=t.name, mute=t.mute, strips=[dict(
            name=s.name, action=s.action.name if s.action else None,
            range=[s.frame_start, s.frame_end]) for s in t.strips]) for t in ad.nla_tracks]
        objects.append(dict(name=obj.name, type=obj.type, nla=nla,
                            action=ad.action.name if ad and ad.action else None,
                            materials=[s.material.name if s.material else None for s in obj.material_slots]))
        if nla:
            warnings.append('nla_tracks:' + obj.name)
        if obj.type == 'MESH' and (not obj.material_slots or any(not s.material for s in obj.material_slots)):
            warnings.append('missing_material:' + obj.name)
    if bpy.data.texts:
        warnings.append('embedded_text_blocks')
    blocks = list(bpy.data.objects) + list(bpy.data.materials) + list(bpy.data.shape_keys) + list(bpy.data.node_groups)
    blocks += [m.node_tree for m in bpy.data.materials if m.node_tree]
    drivers = [o.name for o in blocks if o.animation_data and o.animation_data.drivers]
    def reaches_output(node, visited=None):
        visited = set() if visited is None else visited
        if node.name in visited:
            return False
        visited.add(node.name)
        if node.type == 'OUTPUT_MATERIAL':
            return node.is_active_output
        for socket in node.outputs:
            for link in socket.links:
                dest = link.to_node
                if dest.type == 'BSDF_PRINCIPLED' and link.to_socket.name == 'Emission Color':
                    strength = dest.inputs['Emission Strength']
                    if not strength.is_linked and strength.default_value == 0:
                        continue
                if reaches_output(dest, visited.copy()):
                    return True
        return False
    for mat in bpy.data.materials:
        if mat.node_tree:
            outputs = [n for n in mat.node_tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output]
            if not outputs or not outputs[0].inputs['Surface'].is_linked:
                warnings.append('disconnected_material_output:' + mat.name)
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image is None:
                    connected = reaches_output(node)
                    warnings.append(('missing_texture_node:' if connected else 'unused_empty_texture_node:') + mat.name + '/' + node.name)
    if drivers:
        warnings.append('object_drivers')
    if bpy.data.libraries:
        warnings.append('linked_libraries')
    report = dict(blender=bpy.app.version_string, blender_build=bpy.app.build_hash.decode(), fps=scene.render.fps / scene.render.fps_base,
                  objects=objects, armatures=[o.name for o in scene.objects if o.type == 'ARMATURE'],
                  armature_bones={o.name: [b.name for b in o.data.bones] for o in scene.objects if o.type == 'ARMATURE'},
                  actions=[dict(name=a.name, range=list(a.frame_range),
                                slots=[s.identifier for s in a.slots]) for a in bpy.data.actions],
                  materials=[m.name for m in bpy.data.materials], images=images,
                  texts=[t.name for t in bpy.data.texts], drivers=drivers,
                  libraries=[l.filepath for l in bpy.data.libraries], bounds=bounds(),
                  variant_candidates=[x.name for x in list(bpy.data.images) + list(bpy.data.materials)
                                      if any(k in x.name.lower() for k in ('shiny', 'rare', 'variant'))],
                  warnings=warnings)
    report['action_candidates'] = {category: [a.name for a in bpy.data.actions if any(tag in a.name.lower() for tag in tags)]
        for category, tags in {'idle': ['battlewait', 'ba10_wait'], 'physical_attack': ['attack01', 'buturi'],
        'special_attack': ['rangeattack', 'tokusyu'], 'damage': ['damage', '_hit'], 'sleep': ['sleep'],
        'faint_start': ['down01_start', 'ba41_down'], 'faint_loop': ['down01_loop']}.items()}
    return report


def render(job):
    cfg, output = job['manifest'], Path(job['output'])
    scene = bpy.context.scene
    rig = scene.objects[cfg['rig']]
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for obj in list(scene.objects):
        if obj.type in ('LIGHT', 'CAMERA'):
            bpy.data.objects.remove(obj, do_unlink=True)
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.fps, scene.render.fps_base = cfg['render']['fps'], 1.0
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.render.image_settings.compression = int(job.get(
        'png_compression', cfg['render'].get('png_compression', 15)))
    if hasattr(scene, 'eevee'):
        scene.eevee.taa_render_samples = int(job.get(
            'taa_render_samples', cfg['render'].get(
                'taa_render_samples', scene.eevee.taa_render_samples)))
    taa_render_samples = int(scene.eevee.taa_render_samples) if hasattr(scene, 'eevee') else None
    scene.view_settings.view_transform = cfg['render']['view_transform']
    scene.view_settings.look = cfg['render']['look']
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    if 'world_color' in cfg['render']:
        scene.world.color = cfg['render']['world_color']
    def aim(obj, target):
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    for i, lamp in enumerate(cfg['render']['lights']):
        data = bpy.data.lights.new('FactoryLight' + str(i), 'AREA')
        data.energy, data.size, data.shape = lamp['energy'], lamp['size'], 'DISK'
        obj = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(obj)
        obj.location = lamp['position']
        aim(obj, cfg['render']['light_target'])
    data = bpy.data.cameras.new('FactoryCamera')
    data.type = 'ORTHO'
    camera = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    # Explicit replacements only: no inferred recolouring or shiny synthesis.
    for old, new in cfg['variants'][job['variant']].get('material_overrides', {}).items():
        for obj in scene.objects:
            for slot in obj.material_slots:
                if slot.material and slot.material.name == old:
                    slot.material = bpy.data.materials[new]
    geometry = {}
    facial_warnings = []
    timings = dict(frame_setup_seconds=0.0, geometry_seconds=0.0, render_seconds=0.0)
    geometry_scan = bool(job.get('geometry_scan', cfg['render'].get('geometry_scan', True)))
    batch_animation = bool(job.get('batch_animation', cfg['render'].get('batch_animation', False)))
    for view, cam in cfg['cameras'].items():
        camera.location, data.ortho_scale = cam['position'], cam['ortho_scale']
        aim(camera, cam['target'])
        inverse = camera.rotation_euler.to_matrix().inverted()
        geometry[view] = {}
        for category, spec in cfg['actions'].items():
            if spec is None:
                continue
            action = bpy.data.actions[spec['action']]
            rig.animation_data.action = action
            if spec.get('slot'):
                rig.animation_data.action_slot = next(s for s in action.slots if s.identifier == spec['slot'])
            elif len(action.slots) == 1:
                rig.animation_data.action_slot = action.slots[0]
            frames = spec['frames']
            neutral_bones = [rig.pose.bones[name] for name in spec.get('neutral_bones', [])]
            destination = output / 'masters' / view / category
            destination.mkdir(parents=True, exist_ok=True)
            records = []
            eyelid_angles = {bone.name: [] for bone in rig.pose.bones if 'eyelid' in bone.name.lower() and 'sub' not in bone.name.lower()} if category == 'idle' else {}
            can_batch = (batch_animation and not geometry_scan and frames and
                         all(float(frame).is_integer() for frame in frames) and
                         frames == list(range(int(frames[0]), int(frames[0]) + len(frames))))
            if can_batch:
                batch_destination = destination / '_batch'
                batch_destination.mkdir()

                def prepare_frame(_scene, _depsgraph):
                    for name, values in eyelid_angles.items():
                        values.append(rig.pose.bones[name].matrix_basis.to_quaternion().angle)
                    for bone in neutral_bones:
                        bone.matrix_basis.identity()
                    if neutral_bones:
                        bpy.context.view_layer.update()

                bpy.app.handlers.frame_change_post.append(prepare_frame)
                scene.frame_start = int(frames[0])
                scene.frame_end = int(frames[-1])
                scene.render.filepath = str(batch_destination) + '/'
                started = time.perf_counter()
                try:
                    bpy.ops.render.render(animation=True)
                finally:
                    bpy.app.handlers.frame_change_post.remove(prepare_frame)
                timings['render_seconds'] += time.perf_counter() - started
                for index, frame in enumerate(frames):
                    source = batch_destination / f'{int(frame):04}.png'
                    if not source.is_file():
                        raise RuntimeError('Batch render did not produce ' + str(source))
                    source.replace(destination / f'{index:04}.png')
                    records.append(dict(source_frame=frame))
                batch_destination.rmdir()
                geometry[view][category] = records
                for name, angles in eyelid_angles.items():
                    if name not in spec.get('neutral_bones', []) and min(angles) > 0.35 and max(angles) - min(angles) < 0.05:
                        facial_warnings.append(view + '/' + category + ':persistent_eyelid_pose:' + name)
                continue
            for index, frame in enumerate(frames):
                started = time.perf_counter()
                scene.frame_set(int(frame), subframe=frame - int(frame))
                for name, values in eyelid_angles.items():
                    values.append(rig.pose.bones[name].matrix_basis.to_quaternion().angle)
                # Some source actions include a persistent facial pose (for example closed
                # eyelids in battle idle). Explicit manifest overrides restore only the
                # named bones to their rest transforms, after evaluating every frame.
                for bone in neutral_bones:
                    bone.matrix_basis.identity()
                if neutral_bones:
                    bpy.context.view_layer.update()
                timings['frame_setup_seconds'] += time.perf_counter() - started
                # Full evaluated vertex bounds at EVERY rendered frame, including alpha-invisible meshes.
                started = time.perf_counter()
                if geometry_scan:
                    graph = bpy.context.evaluated_depsgraph_get()
                    coords = []
                    for obj in scene.objects:
                        if obj.type != 'MESH' or obj.hide_render:
                            continue
                        ev = obj.evaluated_get(graph)
                        mesh = ev.to_mesh()
                        coords.extend(inverse @ (ev.matrix_world @ v.co - Vector(cam['target'])) for v in mesh.vertices)
                        ev.to_mesh_clear()
                    extent = max((max(abs(p.x), abs(p.y)) for p in coords), default=0)
                    records.append(dict(source_frame=frame, extent=extent,
                                        outside=extent > data.ortho_scale * 0.5))
                timings['geometry_seconds'] += time.perf_counter() - started
                scene.render.filepath = str(destination / f'{index:04}.png')
                started = time.perf_counter()
                bpy.ops.render.render(write_still=True)
                timings['render_seconds'] += time.perf_counter() - started
            geometry[view][category] = records
            for name, angles in eyelid_angles.items():
                if name not in spec.get('neutral_bones', []) and min(angles) > 0.35 and max(angles) - min(angles) < 0.05:
                    facial_warnings.append(view + '/' + category + ':persistent_eyelid_pose:' + name)
    return dict(blender=bpy.app.version_string, blender_build=bpy.app.build_hash.decode(), geometry=geometry,
                engine=scene.render.engine, fps=cfg['render']['fps'], resolution=[512, 512],
                facial_warnings=facial_warnings, geometry_scan=geometry_scan,
                batch_animation=batch_animation, taa_render_samples=taa_render_samples,
                timings=timings)


if __name__ == '__main__':
    job_path = Path(sys.argv[sys.argv.index('--') + 1])
    job = json.loads(job_path.read_text())
    result = inspect() if job['mode'] == 'inspect' else render(job)
    Path(job['result']).write_text(json.dumps(result, indent=2))
