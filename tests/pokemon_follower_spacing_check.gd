extends SceneTree

const FOLLOWER_SCRIPT_PATH := "res://scripts/world/pokemon_follower.gd"
const REMOTE_PLAYER_SCRIPT_PATH := "res://scripts/world/remote_player_avatar.gd"
const CARDINAL_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
]

var failed := false


class TestPlayer extends Node2D:
	var last_direction := Vector2.DOWN
	var target_position := Vector2.ZERO
	var is_moving := false

	func get_feet_position() -> Vector2:
		return global_position

	func get_target_feet_position() -> Vector2:
		return target_position if is_moving else global_position

	func is_tile_moving() -> bool:
		return is_moving

	func get_current_move_duration() -> float:
		return 0.22


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_reset_spacing_in_every_direction()
	_check_visual_offset_in_every_direction()
	_check_trail_keeps_adjacent_spacing()
	_check_remote_player_exposes_active_step_target()
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
	player.target_position = player.global_position
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
	var expected_offsets := {
		Vector2.UP: Vector2(0.0, -16.0),
		Vector2.DOWN: Vector2(0.0, -16.0),
		Vector2.LEFT: Vector2(8.0, -16.0),
		Vector2.RIGHT: Vector2(-8.0, -16.0),
	}
	for direction: Vector2 in CARDINAL_DIRECTIONS:
		var offset: Vector2 = follower.call("_get_sprite_visual_offset", direction)
		var expected_offset: Vector2 = expected_offsets[direction]
		_check(
			offset.is_equal_approx(expected_offset),
			"follower uses the intended visual spacing when facing %s" % direction
		)
	follower.free()


func _check_trail_keeps_adjacent_spacing() -> void:
	var follower_script := load(FOLLOWER_SCRIPT_PATH) as Script
	_check(follower_script != null, "follower script loads for trail movement")
	if follower_script == null:
		return
	var tile_size := float(follower_script.get_script_constant_map().get("TILE_SIZE", 0.0))
	var frame_delta := 0.05
	var step_distance := tile_size / 0.22 * frame_delta

	for direction: Vector2 in CARDINAL_DIRECTIONS:
		var player := TestPlayer.new()
		player.global_position = Vector2(320.0, 256.0)
		player.target_position = player.global_position
		player.last_direction = direction
		get_root().add_child(player)

		var follower := follower_script.new() as Node2D
		get_root().add_child(follower)
		follower.call("setup", player)

		var initial_follower_position := follower.global_position
		player.target_position = player.global_position + direction * tile_size
		player.is_moving = true
		follower.call("_update_position_history")
		player.global_position += direction * step_distance
		follower.call("_follow_target", frame_delta)
		_check(
			not follower.global_position.is_equal_approx(initial_follower_position),
			"follower starts moving immediately toward %s" % direction
		)
		_check(
			is_equal_approx(follower.global_position.distance_to(player.global_position), tile_size),
			"walking toward %s preserves idle spacing" % direction
		)

		follower.free()
		player.free()


func _check_remote_player_exposes_active_step_target() -> void:
	var remote_player_script := load(REMOTE_PLAYER_SCRIPT_PATH) as Script
	_check(remote_player_script != null, "remote player script loads for follower trail movement")
	if remote_player_script == null:
		return

	var remote_player := remote_player_script.new() as Node2D
	remote_player.global_position = Vector2(320.0, 256.0)
	remote_player.set("tile_move_target_position", Vector2(352.0, 256.0))
	remote_player.set("is_replaying_tile_move", true)
	_check(
		remote_player.call("get_target_feet_position") == Vector2(352.0, 256.0),
		"remote followers use the active replay step instead of a later queued position"
	)
	remote_player.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
