extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(800, 600)
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.position = Vector2(400, 300)
	player.world_camera.enabled = false
	await process_frame
	player._update_fishing_feedback_position()
	var button: Button = player.fishing_bite_prompt_button
	_check(player.fishing_feedback_layer.layer > 20, "Fishing feedback renders above focused HUD and world nameplates")
	_check(button.size.x >= 44 and button.size.y >= 44, "Bite target stays large enough for touch")
	_check(player.fishing_feedback_root.position == Vector2(400, 300), "Overlay follows the trainer in screen coordinates")
	player.position = player.get_viewport_rect().size * Vector2(1, 0)
	player._update_fishing_feedback_position()
	_check(player.fishing_feedback_root.position == Vector2(player.get_viewport_rect().size.x - 92, 144), "Feedback and caption stay on screen at the shoreline edges")
	player.position = Vector2(400, 300)
	player._update_fishing_feedback_position()

	player.world_camera.enabled = true
	player.world_camera.zoom = Vector2(2, 2)
	player.world_camera.position = Vector2(60, 20)
	player.world_camera.force_update_scroll()
	await process_frame
	player._update_fishing_feedback_position()
	var expected_anchor: Vector2 = player.get_viewport_rect().size * 0.5 - Vector2(120, 40)
	_check(player.fishing_feedback_root.position.is_equal_approx(expected_anchor), "Feedback follows camera pan and zoom without scaling its touch target")
	player.world_camera.enabled = false
	await process_frame
	player._update_fishing_feedback_position()

	player._start_fishing_activity(1)
	_check(button.visible and button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Casting shows noninteractive waiting feedback")
	player._update_fishing_activity(player.FISHING_CAST_DURATION)
	_check(player.fishing_activity_state == player.FISHING_STATE_WAITING, "Casting still enters the randomized wait")
	button._process(0.6)
	_check(button.text == "..", "Waiting dots animate while the line is in the water")
	player._try_reel_fishing_bite()
	_check(player.fishing_activity_state == player.FISHING_STATE_MISSED, "Early reel still fails")
	var early_caption: String = button.hint.text
	_check(early_caption == root.get_node("LocalizationManager").text("ui.fishing.feedback.early"), "Early input has its own localized explanation")
	player._finish_fishing_activity()
	_check(not button.visible, "Ending a cast hides its feedback")

	player._start_fishing_activity(1)
	player._enter_fishing_bite_state()
	_check(button.text == "!" and button.mouse_filter == Control.MOUSE_FILTER_STOP, "Bite exposes the clickable exclamation mark")
	_check(is_equal_approx(button.time_fraction, 1.0), "Reaction ring starts full")
	player._update_fishing_activity(player.FISHING_BITE_WINDOW_DURATION * 0.5)
	player._sync_fishing_bite_prompt_visibility()
	_check(is_equal_approx(button.time_fraction, 0.5), "Reaction ring tracks the remaining input window")
	_check(button.hint.text.contains(root.get_node("SettingsManager").get_input_binding_label("fish")), "Bite caption shows the current Fishing hotkey")

	# Put a blocking HUD under the prompt. A real pointer event must still reach
	# the prompt rather than a lower canvas or a high-z world nameplate.
	var hud := CanvasLayer.new()
	hud.layer = 20
	root.add_child(hud)
	var blocker := Button.new()
	blocker.size = Vector2(800, 600)
	hud.add_child(blocker)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	_check(root.gui_get_hovered_control() == button, "Pointer targeting picks fishing above an overlapping HUD")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = motion.position
	click.pressed = true
	root.push_input(click, true)
	_check(player.fishing_activity_state == player.FISHING_STATE_REEL_SUCCESS, "Real mouse press reels above the HUD")
	var result_time: float = player.fishing_activity_time_left
	click.pressed = false
	root.push_input(click, true)
	_check(is_equal_approx(player.fishing_activity_time_left, result_time), "Mouse release cannot restart the result or reel twice")
	_check(button.hint.text == root.get_node("LocalizationManager").text("ui.fishing.feedback.hooked"), "Successful reel has a localized confirmation")
	player._enter_fishing_missed_state()
	player._finish_fishing_activity()

	player._start_fishing_activity(1)
	player._enter_fishing_bite_state()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = button.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	_check(player.fishing_activity_state == player.FISHING_STATE_REEL_SUCCESS, "Touch press reels through the same overlay target")
	touch.pressed = false
	root.push_input(touch, true)
	player._enter_fishing_missed_state()
	player._finish_fishing_activity()

	player._start_fishing_activity(1)
	player._enter_fishing_bite_state()
	player._update_fishing_activity(player.FISHING_BITE_WINDOW_DURATION)
	_check(player.fishing_activity_state == player.FISHING_STATE_MISSED, "Expired reaction window still fails")
	_check(button.hint.text != early_caption, "Late failure is distinct from early failure")
	player._finish_fishing_activity()
	player._start_fishing_activity(1)
	player._enter_fishing_bite_state()
	var key := InputEventKey.new()
	key.physical_keycode = root.get_node("SettingsManager").get_input_binding_keycode("fish")
	key.pressed = true
	root.push_input(key, true)
	_check(player.fishing_activity_state == player.FISHING_STATE_REEL_SUCCESS, "Configured Fishing key still reels in")
	player._enter_fishing_missed_state()
	player._finish_fishing_activity()

	player.queue_free()
	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
