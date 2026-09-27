extends Node2D

var overview := false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			overview = not overview
			$Camera2D.position = Vector2(1120, 1040) if overview else Vector2(736, 1632)
			$Camera2D.zoom = Vector2(0.35, 0.35) if overview else Vector2(2, 2)
		elif event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
