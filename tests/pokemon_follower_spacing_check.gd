extends SceneTree

const FOLLOWER_SCRIPT_PATH := "res://scripts/world/pokemon_follower.gd"
const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
]

var failed := false


class TestPlayer extends Node2D:
	var last_direction := Vector2.DOWN

	func get_feet_position() -> Vector2:
		return global_position

	func get_current_move_duration() -> float:
		return 0.22


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_reset_spacing_in_every_direction()
	_check_visual_offset_in_every_direction()
	_check_trail_keeps_adjacent_spacing()
	quit(1 if failed else 0)


func _check_reset_spacing_in_every_direction() -> void:
	var follower_script := load(FOLLOWER_SCRIPT_PATH) as Script
	_check(follower_script != null, "follower script loads")
	if follower_script == null:
		return
	var constants := follower_script.get_script_constant_map()
	var tile_size := float(constants.get("TILE_SIZE", 0.0))
	var follow_distance_tiles := int(constants.get("FOLLOW_DISTANCE_TILES", 0))
	var player := TestPlayer.new()
	player.global_position = Vector2(320.0, 256.0)
	get_root().add_child(player)

	var follower := follower_script.new() as Node2D
	get_root().add_child(follower)
	follower.call("setup", player)
	_check(
		follow_distance_tiles == 1,
		"follower uses the adjacent trailing tile"
	)

	for direction: Vector2 in CARDINAL_DIRECTIONS:
		player.last_direction = direction
		follower.call("reset_follow_position")
		var expected_position := player.global_position - direction * tile_size * follow_distance_tiles
		_check(
			follower.global_position.is_equal_approx(expected_position),
			"reset keeps adjacent spacing when facing %s" % direction
		)

	follower.free()
	player.free()


func _check_visual_offset_in_every_direction() -> void:
	var follower_script := load(FOLLOWER_SCRIPT_PATH) as Script
	_check(follower_script != null, "follower script loads for visual offsets")
	if follower_script == null:
		return

	var follower := follower_script.new() as Node2D
	get_root().add_child(follower)
	var expected_offset := Vector2(0.0, -16.0)
	for direction: Vector2 in CARDINAL_DIRECTIONS:
		var offset: Vector2 = follower.call("_get_sprite_visual_offset", direction)
		_check(
			offset.is_equal_approx(expected_offset),
			"follower uses the same visual anchor when facing %s" % direction
		)
	follower.free()


func _check_trail_keeps_adjacent_spacing() -> void:
	var follower_script := load(FOLLOWER_SCRIPT_PATH) as Script
	_check(follower_script != null, "follower script loads for trail movement")
	if follower_script == null:
		return
	var tile_size := float(follower_script.get_script_constant_map().get("TILE_SIZE", 0.0))
	var player := TestPlayer.new()
	player.global_position = Vector2(320.0, 256.0)
	player.last_direction = Vector2.RIGHT
	get_root().add_child(player)

	var follower := follower_script.new() as Node2D
	get_root().add_child(follower)
	follower.call("setup", player)

	player.global_position += Vector2.RIGHT * tile_size
	follower.call("_update_position_history")
	follower.call("_follow_target", 1.0)
	_check(
		follower.global_position.is_equal_approx(Vector2(320.0, 256.0)),
		"follower advances to the Trainer's previous tile"
	)

	follower.free()
	player.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
