extends Node2D

class_name RemotePlayerAvatar

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TILE_SIZE := 32
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256
const SNAP_DISTANCE := 96.0
const MOVE_SPEED := 180.0

var user_id := 0
var username := ""
var display_name := ""
var target_position := Vector2.ZERO
var last_direction := Vector2.DOWN
var appearance_sprites: Array[AnimatedSprite2D] = []
var has_position := false


func _ready() -> void:
	z_as_relative = false
	_create_visual()
	_update_animation(false)
	_update_sort_z()


func _process(delta: float) -> void:
	var distance := global_position.distance_to(target_position)
	if distance > SNAP_DISTANCE:
		global_position = target_position
	elif distance > 0.5:
		global_position = global_position.move_toward(target_position, MOVE_SPEED * delta)

	_update_animation(global_position.distance_to(target_position) > 0.5)
	_update_sort_z()


func apply_state(state: Dictionary) -> void:
	user_id = int(state.get("userId", user_id))
	username = str(state.get("username", username))
	var display_name_value: Variant = state.get("displayName", display_name)
	display_name = username if display_name_value == null else str(display_name_value)

	var position_data := _dictionary_from_value(state.get("position", {}))
	target_position = Vector2(
		float(position_data.get("x", target_position.x)),
		float(position_data.get("y", target_position.y))
	)
	if not has_position:
		global_position = target_position
		has_position = true

	last_direction = _direction_from_name(str(state.get("facingDirection", "down")))
	_update_animation(global_position.distance_to(target_position) > 0.5)
	_update_sort_z()


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
