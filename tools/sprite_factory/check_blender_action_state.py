"""Focused Blender regression: partial clips must not inherit previous poses.

Run with --factory-startup --disable-autoexec --python-exit-code 1.
Optional argument after -- is a phase5 catalog directory (read-only).
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from blender_action_state import select_action


def snapshot(rig, action, frame):
    select_action(rig, action)
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    return tuple(value for bone in rig.pose.bones for row in bone.matrix for value in row)


def fixture():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.object.armature_add()
    rig = bpy.context.object
    bone = rig.pose.bones[0]
    bone.rotation_mode = 'QUATERNION'
    rig.animation_data_create()
    closed = bpy.data.actions.new('closed')
    rig.animation_data.action = closed
    bone.location = (0, 0, 3)
    bone.keyframe_insert('location', frame=0)
    # Idle deliberately has no location track, like an omitted eyelid track.
    idle = bpy.data.actions.new('partial_idle')
    rig.animation_data.action = idle
    bone.scale = (1, 1, 1)
    bone.keyframe_insert('scale', frame=0)
    rig.animation_data.action = closed
    bpy.context.scene.frame_set(0)
    rig.animation_data.action = idle
    bpy.context.scene.frame_set(0)
    assert abs(bone.location.z - 3) < 1e-6, 'Fixture no longer reproduces leakage'
    snapshot(rig, idle, 0)
    assert abs(bone.location.z) < 1e-6, 'Partial clip inherited previous translation'
    snapshot(rig, closed, 0)
    assert abs(bone.location.z - 3) < 1e-6, 'Explicit animation must not be neutralized'
    print('PASS partial-track reset and explicit-track preservation', flush=True)


def cohort(root):
    catalog = json.loads((root / 'catalog.json').read_text())
    for entry in catalog['entries']:
        assert entry['status'] == 'source_review_only', entry
        report_path = Path(entry['report'])
        report = json.loads(report_path.read_text())
        job = json.loads((report_path.parent / 'job.json').read_text())
        source = Path(job['source'])
        assert hashlib.sha256(source.read_bytes()).hexdigest() == job['source_sha256']
        bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
        rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
        assert len(rigs) == 1
        rig = rigs[0]
        for track in rig.animation_data.nla_tracks:
            track.mute = True
        cases = []
        for category, name in report['review_mapping'].items():
            action = bpy.data.actions[name]
            lo, hi = action.frame_range
            for fraction in (0, 0.5, 1):
                cases.append((category, action, lo + (hi - lo) * fraction))
        expected = [snapshot(rig, action, frame) for _, action, frame in cases]
        largest_error = 0
        for index in reversed(range(len(cases))):
            _, action, frame = cases[index]
            # Poison unkeyed transforms as an arbitrary preceding action would.
            rig.animation_data.action = None
            for bone in rig.pose.bones:
                bone.location = (0.3, -0.2, 0.7)
                bone.scale = (1.1, 0.9, 1.2)
            actual = snapshot(rig, action, frame)
            error = max(abs(a - b) for a, b in zip(actual, expected[index]))
            largest_error = max(largest_error, error)
            assert error < 1e-5, (entry['species'], action.name, frame, error)
        print('PASS', entry['species'], len(cases), 'samples; max_order_error=', largest_error,
              flush=True)


fixture()
if '--' in sys.argv:
    cohort(Path(sys.argv[sys.argv.index('--') + 1]))
