extends Node

const ARROW_CURSOR: Texture2D = preload("res://assets/ui/cursors/aether_arrow.png")
const POINTER_CURSOR: Texture2D = preload("res://assets/ui/cursors/aether_pointer.png")
const ARROW_HOTSPOT := Vector2(18, 0)
const POINTER_HOTSPOT := Vector2(14, 0)


func _ready() -> void:
	apply_cursor_theme()


func apply_cursor_theme() -> void:
	Input.set_custom_mouse_cursor(
		ARROW_CURSOR,
		Input.CURSOR_ARROW,
		ARROW_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		POINTER_CURSOR,
		Input.CURSOR_POINTING_HAND,
		POINTER_HOTSPOT
	)
