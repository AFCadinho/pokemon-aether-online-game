"""Trusted Blender source review; no source saves or embedded script execution."""
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
from blender_worker import bounds, inspect
from phase5_review_actions import candidates


def run(job):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Source changed before review')
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    report = inspect()
    report.update(species=job['species'], source_sha256=job['source_sha256'],
                  scope='source_only_not_runtime_approval', poses=[])
    output = Path(job['output'])
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    if len(rigs) != 1 or report['libraries']:
        raise ValueError('Expected one self-contained rig')
    rig = rigs[0]
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    mapping = dict(job['actions'])
    if not mapping:
        report['review_action_candidates'] = candidates([action.name for action in bpy.data.actions])
        mapping = {name: matches[0] for name, matches in report['review_action_candidates'].items()
                   if len(matches) == 1}
    report['review_mapping'] = mapping
    poses = []
    for category, fraction, view in [('idle', 0.0, 'front'), ('idle', 0.5, 'back'),
                                      ('special_attack', 0.5, 'front'), ('sleep', 0.5, 'front'),
                                      ('faint_start', 1.0, 'front')]:
        action = bpy.data.actions.get(mapping.get(category, ''))
        if action is None:
            report['poses'].append({'category': category, 'view': view, 'status': 'missing_or_ambiguous'})
            continue
        rig.animation_data.action = action
        if len(action.slots) == 1:
            rig.animation_data.action_slot = action.slots[0]
        frame = action.frame_range[0] + fraction * (action.frame_range[1] - action.frame_range[0])
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        box = bounds()
        poses.append((category, view, action, frame, box))
    if not poses:
        raise ValueError('No unambiguous representative actions')
    low = Vector([min(pose[4][axis][0] for pose in poses) for axis in range(3)])
    high = Vector([max(pose[4][axis][1] for pose in poses) for axis in range(3)])
    target = (low + high) / 2
    size = max((high - low).length * 1.12, 0.1)
    report['review_bounds'] = [list(low), list(high)]
    report['camera_ortho_scale'] = size
    scene = bpy.context.scene
    for obj in list(scene.objects):
        if obj.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(obj, do_unlink=True)
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 320
    scene.render.resolution_y = 320
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new('Phase5NeutralWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.12, 0.12, 0.12, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
    scene.view_settings.view_transform = 'Standard'
    for location, energy in [((3, -4, 6), 2.0), ((-4, 2, 4), 0.8)]:
        data = bpy.data.lights.new('ReviewSun', 'SUN')
        data.energy = energy
        obj = bpy.data.objects.new('ReviewSun', data)
        scene.collection.objects.link(obj)
        obj.rotation_euler = (-Vector(location)).to_track_quat('-Z', 'Y').to_euler()
    data = bpy.data.cameras.new('ReviewCamera')
    camera = bpy.data.objects.new('ReviewCamera', data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    data.type = 'ORTHO'
    data.ortho_scale = size
    data.clip_end = max(1000, size * 20)
    for category, view, action, frame, box in poses:
        rig.animation_data.action = action
        if len(action.slots) == 1:
            rig.animation_data.action_slot = action.slots[0]
        scene.frame_set(int(frame), subframe=frame % 1)
        direction = Vector((3, -7, 2) if view == 'front' else (-3, 7, 2)).normalized()
        camera.location = target + direction * size * 3
        camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        filename = category + '-' + view + '.png'
        scene.render.filepath = str(output / filename)
        bpy.ops.render.render(write_still=True)
        report['poses'].append({'category': category, 'view': view, 'action': action.name,
                                'frame': frame, 'bounds': box, 'image': filename, 'status': 'rendered'})
    (output / 'review.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    run(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
