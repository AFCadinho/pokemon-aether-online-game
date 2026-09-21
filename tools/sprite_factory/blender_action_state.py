"""Evaluate skeletal clips from a deterministic rest state, not the last clip."""
from mathutils import Matrix


def select_action(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    rig.animation_data.action = action
    if len(action.slots) == 1:
        rig.animation_data.action_slot = action.slots[0]
