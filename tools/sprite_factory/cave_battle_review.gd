extends "res://tools/sprite_factory/temperate_battle_review.gd"
## Original procedural chamber; no purchased environment assets required.
## Reuses the reviewed neutral actors, shadow quality and idle grounding sweep.

func _surface_height(_pos: Vector3) -> float:
	return 0.0

func _camera() -> void:
	distance = clampf(distance, 8.0, 15.5)
	elevation = minf(elevation, asin(8.0 / distance))
	super._camera()

func _credit_text() -> String:
	return "PokeAether · original cave study · Kanto-inspired\nOpen stone floor · neutral Pokémon materials · isolated preview"

func _make_forest() -> Node3D:
	return load("res://scripts/battle/arenas/cave_arena.gd").new(stage.world).build()
