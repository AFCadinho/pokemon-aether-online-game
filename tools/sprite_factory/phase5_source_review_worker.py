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
from blender_action_state import select_action
from source_review_rigs import isolate, equivalent_action_names


def run(job, material_intervention=None, camera_bounds=None):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Source changed before review')
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rig, rig_selection = isolate(source)
    report = inspect()
    report['rig_selection'] = rig_selection
    if job.get('material_source'):
        from material_profiles import read_profiles
        report['material_profiles'] = read_profiles(job['material_source'], job['material_source_sha256'])
    evaluate_material = None
    if job.get('material_probe_policy'):
        from scvi_material_probe import POLICY, apply_probe
        if job['material_probe_policy'] != POLICY:
            raise ValueError('Unknown material probe policy')
        report['material_probe'] = apply_probe(job['material_probe_metadata'], job.get('displacement_probe', False))
        if job.get('ambient_material_probe'):
            from blender_ambient_probe import prepare
            evaluate_material = prepare(job['material_probe_metadata'], job['ambient_material_probe'])
            report['ambient_material_probe'] = {
                'source': job['ambient_source'], 'sha256': job['ambient_sha256'],
                'duration_seconds': (job['ambient_material_probe']['frames'] - 1) / job['ambient_material_probe']['fps'],
                'hypotheses': ['unlit source base colour', 'UVScaleOffset to UV1; UVScaleOffset3 to displacement UV2'],
                'runtime_approved': False}
    if material_intervention is not None:
        report['diagnostic_intervention'] = material_intervention(job)
    report.update(species=job['species'], source_sha256=job['source_sha256'],
                  scope=('experimental_opacity_probe_not_runtime_approval' if job.get('material_probe_policy')
                         else 'source_only_not_runtime_approval'),
                  pose_initialization='rest_before_each_clip', poses=[])
    output = Path(job['output'])
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    mapping = dict(job['actions'])
    if not mapping:
        names = equivalent_action_names(bpy.data.actions)
        report['animation_bank'] = job.get('animation_bank')
        report['review_action_candidates'] = candidates(names, bank=job.get('animation_bank'))
        mapping = {name: matches[0] for name, matches in report['review_action_candidates'].items()
                   if len(matches) == 1}
    report['review_mapping'] = mapping
    from source_repairs import apply as apply_repair
    report['source_repair'] = apply_repair(job['source_sha256'], mapping.values())
    poses = []
    pose_specs = [('idle', 0.0, 'front', ''), ('idle', 0.5, 'back', ''),
                  ('physical_attack', 0.25, 'front', 'early'),
                  ('physical_attack', 0.5, 'front', ''),
                  ('physical_attack', 0.75, 'front', 'late'),
                  ('physical_attack_2', 0.25, 'front', 'early'),
                  ('physical_attack_2', 0.5, 'front', ''),
                  ('physical_attack_2', 0.75, 'front', 'late'),
                  ('special_attack', 0.5, 'front', ''), ('sleep', 0.5, 'front', ''),
                  ('faint_start', 1.0, 'front', '')]
    for category, fraction, view, sample in pose_specs:
        action = bpy.data.actions.get(mapping.get(category, ''))
        if action is None:
            report['poses'].append({'category': category, 'view': view, 'status': 'missing_or_ambiguous'})
            continue
        select_action(rig, action)
        frame = action.frame_range[0] + fraction * (action.frame_range[1] - action.frame_range[0])
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        if evaluate_material:
            evaluate_material(frame / report['fps'])
        box = bounds()
        poses.append((category, view, action, frame, box, sample))
    if not poses:
        raise ValueError('No unambiguous representative actions')
    low = Vector([min(pose[4][axis][0] for pose in poses) for axis in range(3)])
    high = Vector([max(pose[4][axis][1] for pose in poses) for axis in range(3)])
    report['review_bounds'] = [list(low), list(high)]
    if camera_bounds is not None:
        low, high = map(Vector, camera_bounds)
    report['camera_bounds'] = [list(low), list(high)]
    target = (low + high) / 2
    size = max((high - low).length * 1.12, 0.1)
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
    for category, view, action, frame, box, sample in poses:
        select_action(rig, action)
        scene.frame_set(int(frame), subframe=frame % 1)
        if evaluate_material:
            evaluate_material(frame / report['fps'])
        direction = Vector((3, -7, 2) if view == 'front' else (-3, 7, 2)).normalized()
        camera.location = target + direction * size * 3
        camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        filename = category + ('-' + sample if sample else '') + '-' + view + '.png'
        scene.render.filepath = str(output / filename)
        bpy.ops.render.render(write_still=True)
        report['poses'].append({'category': category, 'sample': sample, 'view': view, 'action': action.name,
                                'frame': frame, 'bounds': box, 'image': filename, 'status': 'rendered'})
    if evaluate_material:
        # Freeze the skeleton: image changes must come from material motion alone.
        select_action(rig, bpy.data.actions[mapping['idle']])
        scene.frame_set(0)
        report['ambient_frames'] = []
        duration = report['ambient_material_probe']['duration_seconds']
        for index in range(12):
            seconds = duration * index / 12
            values = evaluate_material(seconds)
            filename = f'ambient-{index:02d}.png'
            scene.render.filepath = str(output / filename)
            bpy.ops.render.render(write_still=True)
            report['ambient_frames'].append({'seconds': seconds, 'uv': values, 'image': filename})
    (output / 'review.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    run(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
