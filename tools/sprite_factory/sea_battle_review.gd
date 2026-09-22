extends "res://tools/sprite_factory/cave_battle_review.gd"
## Original coastal study. Fixed dry fighting surface; no swimming semantics.

func _camera() -> void:
	distance = clampf(distance, 8.0, 22.0)
	# Bypass the cave ceiling constraint.
	var offset := Vector3(sin(angle)*cos(elevation), sin(elevation), cos(angle)*cos(elevation))*distance
	stage.camera.position = target + offset
	stage.camera.look_at(target)

func _credit_text() -> String:
	return "PokeAether · original sea study\nTidal sandbar · animated ocean · neutral Pokémon materials · isolated preview"

func _make_forest() -> Node3D:
	return load("res://scripts/battle/arenas/generic/water_arena.gd").new(stage.world).build()
