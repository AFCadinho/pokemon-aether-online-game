@tool
extends TrainerNPC

class_name NuggetBridgeTrainer

const CHALLENGE_LANE_Y_OFFSET_TILES := -1

@export_range(1, 8, 1) var challenge_width_tiles := 6


func _configure_vision_area() -> void:
	super._configure_vision_area()
	if vision_collision_shape == null or vision_collision_shape.disabled:
		return
	var shape := vision_collision_shape.shape as RectangleShape2D
	if shape == null:
		return
	var direction := _get_cardinal_direction(facing_direction)
	if direction.x != 0:
		shape.size.y = float(challenge_width_tiles * TILE_SIZE)
		vision_collision_shape.position.y = float(CHALLENGE_LANE_Y_OFFSET_TILES * TILE_SIZE)
	else:
		shape.size.x = float(challenge_width_tiles * TILE_SIZE)


func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if body == null or range_tiles == 0:
		return false
	var direction := _get_cardinal_direction(facing_direction)
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_target_feet_position(body))
	var delta := body_tile - npc_tile
	var lower_width := ceili(float(challenge_width_tiles - 1) * 0.5)
	var upper_width := floori(float(challenge_width_tiles - 1) * 0.5)
	if direction.x != 0:
		var lane_delta_y := delta.y - CHALLENGE_LANE_Y_OFFSET_TILES
		return (
			delta.x * int(direction.x) >= 1
			and delta.x * int(direction.x) <= range_tiles
			and lane_delta_y >= -lower_width
			and lane_delta_y <= upper_width
		)
	return (
		delta.y * int(direction.y) >= 1
		and delta.y * int(direction.y) <= range_tiles
		and delta.x >= -lower_width
		and delta.x <= upper_width
	)


func walk_to_player(_body: Node2D) -> void:
	# Every challenger guards the full bridge width and battles in place.
	_set_idle_frame(_get_cardinal_direction(facing_direction))
