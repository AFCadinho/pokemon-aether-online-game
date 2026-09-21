"""Blender-only regressions for rig isolation and action-copy equivalence."""
import sys
from pathlib import Path
import bpy
sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import isolate, equivalent_action_names


def actor(name, image_name):
    bpy.ops.object.armature_add()
    rig=bpy.context.object;rig.name=name
    bpy.ops.mesh.primitive_cube_add()
    mesh=bpy.context.object;mesh.parent=rig
    mod=mesh.modifiers.new('Skin','ARMATURE');mod.object=rig
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.new(image_name, width=4,height=4)
    mesh.data.materials.append(mat)
    return rig,mesh


bpy.ops.wm.read_factory_settings(use_empty=True)
a,mesh=actor('first','pm0999_00_Body.png')
b,_=actor('second','pm0999_01_Body.png')
rig,evidence=isolate('pm0999_00.blend')
assert rig is a and len([o for o in bpy.context.scene.objects if o.type=='ARMATURE'])==1
assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])==1
assert mesh.parent is a and evidence['policy']=='exclusive_texture_variant_v1'
print('PASS exclusive variant rig isolation')
b,_=actor('second_again','pm0999_00_Body.png')
try:isolate('pm0999_00.blend')
except ValueError:pass
else:raise AssertionError('Ambiguous variants accepted')
assert len([o for o in bpy.context.scene.objects if o.type=='ARMATURE'])==2
print('PASS ambiguous variants fail before scene mutation')
bone=a.pose.bones[0]
a.animation_data_create();action=bpy.data.actions.new('pm0999_00_ba10_waitA01.gfbanm')
a.animation_data.action=action
bone.location=(0,0,0);bone.keyframe_insert('location',frame=0)
bone.location=(0,0,1);bone.keyframe_insert('location',frame=20)
copy=action.copy()
assert equivalent_action_names([copy,action])==[action.name]
curve=copy.layers[0].strips[0].channelbags[0].fcurves[0]
curve.keyframe_points[0].co.y=7
assert len(equivalent_action_names([copy,action]))==2
print('PASS action copies collapsed only on complete curve equivalence')
