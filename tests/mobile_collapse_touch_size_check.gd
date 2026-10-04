extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var window_fit := root.get_node("WindowFit")
	root.size_changed.disconnect(window_fit.apply_ui_scale)
	root.min_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window_fit.set("_touch_ui", true)
	for browser: bool in [false, true]:
		window_fit.set("_mobile_browser_ui", browser)
		root.content_scale_size = Vector2i(960, 540) if browser else Vector2i(1920, 1080)
		root.size = Vector2i(844, 390)
		root.content_scale_factor = 1.0
		var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
		root.add_child(overlay)
		for frame in 5:
			await process_frame
		overlay._set_collapsible_panel_available("party", true)
		var view: Control = overlay.quest_journal_view
		view.has_main_tracker = true
		view._layout_trackers()
		for dimensions: Vector2i in [Vector2i(844, 390), Vector2i(390, 844), Vector2i(1280, 720)]:
			root.size = dimensions
			for factor: float in [0.75, 1.0, 1.5]:
				root.content_scale_factor = factor
				for frame in 5:
					await process_frame
				_check_layout(overlay, "browser=%s size=%s scale=%s" % [browser, dimensions, factor])
				for panel_id: String in ["options", "party", "location", "chat", "player_status", "actions", "dex_actions", "hotkey_sidebar"]:
					var before: bool = overlay.collapsible_panels[panel_id]["collapsed"]
					await _tap_edge(overlay.collapsible_panels[panel_id]["button"])
					_check(bool(overlay.collapsible_panels[panel_id]["collapsed"]) != before, "edge press toggles " + panel_id)
					_check_layout(overlay, "after toggling " + panel_id)
					await _tap_edge(overlay.collapsible_panels[panel_id]["button"])
					_check(bool(overlay.collapsible_panels[panel_id]["collapsed"]) == before, "edge press restores " + panel_id)
				var before: bool = view.tracker_collapsed
				await _tap_edge(view.tracker_collapse_button)
				_check(view.tracker_collapsed != before, "quest edge press toggles tracker")
				_check_layout(overlay, "quest collapsed")
				await _tap_edge(view.tracker_collapse_button)
				_check(view.tracker_collapsed == before, "quest edge press restores tracker")
		overlay.queue_free()
		await process_frame
	window_fit.set("_touch_ui", false)
	window_fit.set("_mobile_browser_ui", false)
	var desktop = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(desktop)
	for frame in 5:
		await process_frame
	for state: Dictionary in desktop.collapsible_panels.values():
		_check(state["button"].size == Vector2(28, 28), "desktop collapse size is preserved")
		var button: Button = state["button"]
		_check(_visual_rect(button, "normal") == Rect2(Vector2.ZERO, button.size), "desktop surface covers the original button")
	desktop.quest_journal_view.has_main_tracker = true
	desktop.quest_journal_view._layout_trackers()
	_check(desktop.quest_journal_view.tracker_collapse_button.size == Vector2(28, 32), "desktop quest collapse size is preserved")
	desktop.queue_free()
	await process_frame
	print("mobile_collapse_touch_size_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_layout(overlay: CanvasLayer, context: String) -> void:
	var buttons: Array[Control] = []
	var surfaces: Array[Control] = []
	for state: Dictionary in overlay.collapsible_panels.values():
		if state["button"].visible:
			buttons.append(state["button"])
		if state["panel"].visible:
			surfaces.append(state["panel"])
	for surface: Control in [overlay.chat_tabs_panel, overlay.global_buffs_panel, overlay.personal_buffs_panel, overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.donator_store_button, overlay.my_powers_button, overlay.quest_journal_view.tracker_panel, overlay.quest_journal_view.side_tracker_panel]:
		if surface.visible:
			surfaces.append(surface)
	if overlay.quest_journal_view.tracker_collapse_button.visible:
		buttons.append(overlay.quest_journal_view.tracker_collapse_button)
	if overlay.chat_resize_button.visible:
		buttons.append(overlay.chat_resize_button)
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	var rects: Array[Rect2] = []
	for button: Control in buttons:
		var rect := _screen_rect(button)
		_check(overlay.is_point_over_visible_ui(button.get_global_rect().position + button.size * Vector2(0.9, 0.9)), "enlarged target blocks touch movement: " + context)
		_check(rect.size.x >= 47.99 and rect.size.y >= 47.99, "48-pixel target: " + context + " " + str(rect))
		_check(bounds.grow(0.1).encloses(rect), "target stays on screen: " + context + " " + str(rect))
		if not root.get_node("WindowFit").is_mobile_browser_ui():
			for state: String in ["normal", "hover", "pressed"]:
				var visual := _visual_rect(button, state)
				var expected := Vector2(28, 32) if button == overlay.quest_journal_view.tracker_collapse_button else Vector2(28, 28)
				_check(visual.size.is_equal_approx(expected), "original UI-scaled surface in " + state + ": " + context)
				_check(not visual.has_point(button.size * 0.9), "edge press lies in transparent padding: " + context)
			if button == overlay.chat_resize_button:
				_check(button.get_theme_constant("icon_max_width") == 16, "resize icon follows the chosen UI scale: " + context)
			else:
				var expected_font := 16 if button == overlay.quest_journal_view.tracker_collapse_button else 18
				_check(button.get_theme_font_size("font_size") == expected_font, "arrow follows the chosen UI scale: " + context)
		for previous: Rect2 in rects:
			_check(not previous.intersects(rect), "touch controls do not overlap: " + context + " " + str(previous) + " / " + str(rect))
		for surface: Control in surfaces:
			_check(not _screen_rect(surface).intersects(rect), "touch control clears " + surface.name + ": " + context)
		rects.append(rect)


func _tap_edge(button: Control) -> void:
	# Send real viewport input near the newly enlarged edge, outside the old
	# 28-unit button area. Godot emulates mouse input for touchscreen UI buttons.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().position + button.size * Vector2(0.9, 0.9)
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	root.push_input(motion, true)
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	for frame in 3:
		await process_frame


func _screen_rect(control: Control) -> Rect2:
	return (control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, control.size)


func _visual_rect(button: Control, state: String) -> Rect2:
	var style := button.get_theme_stylebox(state) as StyleBoxFlat
	return Rect2(Vector2.ZERO, button.size).grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
