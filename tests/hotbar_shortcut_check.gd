extends SceneTree

var failures := 0


func _init() -> void:
	_check(HotbarShortcut.slot_index_from_event(_key_event(KEY_1)) == -1, "plain 1 stays available for battle moves")
	_check(HotbarShortcut.slot_index_from_event(_key_event(KEY_1, true)) == 0, "Ctrl+1 activates hotbar slot 1")
	_check(HotbarShortcut.slot_index_from_event(_key_event(KEY_8, true)) == 7, "Ctrl+8 activates hotbar slot 8")
	_check(HotbarShortcut.slot_index_from_event(_key_event(KEY_9, true)) == -1, "Ctrl+9 is outside the hotbar")

	var fallback_event := _key_event(KEY_8, true)
	fallback_event.physical_keycode = 0
	_check(HotbarShortcut.slot_index_from_event(fallback_event) == 7, "logical keycode remains a safe fallback")

	var shifted_event := _key_event(KEY_1, true)
	shifted_event.shift_pressed = true
	_check(HotbarShortcut.slot_index_from_event(shifted_event) == -1, "Ctrl+Shift+1 does not trigger the hotbar")

	var echoed_event := _key_event(KEY_1, true)
	echoed_event.echo = true
	_check(HotbarShortcut.slot_index_from_event(echoed_event) == -1, "held shortcuts do not repeat")

	var released_event := _key_event(KEY_1, true)
	released_event.pressed = false
	_check(HotbarShortcut.slot_index_from_event(released_event) == -1, "key releases do not trigger the hotbar")

	quit(1 if failures > 0 else 0)


func _key_event(keycode: Key, ctrl_pressed := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.ctrl_pressed = ctrl_pressed
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
