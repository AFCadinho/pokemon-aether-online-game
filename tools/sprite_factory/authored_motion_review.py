"""Explicit authored motion proposals on the model's own rig, never native recovery.

Only missing source actions named in a disposable export job are replaced.
Human visual and independent battle qualification remain mandatory.
"""
import math


def author(rig, job):
    import bpy
    from mathutils import Quaternion
    from blender_action_state import select_action
    requested = job.get('authored_motion_review', [])
    if not requested:
        return []
    permitted = {'idle', 'sleep', 'physical_attack', 'special_attack', 'damage', 'faint_start'}
    if not isinstance(requested, list) or set(requested)-permitted or len(set(requested))!=len(requested):
        raise ValueError('Invalid authored review action request')
    idle = job['actions'].get('idle')
    if idle in bpy.data.actions:
        select_action(rig, bpy.data.actions[idle])
        bpy.context.scene.frame_set(round(sum(bpy.data.actions[idle].frame_range)/2))
    baseline = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    root_location = rig.location.copy()
    rotation_property = ('rotation_quaternion' if rig.rotation_mode=='QUATERNION' else
                         'rotation_axis_angle' if rig.rotation_mode=='AXIS_ANGLE' else 'rotation_euler')
    root_rotation = rig.matrix_basis.to_quaternion()
    def set_rotation(delta=None):
        q = root_rotation if delta is None else root_rotation @ delta
        if rotation_property=='rotation_quaternion': rig.rotation_quaternion=q
        elif rotation_property=='rotation_axis_angle':
            axis, angle=q.to_axis_angle();rig.rotation_axis_angle=(angle,*axis)
        else: rig.rotation_euler=q.to_euler(rig.rotation_mode)
    def curves(action):
        if hasattr(action,'fcurves'):return list(action.fcurves)
        return [curve for layer in action.layers for strip in layer.strips
                for bag in strip.channelbags for curve in bag.fcurves]

    root_scale = rig.scale.copy()
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    extent = max((o.dimensions.z for o in bpy.context.scene.objects if o.type=='MESH'), default=1)
    step = min(extent*.12, 40 if extent>20 else .4)
    records=[]
    durations={'idle':2,'sleep':2,'physical_attack':.7,'special_attack':.8,'damage':.4,'faint_start':1.2}
    originals={k:v for k,v in job['actions'].items()}
    for category in requested:
        action=bpy.data.actions.new('PAO_AUTHORED_REVIEW_'+category)
        rig.animation_data.action=action
        end=max(2,round(durations[category]*fps)+1)
        for frame in sorted({1,round(end*.3),round(end*.55),end}):
            t=(frame-1)/(end-1)
            weight=math.sin(math.pi*t)
            rig.location=root_location.copy();set_rotation();rig.scale=root_scale.copy()
            for bone in rig.pose.bones:
                bone.matrix_basis=baseline[bone.name]
                bone.keyframe_insert('location',frame=frame)
                rotation='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else ('rotation_axis_angle' if bone.rotation_mode=='AXIS_ANGLE' else 'rotation_euler')
                bone.keyframe_insert(rotation,frame=frame)
                bone.keyframe_insert('scale',frame=frame)
            if category=='physical_attack': rig.location.y -= step*weight
            if category=='special_attack': set_rotation(Quaternion((1,0,0), .12*weight))
            if category=='damage': set_rotation(Quaternion((1,0,0), -.12*weight))
            if category=='faint_start': set_rotation(Quaternion((0,1,0), math.pi*.48*(t*t*(3-2*t))))
            if category=='sleep': rig.scale.z *= 1+.007*math.sin(t*2*math.pi)
            for property in ['location',rotation_property,'scale']:rig.keyframe_insert(property,frame=frame)
        action.use_fake_user=True
        job['actions'][category]=action.name
        records.append({'action':category,'authored_action':action.name,'baseline_source_action':idle,
                        'policy':'authored_own_rig_review_v1','native':False})
    # Every retained native clip receives the unchanged object baseline so a
    # faint root rotation cannot leak into the following idle. Bone keys stay.
    for category,name in originals.items():
        if category in requested or name not in bpy.data.actions:continue
        action=bpy.data.actions[name]
        select_action(rig,action)
        existing={(c.data_path,c.array_index) for c in curves(action)}
        for frame in action.frame_range:
            rig.location=root_location.copy();set_rotation();rig.scale=root_scale.copy()
            for property in ['location',rotation_property,'scale']:
                for axis in range(len(getattr(rig,property))):
                    if (property,axis) not in existing:rig.keyframe_insert(property,index=axis,frame=frame)
    rig.location=root_location;set_rotation();rig.scale=root_scale
    return records
