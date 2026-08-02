extends Node

const ARROW_CURSOR_PATH := "res://assets/ui/cursors/aether_arrow.png"
const POINTER_CURSOR_PATH := "res://assets/ui/cursors/aether_pointer.png"
const ARROW_HOTSPOT := Vector2(1, 1)
const POINTER_HOTSPOT := Vector2(1, 1)


func _ready() -> void:
	apply_cursor_theme()


func apply_cursor_theme() -> void:
	var arrow_cursor := load(ARROW_CURSOR_PATH) as Texture2D
	var pointer_cursor := load(POINTER_CURSOR_PATH) as Texture2D
	if arrow_cursor == null or pointer_cursor == null:
		push_warning("CursorThemeManager: custom cursor assets are not available yet.")
		return
	Input.set_custom_mouse_cursor(
		arrow_cursor,
		Input.CURSOR_ARROW,
		ARROW_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		pointer_cursor,
		Input.CURSOR_POINTING_HAND,
		POINTER_HOTSPOT
	)
