@tool
extends "res://scripts/world/npcs/rival_trainer_npc.gd"

class_name Route24Gary

@export_range(1, 8, 1) var challenge_width_tiles := 6


func _init() -> void:
	rival_encounter_id = "kanto_route_24_gary"


func _apply_vision_area_configuration() -> void:
	super._apply_vision_area_configuration()
	if vision_collision_shape == null or vision_collision_shape.disabled:
		return
	var shape := vision_collision_shape.shape as RectangleShape2D
	if shape != null:
		shape.size.x = float(challenge_width_tiles * TILE_SIZE)


func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if body == null or range_tiles == 0:
		return false
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_target_feet_position(body))
	var delta := body_tile - npc_tile
	var left_width := ceili(float(challenge_width_tiles - 1) * 0.5)
	var right_width := floori(float(challenge_width_tiles - 1) * 0.5)
	return (
		delta.y >= 1
		and delta.y <= range_tiles
		and delta.x >= -left_width
		and delta.x <= right_width
	)


func walk_to_player(_body: Node2D) -> void:
	# Gary guards the complete bridge entrance and starts the battle in place.
	_set_idle_frame(Vector2.DOWN)
