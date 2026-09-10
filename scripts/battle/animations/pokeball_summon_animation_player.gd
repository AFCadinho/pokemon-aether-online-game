extends Control

class_name PokeballSummonAnimationPlayer
var playback_speed := 1.0

signal ball_thrown
signal pokemon_released
signal summon_finished
signal pokemon_recall_started
signal pokemon_recalled
signal recall_finished

const SPRITE_SHEET_PATH := "res://assets/battles/capture/capture_balls_gen4.png"
const FRAME_SIZE := Vector2i(64, 64)
const FRAME_SECONDS := 0.055
const SWITCH_FRAME_SECONDS := 0.032
const FINISH_HOLD_SECONDS := 0.08
const SWITCH_FINISH_HOLD_SECONDS := 0.04
const SPRITE_SCALE := Vector2(4.0, 4.0)
const THROW_START_FRAME := 0
const THROW_END_FRAME := 3
const RELEASE_START_FRAME := 14
const RELEASE_REVEAL_FRAME := 10
const RELEASE_END_FRAME := 4
const RECALL_START_FRAME := 4
const RECALL_ABSORB_FRAME := 10
const RECALL_END_FRAME := 14

const BALL_COLUMNS := {
	"poke-ball": 0,
	"great-ball": 1,
	"ultra-ball": 2,
	"master-ball": 3,
	"premier-ball": 4,
	"cherish-ball": 5,
	"luxury-ball": 6,
	"nest-ball": 7,
	"net-ball": 8,
	"dive-ball": 9,
	"repeat-ball": 10,
	"timer-ball": 11,
	"safari-ball": 12,
	"quick-ball": 13,
	"dusk-ball": 14,
	"heal-ball": 15,
	"beast-ball": 16,
	"gs-ball": 17,
	"fast-ball": 18,
	"lure-ball": 19,
	"level-ball": 20,
	"heavy-ball": 21,
	"love-ball": 22,
	"friend-ball": 23,
	"moon-ball": 24,
	"park-ball": 25,
	"sport-ball": 26,
	"dream-ball": 27,
}

var sheet_texture: Texture2D
var sprite: Sprite2D
var animation_token := 0

@export var sprite_render_scale := SPRITE_SCALE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	visible = false
	sheet_texture = load(SPRITE_SHEET_PATH) as Texture2D
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.scale = sprite_render_scale
	sprite.top_level = false
	sprite.z_index = 0
	sprite.z_as_relative = true
	add_child(sprite)


func play_summon(item_id: String, target_global_rect: Rect2 = Rect2(), side: String = "back", arena_global_rect: Rect2 = Rect2()) -> void:
	animation_token += 1
	var token := animation_token
	if not _prepare_animation():
		return

	var column := _get_ball_column(item_id)
	var arena_rect := _get_animation_arena_rect(arena_global_rect)
	var target_position := _get_target_position(target_global_rect, side, arena_rect, false)
	var start_position := _get_throw_start_position(target_position, side, arena_rect)

	sprite.position = start_position
	_set_frame(column, THROW_START_FRAME)
	ball_thrown.emit()
	await get_tree().create_timer(0.06 / playback_speed).timeout
	if token != animation_token:
		return

	await _play_throw(column, start_position, target_position, side, token)
	if token != animation_token:
		return

	await _play_release_frames(column, target_position, token, FRAME_SECONDS)
	if token != animation_token:
		return

	await _finish_animation(token, FINISH_HOLD_SECONDS)
	if token == animation_token:
		summon_finished.emit()


func play_overworld_summon(item_id: String, throw_viewport_position: Vector2, target_viewport_position: Vector2) -> void:
	animation_token += 1
	var token := animation_token
	if not _prepare_animation():
		return

	var column := _get_ball_column(item_id)
	var start_position := _global_point_to_local(throw_viewport_position)
	var target_position := _global_point_to_local(target_viewport_position)
	sprite.position = start_position
	_set_frame(column, THROW_START_FRAME)
	ball_thrown.emit()
	await get_tree().create_timer(0.06 / playback_speed).timeout
	if token != animation_token:
		return

	await _play_throw(column, start_position, target_position, "front", token)
	if token != animation_token:
		return

	await _play_release_frames(column, target_position, token, FRAME_SECONDS)
	if token != animation_token:
		return

	await _finish_animation(token, FINISH_HOLD_SECONDS)
	if token == animation_token:
		summon_finished.emit()


func play_release(item_id: String, target_global_rect: Rect2 = Rect2(), side: String = "back", arena_global_rect: Rect2 = Rect2()) -> void:
	animation_token += 1
	var token := animation_token
	if not _prepare_animation():
		return

	var column := _get_ball_column(item_id)
	var arena_rect := _get_animation_arena_rect(arena_global_rect)
	var target_position := _get_target_position(target_global_rect, side, arena_rect, true)

	sprite.position = target_position
	_set_frame(column, RELEASE_START_FRAME)
	await _play_release_frames(column, target_position, token, SWITCH_FRAME_SECONDS)
	if token != animation_token:
		return

	await _finish_animation(token, SWITCH_FINISH_HOLD_SECONDS)
	if token == animation_token:
		summon_finished.emit()


func play_recall(item_id: String, target_global_rect: Rect2 = Rect2(), side: String = "back", arena_global_rect: Rect2 = Rect2()) -> void:
	animation_token += 1
	var token := animation_token
	if not _prepare_animation():
		return

	var column := _get_ball_column(item_id)
	var arena_rect := _get_animation_arena_rect(arena_global_rect)
	var target_position := _get_target_position(target_global_rect, side, arena_rect, true)

	sprite.position = target_position
	_set_frame(column, RECALL_START_FRAME)
	pokemon_recall_started.emit()
	await _play_frame_range(column, RECALL_START_FRAME, RECALL_ABSORB_FRAME, target_position, token, SWITCH_FRAME_SECONDS)
	if token != animation_token:
		return

	pokemon_recalled.emit()
	await _play_frame_range(column, RECALL_ABSORB_FRAME + 1, RECALL_END_FRAME, target_position, token, SWITCH_FRAME_SECONDS)
	if token != animation_token:
		return

	await _finish_animation(token, SWITCH_FINISH_HOLD_SECONDS)
	if token == animation_token:
		recall_finished.emit()


func cancel() -> void:
	animation_token += 1
	visible = false


func _prepare_animation() -> bool:
	if sheet_texture == null:
		return false

	visible = true
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = sprite_render_scale
	return true


func _finish_animation(token: int, hold_seconds: float) -> void:
	await get_tree().create_timer(hold_seconds / playback_speed).timeout
	if token == animation_token:
		visible = false


func _play_release_frames(column: int, target_position: Vector2, token: int, frame_seconds: float) -> void:
	await _play_frame_range(column, RELEASE_START_FRAME, RELEASE_REVEAL_FRAME, target_position, token, frame_seconds)
	if token != animation_token:
		return

	pokemon_released.emit()
	await _play_frame_range(column, RELEASE_REVEAL_FRAME - 1, RELEASE_END_FRAME, target_position, token, frame_seconds)


func _play_throw(column: int, start_position: Vector2, target_position: Vector2, side: String, token: int) -> void:
	var frame_count := THROW_END_FRAME - THROW_START_FRAME + 1
	for offset: int in range(frame_count):
		if token != animation_token:
			return

		var progress := float(offset) / float(max(frame_count - 1, 1))
		var arc_height := 82.0 if side == "back" else 64.0
		var arc := Vector2(0.0, -sin(progress * PI) * arc_height)
		sprite.position = start_position.lerp(target_position, progress) + arc
		sprite.rotation = lerpf(-0.55, 0.25, progress)
		_set_frame(column, THROW_START_FRAME + offset)
		await get_tree().create_timer(FRAME_SECONDS / playback_speed).timeout


func _play_frame_range(column: int, start_frame: int, end_frame: int, position: Vector2, token: int, frame_seconds: float = FRAME_SECONDS) -> void:
	sprite.position = position
	sprite.rotation = 0.0
	var step := -1 if start_frame > end_frame else 1
	var frame_index := start_frame
	while true:
		if token != animation_token:
			return

		_set_frame(column, frame_index)
		await get_tree().create_timer(frame_seconds / playback_speed).timeout
		if frame_index == end_frame:
			break
		frame_index += step


func _set_frame(column: int, frame_index: int) -> void:
	var frame := AtlasTexture.new()
	frame.atlas = sheet_texture
	frame.region = Rect2(
		Vector2(column * FRAME_SIZE.x, frame_index * FRAME_SIZE.y),
		Vector2(FRAME_SIZE.x, FRAME_SIZE.y)
	)
	sprite.texture = frame


func _get_ball_column(item_id: String) -> int:
	var normalized_item_id := item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	return int(BALL_COLUMNS.get(normalized_item_id, 0))


func _get_target_position(target_global_rect: Rect2, side: String, arena_rect: Rect2, prefer_target_rect: bool) -> Vector2:
	if prefer_target_rect and target_global_rect.size != Vector2.ZERO:
		return _global_point_to_local(target_global_rect.get_center()) + Vector2(0.0, 4.0)

	if side == "back":
		return arena_rect.position + Vector2(arena_rect.size.x * 0.32, arena_rect.size.y * 0.67)

	if target_global_rect.size != Vector2.ZERO:
		return _global_point_to_local(target_global_rect.get_center()) + Vector2(0.0, 4.0)

	return arena_rect.position + Vector2(arena_rect.size.x * 0.68, arena_rect.size.y * 0.35)


func _get_throw_start_position(target_position: Vector2, side: String, arena_rect: Rect2) -> Vector2:
	if side == "back":
		return arena_rect.position + Vector2(arena_rect.size.x * 0.10, arena_rect.size.y * 0.80)

	return Vector2(
		min(arena_rect.position.x + arena_rect.size.x * 0.88, target_position.x + 180.0),
		max(arena_rect.position.y + arena_rect.size.y * 0.16, target_position.y - 120.0)
	)


func _get_animation_arena_rect(arena_global_rect: Rect2) -> Rect2:
	if size != Vector2.ZERO:
		return Rect2(Vector2.ZERO, size)

	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size != Vector2.ZERO:
		return Rect2(Vector2.ZERO, parent_control.size)

	if arena_global_rect.size != Vector2.ZERO:
		return Rect2(Vector2.ZERO, arena_global_rect.size)

	var local_size := _get_local_animation_size()
	return Rect2(Vector2.ZERO, local_size)


func _global_point_to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _get_local_animation_size() -> Vector2:
	var local_size := size
	if local_size == Vector2.ZERO:
		var parent_control := get_parent() as Control
		if parent_control != null:
			local_size = parent_control.size
	if local_size == Vector2.ZERO:
		local_size = get_parent_area_size()
	if local_size == Vector2.ZERO:
		local_size = get_viewport_rect().size
	return local_size
