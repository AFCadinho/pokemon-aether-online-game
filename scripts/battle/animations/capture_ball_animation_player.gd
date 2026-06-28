extends Control

class_name CaptureBallAnimationPlayer

signal ball_thrown
signal ball_shook
signal capture_broke
signal capture_succeeded
signal target_absorbed
signal target_released

const SPRITE_SHEET_PATH := "res://assets/battles/capture/capture_balls_gen4.png"
const FRAME_SIZE := Vector2i(64, 64)
const FRAME_SECONDS := 0.045
const THROW_START_FRAME := 0
const THROW_END_FRAME := 3
const CATCH_START_FRAME := 4
const CATCH_END_FRAME := 14
const SHAKE_START_FRAME := 15
const SHAKE_END_FRAME := 19
const BREAK_START_FRAME := 20
const BREAK_END_FRAME := 26
const SUCCESS_START_FRAME := 27
const SUCCESS_END_FRAME := 31

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	sheet_texture = load(SPRITE_SHEET_PATH) as Texture2D
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.scale = Vector2(2.0, 2.0)
	add_child(sprite)


func play_capture_preview(item_id: String, shake_count: int, caught: bool, target_global_rect: Rect2 = Rect2()) -> void:
	animation_token += 1
	var token := animation_token
	if sheet_texture == null:
		return

	visible = true
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = Vector2(2.0, 2.0)

	var column := _get_ball_column(item_id)
	var target_position := _get_target_position(target_global_rect)
	var start_position := _get_throw_start_position(target_position)

	ball_thrown.emit()
	await _play_throw(column, start_position, target_position, token)
	if token != animation_token:
		return

	target_absorbed.emit()
	await _play_frame_range(column, CATCH_START_FRAME, CATCH_END_FRAME, target_position, token)
	if token != animation_token:
		return

	for index: int in range(clampi(shake_count, 0, 4)):
		ball_shook.emit()
		await _play_frame_range(column, SHAKE_START_FRAME, SHAKE_END_FRAME, target_position, token)
		if token != animation_token:
			return

	if caught:
		capture_succeeded.emit()
		await _play_frame_range(column, SUCCESS_START_FRAME, SUCCESS_END_FRAME, target_position, token)
	else:
		target_released.emit()
		capture_broke.emit()
		await _play_frame_range(column, BREAK_START_FRAME, BREAK_END_FRAME, target_position, token)

	if token != animation_token:
		return

	await get_tree().create_timer(0.18).timeout
	if token == animation_token:
		visible = false


func cancel() -> void:
	animation_token += 1
	visible = false
	target_released.emit()


func _play_throw(column: int, start_position: Vector2, target_position: Vector2, token: int) -> void:
	var frame_count := THROW_END_FRAME - THROW_START_FRAME + 1
	for offset: int in range(frame_count):
		if token != animation_token:
			return

		var progress := float(offset) / float(max(frame_count - 1, 1))
		var arc := Vector2(0.0, -sin(progress * PI) * 88.0)
		sprite.position = start_position.lerp(target_position, progress) + arc
		sprite.rotation = lerpf(-0.6, 0.2, progress)
		_set_frame(column, THROW_START_FRAME + offset)
		await get_tree().create_timer(FRAME_SECONDS).timeout


func _play_frame_range(column: int, start_frame: int, end_frame: int, position: Vector2, token: int) -> void:
	sprite.position = position
	sprite.rotation = 0.0
	for frame_index: int in range(start_frame, end_frame + 1):
		if token != animation_token:
			return

		_set_frame(column, frame_index)
		await get_tree().create_timer(FRAME_SECONDS).timeout


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


func _get_target_position(target_global_rect: Rect2) -> Vector2:
	if target_global_rect.size != Vector2.ZERO:
		return get_global_transform_with_canvas().affine_inverse() * target_global_rect.get_center()

	var local_size := size
	if local_size == Vector2.ZERO:
		local_size = get_viewport_rect().size
	return Vector2(local_size.x * 0.66, local_size.y * 0.36)


func _get_throw_start_position(target_position: Vector2) -> Vector2:
	var local_size := size
	if local_size == Vector2.ZERO:
		local_size = get_viewport_rect().size

	return Vector2(
		max(local_size.x * 0.18, 72.0),
		min(local_size.y * 0.76, target_position.y + 180.0)
	)
