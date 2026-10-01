"""Diagnostic own-SCVI-rig proposal from externally converted transform clips.

Only supports the inspected FBX export convention: X reflection, 100:1 local
translation units and source bone names. The caller must pin both inputs and
confirm the unit scale. No runtime registry or catalog approval is produced.
"""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector


def run(job):
    for key in ('source', 'motion'):
        if hashlib.sha256(Path(job[key]).read_bytes()).hexdigest() != job[key + '_sha256']:
            raise ValueError(key + ' hash changed')
    if job.get('verified_translation_scale') != 100:
        raise ValueError('Unverified FBX translation convention')
    if Path(job['output']).exists():
        raise ValueError('Output already exists; preserve prior evidence')
    bpy.ops.wm.open_mainfile(filepath=job['source'], use_scripts=False, load_ui=False)
    rigs = [obj for obj in bpy.data.objects if obj.type == 'ARMATURE']
    if len(rigs) != 1 or rigs[0].name != job['identity']:
        raise ValueError('Source rig identity differs')
    rig = rigs[0]
    rig.animation_data_create()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    data = json.loads(Path(job['motion']).read_text())
    if len({clip['fps'] for clip in data['clips']}) != 1:
        raise ValueError('Mixed clip sample rates require explicit resampling')
    bone_order = []

    def add(bone):
        bone_order.append(bone)
        for child in bone.children:
            add(child)

    for bone in rig.pose.bones:
        if bone.parent is None:
            add(bone)
    rest = {bone.name: (bone.parent.bone.matrix_local.inverted() @ bone.bone.matrix_local
                       if bone.parent else bone.bone.matrix_local.copy()) for bone in bone_order}
    nodes = {node['name']: node for node in data['nodes']}
    reports, seen = [], set()
    for clip in data['clips']:
        if clip['name'] in seen:
            continue
        seen.add(clip['name'])
        name = clip['name'].split('|')[-1].replace('.gfbanm', '')
        if not name.startswith(job['identity'] + '_'):
            raise ValueError('Animation identity differs from the source rig')
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        action.use_fake_user = True
        bpy.context.scene.render.fps = round(clip['fps'])
        bpy.context.scene.render.fps_base = round(clip['fps']) / clip['fps']
        keyed = set()
        previous_rotations = {}
        rest_overrides = set(job.get('rest_bone_overrides', {}).get(name, []))
        if not rest_overrides <= set(rest):
            raise ValueError('Unknown authored rest override bone')
        for frame in clip['frames']:
            source_globals = {}
            key_frame = frame['time'] * clip['fps']
            bpy.context.scene.frame_set(int(key_frame), subframe=key_frame % 1)
            for bone in bone_order:
                # Unity's model container can carry the FBX 100x unit scale.
                # It is not the SCVI skeleton root animation.
                track = frame['tracks'].get(bone.name) if bone.name != rig.name and bone.name not in rest_overrides else None
                if track:
                    node = nodes[bone.name]
                    position = track.get('1', node['position'])
                    rotation = track.get('2', node['rotation'])
                    scale = track.get('3', node['scale'])
                    matrix = Matrix.LocRotScale(
                        Vector((-position[0] * 100, position[1] * 100, position[2] * 100)),
                        Quaternion((rotation[3], rotation[0], -rotation[1], -rotation[2])).normalized(),
                        Vector(scale))
                else:
                    matrix = rest[bone.name]
                bone.rotation_mode = 'QUATERNION'
                if job.get('explicit_source_hierarchy'):
                    # Converted Unity local transforms include their own scale
                    # inheritance. Do not compose against Blender's evaluated
                    # parent, whose SCVI segment-scale policy can differ.
                    source_globals[bone.name] = (source_globals[bone.parent.name] @ matrix
                                                if bone.parent else matrix)
                    kwargs = ({'parent_matrix': source_globals[bone.parent.name],
                               'parent_matrix_local': bone.parent.bone.matrix_local}
                              if bone.parent else {})
                    bone.matrix_basis = bone.bone.convert_local_to_pose(
                        source_globals[bone.name], bone.bone.matrix_local,
                        invert=True, **kwargs)
                else:
                    bone.matrix = bone.parent.matrix @ matrix if bone.parent else matrix
                if bone.name in previous_rotations:
                    bone.rotation_quaternion.make_compatible(previous_rotations[bone.name])
                previous_rotations[bone.name] = bone.rotation_quaternion.copy()
                for prop in ('location', 'rotation_quaternion', 'scale'):
                    bone.keyframe_insert(data_path=prop, frame=key_frame, group=bone.name)
                if track:
                    keyed.add(bone.name)
        reports.append({'action': name, 'duration': clip['duration'],
                        'frames': len(clip['frames']), 'mapped_bones': sorted(keyed),
                        'authored_rest_bones': sorted(rest_overrides),
                        'source': 'externally converted Unity transform clips'})
        print('Imported', name, len(keyed), flush=True)
    idle = next(action for action in bpy.data.actions
                if 'defaultidle' in action.name or 'battlewait' in action.name)
    rig.animation_data.action = idle
    bpy.context.scene.frame_set(0)
    bpy.context.scene.frame_end = round(idle.frame_range[1])
    bpy.ops.wm.save_as_mainfile(filepath=job['output'])
    Path(job['report']).write_text(json.dumps({'animations': reports, 'runtime_approved': False,
                                             'source_sha256': job['source_sha256'],
                                             'motion_sha256': job['motion_sha256'],
                                             'explicit_source_hierarchy': bool(job.get('explicit_source_hierarchy'))}, indent=2) + '\n')


if __name__ == '__main__':
    run(json.loads(Path(sys.argv[-1]).read_text()))
