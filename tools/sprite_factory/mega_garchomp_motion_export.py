"""Export native Mega Garchomp skeletal clips for posture review, without materials.

The GLB is an intermediate animation carrier. Its geometry is never admitted;
use only its AnimationLibrary after checking the approved runtime's skeleton.
"""
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Matrix


def main(job):
    source = Path(job['source'])
    report = json.loads(source.with_name('import.json').read_text())
    assert report['identity'] == 'pm0445_51_00'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == report['prepared_sha256']
    for path, expected in report['source_files'].items():
        assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == expected
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    assert len(rigs) == 1
    rig = rigs[0]
    rig.animation_data_create()
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    timing = {}
    for name, entry in report['actions'].items():
        if not entry:
            continue
        assert entry['name'].startswith('pm0445_51_00_0')
        action = bpy.data.actions[entry['name']]
        assert len(action.slots) == 1
        start, end = action.frame_range
        assert end > start
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.action_slot = action.slots[0]
        strip.action_frame_start, strip.action_frame_end = start, end
        strip.frame_start, strip.frame_end = 0, end-start
        track.mute = True
        timing[name] = {'source_action': entry['name'], 'duration': (end-start)/60,
                        'loop': name in ('idle', 'sleep', 'faint_loop')}
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.view_layer.objects:
        if obj.type in ('MESH', 'ARMATURE'):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.scene.frame_set(0)
    target = Path(job['output'])/'motion.glb'
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True,
        export_animation_mode='NLA_TRACKS', export_animations=True, export_force_sampling=True,
        export_hierarchy_flatten_bones=True, export_frame_range=False, export_reset_pose_bones=True,
        export_frame_step=1, export_cameras=False, export_lights=False, export_materials='NONE', export_yup=True)
    receipt = {'source_sha256': report['prepared_sha256'], 'glb_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
               'animations': timing, 'policy': 'skeletal_animation_carrier_only_no_material_export'}
    (target.parent/'motion.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print('MEGA_GARCHOMP_MOTION_EXPORTED')


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text()))
