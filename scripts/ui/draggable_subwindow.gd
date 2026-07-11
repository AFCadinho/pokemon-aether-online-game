extends Window

class_name DraggableSubwindow

var dragging := false


func begin_window_drag() -> void:
	dragging = true


func end_window_drag() -> void:
	dragging = false


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			end_window_drag()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		position += Vector2i(roundi(motion.relative.x), roundi(motion.relative.y))
		_clamp_to_parent()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _clamp_to_parent() -> void:
	var parent_window := get_parent() as Window
	if parent_window == null:
		return
	var available := parent_window.size
	position.x = clampi(position.x, 0, maxi(available.x - size.x, 0))
	position.y = clampi(position.y, 0, maxi(available.y - size.y, 0))
