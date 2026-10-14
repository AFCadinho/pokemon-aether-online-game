extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _settle()
	var window_fit := root.get_node("WindowFit")
	root.size_changed.disconnect(window_fit.apply_ui_scale)
	root.min_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_factor = 1.25
	root.size = Vector2i(844, 390)
	window_fit.set("_touch_ui", true)
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	await _settle()
	_check_page(overlay, [0, 1, 2], "1/3")
	var phone_height: float = overlay.hotkey_sidebar_panel.size.y
	_check(phone_height < 219.0 and phone_height >= overlay.hotkey_sidebar_panel.get_combined_minimum_size().y, "phone hotbar shrinks without clipping its contents")
	for button: Control in [overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.donator_store_button, overlay.my_powers_button]:
		if button.visible:
			_check(not overlay.hotkey_sidebar_panel.get_global_rect().intersects(button.get_global_rect()), "phone hotbar clears " + button.name)
	overlay.hotbar_next_page_button.pressed.emit()
	_check_page(overlay, [3, 4, 5], "2/3")
	overlay.hotbar_next_page_button.pressed.emit()
	_check_page(overlay, [6, 7], "3/3")
	overlay.hotbar_next_page_button.pressed.emit()
	_check_page(overlay, [0, 1, 2], "1/3")
	overlay.hotbar_previous_page_button.pressed.emit()
	_check_page(overlay, [6, 7], "3/3")

	root.size = Vector2i(390, 844)
	root.content_scale_factor = 1.5
	await _settle()
	_check_page(overlay, [6, 7], "3/3")
	_check(overlay.hotkey_sidebar_panel.size.y <= phone_height, "orientation and UI zoom keep compact height")
	root.size = Vector2i(1280, 800)
	await _settle()
	_check_page(overlay, [4, 5, 6, 7], "2/2")
	_check(overlay.hotkey_sidebar_panel.size.y >= phone_height + 44.0, "larger touch screen restores the fourth row")
	root.size = Vector2i(844, 390)
	await _settle()
	_check_page(overlay, [3, 4, 5], "2/3")
	_check(is_equal_approx(overlay.hotkey_sidebar_panel.size.y, phone_height), "resizing back removes the old fourth-row space")
	window_fit.set("_touch_ui", false)
	overlay._refresh_quest_tracker_layout()
	await _settle()
	_check_page(overlay, [0, 1, 2, 3], "1/2")
	_check(overlay.hotbar_buttons.size() == 8, "all eight persistent bindings remain available")
	overlay.queue_free()
	await process_frame
	print("player_hotbar_responsive_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _settle() -> void:
	for frame in 8:
		await process_frame


func _check_page(overlay: CanvasLayer, expected: Array, label: String) -> void:
	var visible_slots: Array[int] = []
	for index in overlay.hotbar_slot_panels.size():
		if overlay.hotbar_slot_panels[index].visible:
			visible_slots.append(index)
	_check(visible_slots == expected and overlay.hotbar_page_label.text == label, "visible slots and pager " + label + ": " + str(visible_slots))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
