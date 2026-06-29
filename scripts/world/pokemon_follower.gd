extends Node2D

class_name PokemonFollower

const TILE_SIZE := 32.0
const FOLLOW_DISTANCE_TILES := 1
const MAX_HISTORY_SIZE := 16
const TELEPORT_DISTANCE := 96.0
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const DEFAULT_PLAYER_VISUAL_SORT_DEPTH := 8
const PLAYER_OVERLAP_SORT_Y_EPSILON := 8.0
const SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST
const SIDE_SPRITE_VISUAL_OFFSET := Vector2(0.0, -16.0)
const VERTICAL_SPRITE_VISUAL_OFFSET := Vector2(0.0, -12.0)
const BASE_FOLLOWER_FRAME_HEIGHT := 64.0
const SHINY_SPARKLE_COLOR := Color(1.0, 0.82, 0.22, 0.88)
const SHINY_SPARKLE_CENTER_OFFSET := Vector2(0.0, -20.0)
const SHINY_SPARKLE_RADIUS := 20.0

var player: Node2D
var sprite: AnimatedSprite2D
var position_history: Array[Vector2] = []
var last_animation_direction := Vector2.DOWN
var current_species := ""
var current_shiny := false
var shiny_sparkle_time := 0.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	sprite = AnimatedSprite2D.new()
	sprite.name = "FollowerSprite"
	sprite.centered = true
	sprite.texture_filter = SPRITE_TEXTURE_FILTER
	add_child(sprite)
	visible = false

func setup(target_player: Node2D) -> void:
	player = target_player
	_reset_position_history()

func set_pokemon(pokemon: Pokemon) -> void:
	if pokemon == null or pokemon.species == "":
		current_species = ""
		current_shiny = false
		visible = false
		queue_redraw()
		return

	if current_species == pokemon.species and current_shiny == pokemon.shiny and visible:
		return

	current_species = pokemon.species
	current_shiny = pokemon.shiny

	var sprite_frames: SpriteFrames = FollowerSpriteService.get_sprite_frames(current_species, current_shiny)
	if sprite_frames == null:
		visible = false
		queue_redraw()
		return

	sprite.sprite_frames = sprite_frames
	visible = true
	_play_idle_animation()
	queue_redraw()

func reset_follow_position() -> void:
	_reset_position_history()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not visible:
		return

	_update_position_history()
	_follow_target(delta)
	_update_sort_z()
	if current_shiny:
		shiny_sparkle_time += delta
		queue_redraw()

func _draw() -> void:
	if not visible or not current_shiny:
		return

	var center := _get_shiny_sparkle_center()
	for index in range(4):
		var angle := shiny_sparkle_time * 2.2 + float(index) * TAU / 4.0
		var radius := SHINY_SPARKLE_RADIUS + float(index % 2) * 5.0
		var sparkle_position := center + Vector2(cos(angle), sin(angle * 1.17)) * radius
		var pulse := 0.45 + 0.45 * absf(sin(shiny_sparkle_time * 4.0 + float(index)))
		var sparkle_size := 2.0 + pulse * 1.7
		var sparkle_color := Color(
			SHINY_SPARKLE_COLOR.r,
			SHINY_SPARKLE_COLOR.g,
			SHINY_SPARKLE_COLOR.b,
			SHINY_SPARKLE_COLOR.a * pulse
		)
		draw_line(sparkle_position + Vector2(-sparkle_size, 0.0), sparkle_position + Vector2(sparkle_size, 0.0), sparkle_color, 1.25)
		draw_line(sparkle_position + Vector2(0.0, -sparkle_size), sparkle_position + Vector2(0.0, sparkle_size), sparkle_color, 1.25)
		draw_circle(sparkle_position, sparkle_size * 0.28, sparkle_color)

func _reset_position_history() -> void:
	position_history.clear()
	if player == null or not is_instance_valid(player):
		return

	var direction: Vector2 = _get_player_direction()
	last_animation_direction = direction
	var player_position: Vector2 = _get_player_follow_position()
	var follower_position: Vector2 = player_position - (direction * TILE_SIZE * FOLLOW_DISTANCE_TILES)
	position_history.append(follower_position)
	position_history.append(player_position)
	global_position = follower_position
	_update_sort_z()

func _update_position_history() -> void:
	var player_position: Vector2 = _get_player_follow_position()
	if position_history.is_empty():
		position_history.append(player_position)
		global_position = player_position
		return

	var last_position: Vector2 = position_history[position_history.size() - 1]
	if global_position.distance_to(player_position) >= TELEPORT_DISTANCE:
		_reset_position_history()
		return

	if last_position.distance_to(player_position) < TILE_SIZE * 0.9:
		return

	position_history.append(player_position)
	while position_history.size() > MAX_HISTORY_SIZE:
		position_history.remove_at(0)

func _follow_target(delta: float) -> void:
	if position_history.is_empty():
		return

	var target_index: int = maxi(position_history.size() - 1 - FOLLOW_DISTANCE_TILES, 0)
	var target_position: Vector2 = position_history[target_index]
	var distance: float = global_position.distance_to(target_position)
	if distance <= 1.0:
		global_position = target_position
		if _should_keep_walk_animation():
			_play_walk_animation(last_animation_direction)
		else:
			_play_idle_animation()
		return

	var speed: float = TILE_SIZE / _get_follow_move_duration()
	var previous_position: Vector2 = global_position
	global_position = global_position.move_toward(target_position, speed * delta)
	var movement_delta: Vector2 = global_position - previous_position
	_play_walk_animation(movement_delta)

func _get_follow_move_duration() -> float:
	if player != null and is_instance_valid(player) and player.has_method("get_current_move_duration"):
		return maxf(float(player.call("get_current_move_duration")), 0.001)
	return 0.22

func _should_keep_walk_animation() -> bool:
	if position_history.size() > FOLLOW_DISTANCE_TILES + 1:
		return true
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("is_tile_moving"):
		return bool(player.call("is_tile_moving"))

	var remote_moving_value: Variant = player.get("is_replaying_tile_move")
	if remote_moving_value is bool:
		return bool(remote_moving_value)

	return false

func _play_walk_animation(movement_delta: Vector2) -> void:
	var direction: Vector2 = _direction_from_delta(movement_delta)
	if direction == Vector2.ZERO:
		_play_idle_animation()
		return

	last_animation_direction = direction
	_update_sprite_visual_offset(direction)
	var animation_name: String = _get_walk_animation_name(direction)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func _play_idle_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	_update_sprite_visual_offset(last_animation_direction)
	var animation_name: String = _get_idle_animation_name(last_animation_direction)
	if not sprite.sprite_frames.has_animation(animation_name):
		return

	sprite.play(animation_name)
	sprite.stop()

func _update_sprite_visual_offset(direction: Vector2) -> void:
	if sprite == null:
		return

	sprite.position = _get_sprite_visual_offset(direction)

func _get_shiny_sparkle_center() -> Vector2:
	return _get_sprite_visual_offset(last_animation_direction) + SHINY_SPARKLE_CENTER_OFFSET

func _get_sprite_visual_offset(direction: Vector2) -> Vector2:
	var large_sprite_offset := Vector2(0.0, -maxf(_get_current_frame_size().y - BASE_FOLLOWER_FRAME_HEIGHT, 0.0) * 0.5)
	if direction == Vector2.LEFT or direction == Vector2.RIGHT:
		return SIDE_SPRITE_VISUAL_OFFSET + large_sprite_offset
	return VERTICAL_SPRITE_VISUAL_OFFSET + large_sprite_offset

func _get_current_frame_size() -> Vector2:
	if sprite == null or sprite.sprite_frames == null:
		return Vector2(BASE_FOLLOWER_FRAME_HEIGHT, BASE_FOLLOWER_FRAME_HEIGHT)

	var animation_name := _get_idle_animation_name(last_animation_direction)
	if not sprite.sprite_frames.has_animation(animation_name):
		return Vector2(BASE_FOLLOWER_FRAME_HEIGHT, BASE_FOLLOWER_FRAME_HEIGHT)
	if sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return Vector2(BASE_FOLLOWER_FRAME_HEIGHT, BASE_FOLLOWER_FRAME_HEIGHT)

	var frame_texture := sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return Vector2(BASE_FOLLOWER_FRAME_HEIGHT, BASE_FOLLOWER_FRAME_HEIGHT)

	return frame_texture.get_size()

func _direction_from_delta(delta: Vector2) -> Vector2:
	if abs(delta.x) > abs(delta.y):
		return Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
	if abs(delta.y) > 0.0:
		return Vector2.DOWN if delta.y > 0.0 else Vector2.UP
	return Vector2.ZERO

func _get_player_direction() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.DOWN
	var direction_value: Variant = player.get("last_direction")
	if direction_value is Vector2:
		return direction_value as Vector2
	return Vector2.DOWN

func _get_player_follow_position() -> Vector2:
	if player == null or not is_instance_valid(player):
		return global_position
	if player.has_method("get_feet_position"):
		var feet_position: Variant = player.call("get_feet_position")
		if feet_position is Vector2:
			return feet_position as Vector2
	return player.global_position

func _update_sort_z() -> void:
	var follower_sort_y := global_position.y
	var sort_z := floori(follower_sort_y)
	var sprite_sort_z := 0
	if player != null and is_instance_valid(player) and player.has_method("get_feet_position"):
		var player_feet_position: Variant = player.call("get_feet_position")
		if player_feet_position is Vector2:
			var player_sort_y: float = (player_feet_position as Vector2).y
			var player_sort_z := player.z_index
			if follower_sort_y > player_sort_y + PLAYER_OVERLAP_SORT_Y_EPSILON:
				sort_z = maxi(sort_z, player_sort_z + 1)
				sprite_sort_z = _get_player_visual_sort_depth() + 1
			else:
				sort_z = mini(sort_z, player_sort_z - 1)
	z_index = clampi(sort_z, SORT_Z_MIN, SORT_Z_MAX)
	if sprite != null:
		sprite.z_index = sprite_sort_z

func _get_player_visual_sort_depth() -> int:
	if player == null or not is_instance_valid(player):
		return DEFAULT_PLAYER_VISUAL_SORT_DEPTH

	var look_node := player.get_node_or_null("Look")
	if look_node == null:
		return DEFAULT_PLAYER_VISUAL_SORT_DEPTH

	return maxi(_get_max_relative_z_index(look_node), DEFAULT_PLAYER_VISUAL_SORT_DEPTH)

func _get_max_relative_z_index(node: Node) -> int:
	var max_z := 0
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		if canvas_item.z_as_relative:
			max_z = maxi(max_z, canvas_item.z_index)

	for child in node.get_children():
		max_z = maxi(max_z, _get_max_relative_z_index(child))

	return max_z

func _get_idle_animation_name(direction: Vector2) -> String:
	if direction == Vector2.UP:
		return "idle_up"
	if direction == Vector2.LEFT:
		return "idle_left"
	if direction == Vector2.RIGHT:
		return "idle_right"
	return "idle_down"

func _get_walk_animation_name(direction: Vector2) -> String:
	if direction == Vector2.UP:
		return "walk_up"
	if direction == Vector2.LEFT:
		return "walk_left"
	if direction == Vector2.RIGHT:
		return "walk_right"
	return "walk_down"
