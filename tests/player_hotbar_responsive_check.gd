extends SceneTree

const Target := preload("res://scripts/ui/touch_target_size.gd")
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
	_check(phone_height < 240.0 and phone_height >= overlay.hotkey_sidebar_panel.get_combined_minimum_size().y, "phone hotbar shrinks without clipping its contents")
	var initial_right: float = overlay.hotkey_sidebar_panel.get_rect().end.x
	_check_touch_navigation(overlay)
	await _check_touch_paging(overlay)
	for button: Control in [overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.donator_store_button, overlay.my_powers_button]:
		button.show()
	overlay.quest_journal_view.has_main_tracker = true
	overlay.quest_journal_view._layout_trackers()
	root.content_scale_factor = 1.875
	await _settle()
	_check_touch_navigation(overlay)
	for button: Control in [overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.donator_store_button, overlay.my_powers_button]:
		_check(not overlay.hotkey_sidebar_panel.get_global_rect().intersects(button.get_global_rect()), "zoomed phone hotbar clears " + button.name)
	_check(overlay.hotbar_layout_horizontal_shift > 0.0, "crowded hotbar moves beside the quick buttons")
	for panel: Control in [overlay.personal_buffs_panel, overlay.player_status_panel]:
		_check(not overlay.hotkey_sidebar_panel.get_global_rect().intersects(panel.get_global_rect()), "zoomed hotbar pager clears " + panel.name)
	overlay.quest_journal_view.has_main_tracker = false
	overlay.quest_journal_view._layout_trackers()
	root.content_scale_factor = 1.25
	await _settle()
	_check(is_equal_approx(overlay.hotkey_sidebar_panel.get_rect().end.x, initial_right), "hotbar returns to its original column when room is available")
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
	_check(is_equal_approx(overlay.hotkey_sidebar_panel.size.y, overlay._hotbar_grid_height()), "orientation and UI zoom keep compact height")
	root.size = Vector2i(1280, 800)
	await _settle()
	_check_page(overlay, [4, 5, 6, 7], "2/2")
	_check(is_equal_approx(overlay.hotkey_sidebar_panel.size.y, overlay._hotbar_grid_height()), "larger touch screen restores the fourth row")
	root.size = Vector2i(844, 390)
	await _settle()
	_check_page(overlay, [3, 4, 5], "2/3")
	_check(is_equal_approx(overlay.hotkey_sidebar_panel.size.y, overlay._hotbar_grid_height()), "resizing back removes the old fourth-row space")
	window_fit.set("_touch_ui", false)
	overlay._refresh_quest_tracker_layout()
	await _settle()
	_check_page(overlay, [0, 1, 2, 3], "1/2")
	_check(overlay.hotbar_buttons.size() == 8, "all eight persistent bindings remain available")
	_check(not overlay.hotbar_touch_page_button.visible and overlay.hotbar_page_controls.visible, "desktop restores its original pager")
	overlay.queue_free()
	await process_frame
	print("player_hotbar_responsive_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _settle() -> void:
	for frame in 8:
		await process_frame


func _check_touch_navigation(overlay: CanvasLayer) -> void:
	var button: Button = overlay.hotbar_touch_page_button
	var dp_size := button.size * Target.screen_scale(button)
	_check(button.visible and not overlay.hotbar_previous_page_button.visible and not overlay.hotbar_next_page_button.visible, "native HUD uses one visible page button")
	_check(dp_size.x >= 48.0 and dp_size.y >= 48.0, "page button has a 48 dp target")
	_check(float(button.get_theme_font_size("font_size")) * Target.screen_scale(button).y >= 8.0, "page text stays readable independently of UI zoom")
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	var visual := Rect2(Vector2.ZERO, button.size).grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
	_check(is_equal_approx((visual.size * Target.screen_scale(button)).y, 16.0), "page footer visual=" + str(visual.size * Target.screen_scale(button)) + " target=" + str(dp_size) + " min=" + str(button.get_combined_minimum_size()))
	_check(overlay.hotkey_sidebar_panel.get_global_rect().grow(0.1).encloses(button.get_global_transform() * visual), "visible page label belongs inside the hotbar frame")
	_check(Rect2(Vector2.ZERO, overlay.root_control.size).grow(0.1).encloses(overlay._collapse_touch_rect(button)), "page button stays within the viewport")
	_check(overlay.is_point_over_visible_ui(button.get_global_rect().get_center()), "page button blocks world movement")
	for state: Dictionary in overlay.collapsible_panels.values():
		for control: Control in [state["panel"], state["button"]]:
			if control.visible and control != overlay.hotkey_sidebar_panel:
				_check(not button.get_global_rect().intersects(control.get_global_rect()), "page button clears " + control.name)
	for control: Control in [overlay.personal_buffs_panel, overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.donator_store_button, overlay.my_powers_button]:
		if control.visible:
			_check(not button.get_global_rect().intersects(control.get_global_rect()), "page button clears " + control.name)


func _check_touch_paging(overlay: CanvasLayer) -> void:
	var page_button: Button = overlay.hotbar_touch_page_button
	var point := page_button.get_global_rect().get_center()
	Input.set_emulate_mouse_from_touch(true)
	_touch(true, point)
	_touch(false, point)
	_check_page(overlay, [3, 4, 5], "2/3")
	page_button.pressed.emit()
	page_button.pressed.emit()
	_check_page(overlay, [0, 1, 2], "1/3")
	_check(page_button.text == "1/3›", "one page button wraps back to the first page")
	var activations: Array[int] = []
	for slot: BaseButton in overlay.hotbar_buttons:
		slot.pressed.connect(func() -> void: activations.append(1))
	point = overlay.hotbar_buttons[0].get_global_rect().get_center()
	_touch(true, point)
	_touch(false, point)
	_check(activations.size() == 1, "ordinary native slot tap activates once")
	var distance := 30.0 / Target.screen_scale(overlay.root_control).x
	_touch(true, point)
	_drag(point - Vector2(distance, 0), Vector2(-distance, 0))
	_touch(false, point - Vector2(distance, 0))
	_check_page(overlay, [3, 4, 5], "2/3")
	_check(activations.size() == 1 and not root.gui_is_dragging(), "swipe changes page without using or dragging an item")
	point = overlay.hotbar_buttons[3].get_global_rect().get_center()
	_touch(true, point)
	_drag(point + Vector2(distance, 0), Vector2(distance, 0))
	_touch(false, point + Vector2(distance, 0))
	_check_page(overlay, [0, 1, 2], "1/3")
	point = overlay.hotbar_buttons[0].get_global_rect().get_center()
	_touch(true, point)
	_drag(point - Vector2(distance * 0.5, 0), Vector2(-distance * 0.5, 0))
	_touch(false, point - Vector2(distance * 0.5, 0))
	_check(activations.size() == 1 and overlay.hotbar_current_page == 0, "short cancelled swipe does not use the slot or change pages")
	var dp_scale := Target.screen_scale(overlay.root_control).x
	point.x = root.get_visible_rect().end.x - 9.0 / dp_scale
	_touch(true, point)
	_drag(point + Vector2(8.75 / dp_scale, 0), Vector2(8.75 / dp_scale, 0))
	_touch(false, point + Vector2(8.75 / dp_scale, 0))
	_check_page(overlay, [6, 7], "3/3")
	_check(activations.size() == 1, "back swipe can complete within the narrow right screen edge")
	page_button.pressed.emit()
	point = overlay.hotbar_buttons[0].get_global_rect().get_center()
	_touch(true, point)
	var gesture: Node = overlay.hotbar_buttons[0].get_node("TouchContextGesture")
	gesture._process(0.51)
	_check(gesture.held and activations.size() == 1, "stationary slot hold keeps its context action")
	_touch(false, point)
	await process_frame
	_check(activations.size() == 1 and overlay.hotbar_current_page == 0, "releasing a slot hold does not use an item or change page")
	overlay.collapsible_panels["hotkey_sidebar"]["button"].pressed.emit()
	await _settle()
	_check(not page_button.visible, "collapsing hotbar hides its separate page button")
	overlay.collapsible_panels["hotkey_sidebar"]["button"].pressed.emit()
	await _settle()
	_check(page_button.visible, "reopening hotbar restores the page button")


func _touch(pressed: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.window_id = root.get_window_id()
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.window_id = root.get_window_id()
	event.position = root.get_final_transform() * point
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


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
