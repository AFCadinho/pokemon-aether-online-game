extends Node

const ARROW_CURSOR_PATH := "res://assets/ui/cursors/aether_arrow.png"
const POINTER_CURSOR_PATH := "res://assets/ui/cursors/aether_pointer.png"
const ARROW_HOTSPOT := Vector2(1, 1)
const POINTER_HOTSPOT := Vector2(1, 1)
const MIN_CURSOR_SCALE := 50.0
const MAX_CURSOR_SCALE := 150.0
const DEFAULT_CURSOR_SCALE := 75.0

var cursor_scale := DEFAULT_CURSOR_SCALE


func _ready() -> void:
	apply_cursor_theme()


func apply_cursor_theme() -> void:
	var arrow_cursor := load(ARROW_CURSOR_PATH) as Texture2D
	var pointer_cursor := load(POINTER_CURSOR_PATH) as Texture2D
	if arrow_cursor == null or pointer_cursor == null:
		push_warning("CursorThemeManager: custom cursor assets are not available yet.")
		return
	Input.set_custom_mouse_cursor(
		_scaled_cursor(arrow_cursor),
		Input.CURSOR_ARROW,
		_scaled_hotspot(ARROW_HOTSPOT)
	)
	Input.set_custom_mouse_cursor(
		_scaled_cursor(pointer_cursor),
		Input.CURSOR_POINTING_HAND,
		_scaled_hotspot(POINTER_HOTSPOT)
	)


func set_cursor_scale(value: float) -> void:
	var validated_scale := clampf(value, MIN_CURSOR_SCALE, MAX_CURSOR_SCALE)
	if not is_equal_approx(cursor_scale, validated_scale):
		cursor_scale = validated_scale
	apply_cursor_theme()


func _scaled_cursor(source: Texture2D) -> ImageTexture:
	var image := source.get_image()
	var scale_factor := cursor_scale / 100.0
	var scaled_size := Vector2i(
		maxi(1, roundi(float(image.get_width()) * scale_factor)),
		maxi(1, roundi(float(image.get_height()) * scale_factor))
	)
	image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _scaled_hotspot(source_hotspot: Vector2) -> Vector2:
	var scale_factor := cursor_scale / 100.0
	return Vector2(
		maxf(1.0, roundf(source_hotspot.x * scale_factor)),
		maxf(1.0, roundf(source_hotspot.y * scale_factor))
	)
