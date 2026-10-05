"""Export Charmander's pinned native breath clips as a skeletal motion carrier.

Run with isolated Blender: -- SOURCE_BLEND IMPORTER PYTHON_DEPS MOTION_DIR OUTPUT_GLB.
No source files are saved; carrier materials are omitted for animation-only use.
"""
import hashlib
import sys
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).parent))
from append_scvi_action_worker import _load_importer
from blender_action_state import select_action

SOURCE_SHA = 'ab6631a336987bf81b0db47e9b35be202e24bb98d07468db4c4e18ee60371489'
PARTS = {
    'breath_start': ('00460_rangeattack02_start', '6a95f9948023401b362da982d21f2c320562d4078c56b6f6a0a08dd07f34bd80'),
    'breath_loop': ('00461_rangeattack02_loop', 'a8051d615f5f58ad7b1db8a4829170e02b1620580f92e8e63a295c0ebac9cba4'),
    'breath_end': ('00462_rangeattack02_end', '376b54185fb9f73c68c0fa48fdd7aa2b3ca7d96bd440c1708994638ce7361d1e'),
}

def run():
    source, importer, deps, motion_dir, output = map(Path, sys.argv[sys.argv.index('--') + 1:])
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA
    assert not output.exists()
    sys.path.insert(0, str(deps))
    _load_importer(importer)
    from pokeaether_scvi_importer.gfbanm_importer import import_animation
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    assert len(rigs) == 1
    rig = rigs[0]
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    for name, (suffix, digest) in PARTS.items():
        motion = motion_dir / ('pm0004_00_00_' + suffix + '.tranm')
        assert hashlib.sha256(motion.read_bytes()).hexdigest() == digest
        import_animation(bpy.context, str(motion), False, 0, False, False)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    select_action(rig, bpy.data.actions['pm0004_00_00_00001_battlewait01_loop'])
    rig.animation_data.action = None
    for name, (suffix, _) in PARTS.items():
        action = bpy.data.actions['pm0004_00_00_' + suffix]
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        assert len(action.slots) == 1
        strip.action_slot = action.slots[0]
        strip.action_frame_start, strip.action_frame_end = action.frame_range
        strip.frame_start, strip.frame_end = 0, action.frame_range[1] - action.frame_range[0]
        track.mute = True
    for obj in bpy.context.view_layer.objects:
        obj.select_set(obj.type in ('MESH', 'ARMATURE'))
    bpy.context.scene.frame_set(0)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
        export_animation_mode='NLA_TRACKS', export_animations=True, export_force_sampling=True,
        export_frame_range=False, export_reset_pose_bones=True, export_frame_step=1,
        export_cameras=False, export_lights=False, export_materials='NONE', export_yup=True)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA
    print('CHARMANDER_BREATH_EXPORTED', hashlib.sha256(output.read_bytes()).hexdigest())

if __name__ == '__main__':
    run()
