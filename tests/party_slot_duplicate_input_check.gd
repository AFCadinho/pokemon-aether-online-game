extends SceneTree

var failures := 0
var clicks: Array[int] = []
var contexts: Array[int] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var template := load("res://scenes/interface/party_slot.tscn").instantiate() as Control
	root.add_child(template)
	await process_frame
	var slots: Array[Control] = [template]
	for index in range(1, 6):
		var slot := template.duplicate() as Control
		root.add_child(slot)
		slots.append(slot)
	await process_frame
	for index in range(slots.size()):
		var slot := slots[index]
		slot.set("slot_index", index)
		slot.connect("clicked", func(value: int) -> void: clicks.append(value))
		slot.connect("context_requested", func(value: int, _position: Vector2) -> void: contexts.append(value))
		var button := slot.get_node("ClickButton") as Button
		var gesture := button.get_node("TouchContextGesture")
		_check(gesture.get("target") == button, "slot %d gesture targets its own button" % index)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.global_position = Vector2(40, 40)
			button.gui_input.emit(event)
		var context := InputEventMouseButton.new()
		context.button_index = MOUSE_BUTTON_RIGHT
		context.pressed = true
		button.gui_input.emit(context)
	_check(clicks == [0, 1, 2, 3, 4, 5], "clicks reach every party slot exactly once")
	_check(contexts == [0, 1, 2, 3, 4, 5], "context requests reach every party slot exactly once")
	for slot in slots:
		slot.free()
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
