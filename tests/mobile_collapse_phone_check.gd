extends SceneTree
## Actual-device companion to the desktop geometry regression. Exported by the
## offline diagnostic tool; keeps a scale picker available after automatic QA.

const Target := preload("res://scripts/ui/touch_target_size.gd")
var overlay: CanvasLayer
var failures: Array[String] = []
var checks := 0
var samples: Array[Dictionary] = []
var presses: Array[Dictionary] = []
var manual := false
var toolbar_root: Control
var toolbar: PanelContainer
var status: Label


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var fit := root.get_node("WindowFit")
	_check(fit.is_touch_ui() and not fit.is_mobile_browser_ui(), "native touch layout")
	var settings := root.get_node("SettingsManager")
	var background_layer := CanvasLayer.new()
	background_layer.layer = 0
	root.add_child(background_layer)
	var background := ColorRect.new()
	background.color = Color("#17303b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background)
	overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	await _settle()
	overlay._set_collapsible_panel_available("party", true)
	var view: Control = overlay.quest_journal_view
	view.has_main_tracker = true
	view.tracker_title_label.text = "Testdoel"
	view.tracker_objective_label.text = "Klap dit paneel in en open het opnieuw."
	view._layout_trackers()
	for panel_id: String in overlay.collapsible_panels:
		overlay.collapsible_panels[panel_id]["button"].pressed.connect(_record_press.bind(panel_id))
	view.tracker_collapse_button.pressed.connect(_record_press.bind("quest"))
	for percentage: float in [75, 100, 150]:
		settings.set_ui_scale(percentage)
		_set_collapsed(false)
		await _settle()
		await _sample(percentage, "expanded")
		for panel_id: String in overlay.collapsible_panels:
			var state: Dictionary = overlay.collapsible_panels[panel_id]
			if not state["button"].visible:
				continue
			await _tap_edge(state["button"])
			_check(state["collapsed"], "edge collapses " + panel_id)
			await _tap_edge(state["button"])
			_check(not state["collapsed"], "edge reopens " + panel_id)
		await _tap_edge(view.tracker_collapse_button)
		_check(view.tracker_collapsed, "quest edge collapses")
		await _tap_edge(view.tracker_collapse_button)
		_check(not view.tracker_collapsed, "quest edge reopens")
		_set_collapsed(true)
		await _settle()
		await _sample(percentage, "collapsed")
	settings.set_ui_scale(75)
	_set_collapsed(false)
	await _settle()
	manual = true
	_build_toolbar()
	_write_report()
	print("MOBILE_COLLAPSE_PHONE_QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _settle() -> void:
	for frame in 8:
		await process_frame


func _set_collapsed(collapsed: bool) -> void:
	for panel_id: String in overlay.collapsible_panels:
		overlay.collapsible_panels[panel_id]["collapsed"] = collapsed
		overlay._apply_collapsible_panel_state(panel_id)
	overlay.quest_journal_view.tracker_collapsed = collapsed
	overlay.quest_journal_view._layout_trackers()
	overlay._invalidate_collapsible_layout()
	if manual:
		_write_after_layout()


func _sample(percentage: float, state: String) -> void:
	var density := float(DisplayServer.screen_get_dpi()) / 160.0 if OS.has_feature("android") else DisplayServer.screen_get_scale()
	var buttons: Dictionary = {}
	var rects: Array[Rect2] = []
	var candidates: Dictionary = {}
	for panel_id: String in overlay.collapsible_panels:
		candidates[panel_id] = overlay.collapsible_panels[panel_id]["button"]
	candidates["quest"] = overlay.quest_journal_view.tracker_collapse_button
	for panel_id: String in candidates:
		var button: Control = candidates[panel_id]
		if not button.visible:
			continue
		var rect: Rect2 = (root.get_screen_transform() * button.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, button.size)
		_check(rect.size.x / density >= 47.99 and rect.size.y / density >= 47.99, "48 dp " + panel_id + " at " + str(percentage))
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(0.1).encloses(rect), "on screen " + panel_id)
		_check(overlay.is_point_over_visible_ui(button.get_global_rect().position + button.size * 0.9), "blocks movement " + panel_id)
		for previous: Rect2 in rects:
			_check(not previous.intersects(rect), "separate targets " + panel_id)
		rects.append(rect)
		buttons[panel_id] = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "widthDp": rect.size.x / density, "heightDp": rect.size.y / density}
	samples.append({"scale": percentage, "state": state, "buttons": buttons})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://collapse-%d-%s.png" % [percentage, state])


func _tap_edge(button: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().position + button.size * 0.9
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	root.push_input(motion, true)
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await _settle()


func _record_press(panel_id: String) -> void:
	presses.append({"panel": panel_id, "manual": manual, "scale": root.get_node("SettingsManager").ui_scale})
	if manual:
		_write_after_layout()


func _build_toolbar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	root.add_child(layer)
	toolbar_root = Control.new()
	toolbar_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toolbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toolbar_root)
	toolbar = PanelContainer.new()
	toolbar_root.add_child(toolbar)
	var box := VBoxContainer.new()
	toolbar.add_child(box)
	status = Label.new()
	status.text = "Knoppen testen — %d controles, %d fouten" % [checks, failures.size()]
	status.add_theme_font_size_override("font_size", 16)
	box.add_child(status)
	var row := HBoxContainer.new()
	box.add_child(row)
	for percentage: int in [75, 100, 150]:
		var button := Button.new()
		button.text = str(percentage) + "%"
		button.custom_minimum_size = Vector2(72, 48)
		button.pressed.connect(_select_scale.bind(percentage))
		row.add_child(button)
	var collapse := Button.new()
	collapse.text = "Alles inklappen"
	collapse.custom_minimum_size = Vector2(140, 48)
	collapse.pressed.connect(_set_collapsed.bind(true))
	row.add_child(collapse)
	toolbar_root.resized.connect(_fit_toolbar)
	_fit_toolbar.call_deferred()


func _fit_toolbar() -> void:
	toolbar.scale = Vector2.ONE / Target.screen_scale(toolbar_root)
	var extent := toolbar.size * toolbar.scale
	var occupied: Array[Rect2] = []
	for state: Dictionary in overlay.collapsible_panels.values():
		for control: Control in [state["panel"], state["button"]]:
			if control.visible:
				occupied.append(control.get_global_rect())
	for control: Control in [overlay.chat_tabs_panel, overlay.quest_journal_view.tracker_panel, overlay.quest_journal_view.tracker_collapse_button]:
		if control.visible:
			occupied.append(control.get_global_rect())
	var desired := Rect2((toolbar_root.size - extent) * 0.5, extent)
	toolbar.position = Target.fit_rect(desired, Rect2(Vector2.ZERO, toolbar_root.size), occupied).position


func _select_scale(percentage: int) -> void:
	root.get_node("SettingsManager").set_ui_scale(percentage)
	await _settle()
	_fit_toolbar()
	_write_report()


func _write_after_layout() -> void:
	await _settle()
	_fit_toolbar()
	_write_report()


func _write_report() -> void:
	var live: Dictionary = {}
	for panel_id: String in overlay.collapsible_panels:
		var state: Dictionary = overlay.collapsible_panels[panel_id]
		var button: Control = state["button"]
		var rect: Rect2 = (root.get_screen_transform() * button.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, button.size)
		live[panel_id] = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y, "collapsed": state["collapsed"]}
	var quest: Control = overlay.quest_journal_view.tracker_collapse_button
	var quest_rect: Rect2 = (root.get_screen_transform() * quest.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, quest.size)
	live["quest"] = {"x": quest_rect.position.x, "y": quest_rect.position.y, "width": quest_rect.size.x, "height": quest_rect.size.y, "collapsed": overlay.quest_journal_view.tracker_collapsed}
	var file := FileAccess.open("user://mobile-collapse-details.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "screenPixels": {"width": root.size.x, "height": root.size.y}, "densityScale": float(DisplayServer.screen_get_dpi()) / 160.0 if OS.has_feature("android") else DisplayServer.screen_get_scale(), "godotScreenScale": DisplayServer.screen_get_scale(), "densityDpi": DisplayServer.screen_get_dpi(), "samples": samples, "presses": presses, "liveButtons": live, "currentScale": root.get_node("SettingsManager").ui_scale}, "  "))
	file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
