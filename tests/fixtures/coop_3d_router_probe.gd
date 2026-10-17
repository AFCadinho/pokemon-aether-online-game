extends "res://scripts/battle/coop_native_animation_router.gd"

func _get_move_animation_config(_key: String) -> Dictionary:
	assert(false, "A 3D doubles move must not read the 2D visual catalog")
	return {}

func _get_effect_target_anchor_in_parent(_player_id: String, _parent: Node, _point := "center") -> Vector2:
	assert(false, "A 3D doubles move must not use projected sprite anchors")
	return Vector2.ZERO
