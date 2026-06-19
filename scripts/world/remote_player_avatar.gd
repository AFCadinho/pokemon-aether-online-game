extends Node2D

class_name RemotePlayerAvatar

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256
const SNAP_DISTANCE := 96.0
const REMOTE_MOVE_SPEED := 150.0
const WALK_ANIMATION_HOLD_DURATION := 0.18
const INTERPOLATION_DELAY_SECONDS := 0.16
const MAX_POSITION_SAMPLES := 8

var user_id := 0
var username := ""
var display_name := ""
var target_position := Vector2.ZERO
var walk_animation_hold_timer := 0.0
var position_samples: Array[Dictionary] = []
var tile_move_start_position := Vector2.ZERO
var tile_move_target_position := Vector2.ZERO
var tile_move_elapsed := 0.0
var tile_move_duration := 0.22
var is_replaying_tile_move := false
var pending_tile_moves: Array[Dictionary] = []
var last_direction := Vector2.DOWN
var appearance_sprites: Array[AnimatedSprite2D] = []
var has_position := false


func _ready() -> void:
	z_as_relative = false
	_create_visual()
	_update_animation(false)
	_update_sort_z()


func _process(delta: float) -> void:
	if not has_position:
		return

	var previous_position := global_position
	walk_animation_hold_timer = maxf(walk_animation_hold_timer - delta, 0.0)
	if is_replaying_tile_move:
		_update_replayed_tile_move(delta)
	elif not pending_tile_moves.is_empty():
		_start_next_pending_tile_move()
	else:
		_update_interpolated_position()

	var moved_this_frame := previous_position.distance_to(global_position) > 0.1
	_update_animation(_is_visually_moving(moved_this_frame))
	_update_sort_z()


func apply_state(state: Dictionary) -> void:
	user_id = int(state.get("userId", user_id))
	username = str(state.get("username", username))
	var display_name_value: Variant = state.get("displayName", display_name)
	display_name = username if display_name_value == null else str(display_name_value)

	var position_data := _dictionary_from_value(state.get("position", {}))
	var new_target_position := Vector2(
		float(position_data.get("x", target_position.x)),
		float(position_data.get("y", target_position.y))
	)
	var movement_data := _dictionary_from_value(state.get("movement", {}))
	var packet_direction := _direction_from_name(str(state.get("facingDirection", "down")))
	if not has_position:
		target_position = new_target_position
		if bool(movement_data.get("isMoving", false)):
			global_position = _vector2_from_payload(movement_data.get("startPosition", {}), target_position)
			_reset_position_samples(global_position)
			has_position = true
			_apply_tile_movement_state(movement_data, packet_direction)
		else:
			global_position = target_position
			_reset_position_samples(target_position)
			has_position = true
			last_direction = packet_direction
	else:
		target_position = new_target_position
		if bool(movement_data.get("isMoving", false)):
			_apply_tile_movement_state(movement_data, packet_direction)
		else:
			if not is_replaying_tile_move and pending_tile_moves.is_empty():
				last_direction = packet_direction
				_add_position_sample(target_position)

	_update_animation(_is_visually_moving(false))
	_update_sort_z()


func _apply_tile_movement_state(movement_data: Dictionary, packet_direction: Vector2) -> void:
	var start_position := _vector2_from_payload(movement_data.get("startPosition", {}), global_position)
	var move_target_position := _vector2_from_payload(movement_data.get("targetPosition", {}), target_position)
	var duration := maxf(float(movement_data.get("duration", TILE_MOVE_DURATION)), 0.001)
	if _has_tile_move(start_position, move_target_position):
		return

	pending_tile_moves.append({
		"start": start_position,
		"target": move_target_position,
		"duration": duration,
		"direction": _get_move_direction(start_position, move_target_position, packet_direction),
	})
	position_samples.clear()
	walk_animation_hold_timer = WALK_ANIMATION_HOLD_DURATION

	if not is_replaying_tile_move:
		_start_next_pending_tile_move()


func _has_tile_move(start_position: Vector2, target_position_value: Vector2) -> bool:
	if is_replaying_tile_move \
			and tile_move_start_position.distance_to(start_position) <= 0.5 \
			and tile_move_target_position.distance_to(target_position_value) <= 0.5:
		return true

	for move in pending_tile_moves:
		if typeof(move) != TYPE_DICTIONARY:
			continue
		var move_dictionary: Dictionary = move
		var queued_start := _get_sample_position({"position": move_dictionary.get("start", start_position)}, start_position)
		var queued_target := _get_sample_position({"position": move_dictionary.get("target", target_position_value)}, target_position_value)
		if queued_start.distance_to(start_position) <= 0.5 and queued_target.distance_to(target_position_value) <= 0.5:
			return true

	return false


func _start_next_pending_tile_move() -> void:
	if pending_tile_moves.is_empty():
		return

	var move_value: Variant = pending_tile_moves.pop_front()
	if typeof(move_value) != TYPE_DICTIONARY:
		return

	var move: Dictionary = move_value
	var start_position := _get_sample_position({"position": move.get("start", global_position)}, global_position)
	var move_target_position := _get_sample_position({"position": move.get("target", target_position)}, target_position)
	var move_direction := _get_direction_from_value(move.get("direction", last_direction), last_direction)
	if global_position.distance_to(start_position) > SNAP_DISTANCE:
		global_position = start_position

	tile_move_start_position = _snap_world_position(global_position)
	tile_move_target_position = _snap_world_position(move_target_position)
	tile_move_duration = maxf(float(move.get("duration", TILE_MOVE_DURATION)), 0.001)
	tile_move_elapsed = 0.0
	is_replaying_tile_move = true
	last_direction = move_direction


func _update_replayed_tile_move(delta: float) -> void:
	tile_move_elapsed = minf(tile_move_elapsed + delta, tile_move_duration)
	var progress := clampf(tile_move_elapsed / tile_move_duration, 0.0, 1.0)
	global_position = _snap_world_position(tile_move_start_position.lerp(tile_move_target_position, progress))
	if tile_move_elapsed >= tile_move_duration:
		global_position = tile_move_target_position
		target_position = tile_move_target_position
		is_replaying_tile_move = false
		_reset_position_samples(global_position)
		if not pending_tile_moves.is_empty():
			_start_next_pending_tile_move()


func _add_position_sample(position: Vector2) -> void:
	if not position_samples.is_empty():
		var last_sample: Dictionary = position_samples[position_samples.size() - 1]
		var last_position: Vector2 = _get_sample_position(last_sample, position)
		if last_position.distance_to(position) <= 0.5:
			return

	position_samples.append({
		"time": _get_time_seconds(),
		"position": position,
	})

	while position_samples.size() > MAX_POSITION_SAMPLES:
		position_samples.remove_at(0)

	walk_animation_hold_timer = WALK_ANIMATION_HOLD_DURATION


func _update_interpolated_position() -> void:
	if position_samples.is_empty():
		return

	var render_time := _get_time_seconds() - INTERPOLATION_DELAY_SECONDS
	var first_sample: Dictionary = position_samples[0]
	var first_position: Vector2 = _get_sample_position(first_sample, global_position)
	if global_position.distance_to(first_position) > SNAP_DISTANCE:
		global_position = first_position
		return

	if position_samples.size() == 1:
		global_position = global_position.move_toward(first_position, REMOTE_MOVE_SPEED * get_process_delta_time())
		return

	while position_samples.size() >= 2:
		var next_sample: Dictionary = position_samples[1]
		var next_time := float(next_sample.get("time", 0.0))
		if next_time > render_time:
			break
		position_samples.remove_at(0)

	var from_sample: Dictionary = position_samples[0]
	var from_position: Vector2 = _get_sample_position(from_sample, global_position)
	if position_samples.size() < 2:
		global_position = global_position.move_toward(from_position, REMOTE_MOVE_SPEED * get_process_delta_time())
		return

	var to_sample: Dictionary = position_samples[1]
	var from_time := float(from_sample.get("time", render_time))
	var to_time := float(to_sample.get("time", render_time))
	var to_position: Vector2 = _get_sample_position(to_sample, from_position)
	var sample_duration := maxf(to_time - from_time, 0.001)
	var progress := clampf((render_time - from_time) / sample_duration, 0.0, 1.0)
	global_position = from_position.lerp(to_position, progress)


func _reset_position_samples(position: Vector2) -> void:
	position_samples.clear()
	position_samples.append({
		"time": _get_time_seconds(),
		"position": position,
	})


func _get_sample_position(sample: Dictionary, fallback: Vector2) -> Vector2:
	var position_value: Variant = sample.get("position", fallback)
	if position_value is Vector2:
		return position_value as Vector2
	return fallback


func _is_visually_moving(moved_this_frame: bool) -> bool:
	return moved_this_frame or is_replaying_tile_move or position_samples.size() > 1 or walk_animation_hold_timer > 0.0


func _get_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _vector2_from_payload(value: Variant, fallback: Vector2) -> Vector2:
	var dictionary := _dictionary_from_value(value)
	if dictionary.is_empty():
		return fallback
	return Vector2(
		float(dictionary.get("x", fallback.x)),
		float(dictionary.get("y", fallback.y))
	)


func _get_move_direction(start_position: Vector2, target_position_value: Vector2, fallback: Vector2) -> Vector2:
	var delta := target_position_value - start_position
	if abs(delta.x) > abs(delta.y):
		return Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
	if abs(delta.y) > 0.0:
		return Vector2.DOWN if delta.y > 0.0 else Vector2.UP
	return fallback


func _get_direction_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	return fallback


func _snap_world_position(position: Vector2) -> Vector2:
	return Vector2(roundf(position.x), roundf(position.y))


func _create_visual() -> void:
	var player_instance := PLAYER_SCENE.instantiate()
	var source_look := player_instance.get_node_or_null("Look")
	if source_look == null:
		player_instance.queue_free()
		push_warning("RemotePlayerAvatar: player scene has no Look node.")
		return

	var look_copy := source_look.duplicate()
	add_child(look_copy)
	_collect_appearance_sprites(look_copy)
	player_instance.queue_free()


func _collect_appearance_sprites(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		appearance_sprites.append(sprite)

	for child in node.get_children():
		_collect_appearance_sprites(child)


func _update_animation(is_moving: bool) -> void:
	var animation_name := _get_walk_animation_name(last_direction) if is_moving else _get_idle_animation_name(last_direction)
	for sprite in appearance_sprites:
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
			continue
		if sprite.animation != animation_name:
			sprite.play(animation_name)
		elif not is_moving:
			sprite.frame = 0
			sprite.stop()


func _update_sort_z() -> void:
	z_index = clampi(floori(global_position.y / TILE_SIZE), SORT_Z_MIN, SORT_Z_MAX)


func _get_idle_animation_name(direction: Vector2) -> StringName:
	if direction == Vector2.UP:
		return &"idle_up"
	if direction == Vector2.LEFT:
		return &"idle_left"
	if direction == Vector2.RIGHT:
		return &"idle_right"
	return &"idle_down"


func _get_walk_animation_name(direction: Vector2) -> StringName:
	if direction == Vector2.UP:
		return &"walk_up"
	if direction == Vector2.LEFT:
		return &"walk_left"
	if direction == Vector2.RIGHT:
		return &"walk_right"
	return &"walk_down"


func _direction_from_name(direction_name: String) -> Vector2:
	match direction_name.to_lower():
		"right":
			return Vector2.RIGHT
		"left":
			return Vector2.LEFT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary
