extends SceneTree
## Offline device geometry and screenshot probe. Never injects pointer events.

const Target := preload("res://scripts/ui/touch_target_size.gd")

var overlay: CanvasLayer
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var manual := false
var toolbar: PanelContainer


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _settle()
	_check(OS.has_feature("android"), "physical Android runtime")
	var fit := root.get_node("WindowFit")
	_check(fit.is_touch_ui() and not fit.is_mobile_browser_ui(), "native touch HUD")
	root.get_node("LocalizationManager").set_locale("nl")
	var background_layer := CanvasLayer.new()
	root.add_child(background_layer)
	var background := ColorRect.new()
	background.color = Color("#17303b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background)
	overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	await _settle()
	# Exercise the full five-button rail and an active quest, even offline.
	for button: Control in _quick_buttons():
		button.show()
	overlay.quest_journal_view.has_main_tracker = true
	overlay.quest_journal_view.tracker_title_label.text = "Hotbar-test"
	overlay.quest_journal_view.tracker_objective_label.text = "Controleer de ruimte bij de knoppen."
	overlay.quest_journal_view._layout_trackers()
	for percentage: int in [75, 100, 150]:
		root.get_node("SettingsManager").set_ui_scale(percentage)
		await _settle()
		for page in 3:
			overlay._set_hotbar_page(page)
			await _settle()
			await _sample(percentage, page)
	_check(samples.size() == 9, "all nine screenshot samples completed")
	root.get_node("SettingsManager").set_ui_scale(75)
	overlay._set_hotbar_page(0)
	await _settle()
	manual = true
	_build_toolbar()
	overlay.hotbar_previous_page_button.pressed.connect(_record_manual_page)
	overlay.hotbar_next_page_button.pressed.connect(_record_manual_page)
	_write_report()
	print("HOTBAR_PHONE_QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _quick_buttons() -> Array[Control]:
	return [overlay.donator_store_button, overlay.settings_button, overlay.mount_button, overlay.skills_button, overlay.my_powers_button]


func _settle() -> void:
	for frame in 8:
		await process_frame


func _sample(percentage: int, page: int) -> void:
	var visible_slots: Array[int] = []
	for index in overlay.hotbar_slot_panels.size():
		if overlay.hotbar_slot_panels[index].visible:
			visible_slots.append(index + 1)
	var expected: Array = [1, 2, 3] if page == 0 else ([4, 5, 6] if page == 1 else [7, 8])
	_check(visible_slots == expected, "correct slots at %d%% page %d" % [percentage, page + 1])
	_check(overlay.hotbar_page_label.text == "%d/3" % (page + 1), "three-page indicator")
	var hotbar := _screen_rect(overlay.hotkey_sidebar_panel)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1).encloses(hotbar), "hotbar within screen")
	var buttons: Dictionary = {}
	for button: Control in _quick_buttons() + [overlay.personal_buffs_panel, overlay.player_status_panel]:
		var rect := _screen_rect(button)
		buttons[button.name] = _rect_data(rect)
		_check(not hotbar.intersects(rect), "hotbar and pager clear %s at %d%% page %d" % [button.name, percentage, page + 1])
	var screenshot := "hotbar-%d-page-%d.png" % [percentage, page + 1]
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://" + screenshot)
	samples.append({"scale": percentage, "page": page + 1, "visibleSlots": visible_slots, "hotbar": _rect_data(hotbar), "quickButtons": buttons, "screenshot": screenshot})


func _screen_rect(control: Control) -> Rect2:
	return (root.get_screen_transform() * control.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, control.size)


func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _build_toolbar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	root.add_child(layer)
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(control)
	toolbar = PanelContainer.new()
	control.add_child(toolbar)
	var box := VBoxContainer.new()
	toolbar.add_child(box)
	var label := Label.new()
	label.text = "Hotbar: %d controles, %d fouten\nProbeer de pijltjes rechts handmatig." % [checks, failures.size()]
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for percentage in [75, 100, 150]:
		var button := Button.new()
		button.text = "%d%%" % percentage
		button.custom_minimum_size = Vector2(80, 48)
		button.pressed.connect(_select_scale.bind(percentage))
		row.add_child(button)
	control.resized.connect(_fit_toolbar.bind(control))
	_fit_toolbar.call_deferred(control)


func _fit_toolbar(control: Control) -> void:
	toolbar.scale = Vector2.ONE / Target.screen_scale(control)
	toolbar.position = Vector2(20.0, control.size.y * 0.4)


func _select_scale(percentage: int) -> void:
	root.get_node("SettingsManager").set_ui_scale(percentage)
	await _settle()
	_write_report()


func _record_manual_page() -> void:
	await _settle()
	_write_report()


func _write_report() -> void:
	var file := FileAccess.open("user://hotbar-details.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"device": OS.get_model_name(), "androidVersion": OS.get_version(), "screenPixels": {"width": root.size.x, "height": root.size.y}, "densityDpi": DisplayServer.screen_get_dpi(), "densityScale": Target.pixel_density(), "checks": checks, "failures": failures, "samples": samples, "manual": manual, "currentScale": root.get_node("SettingsManager").ui_scale, "currentPage": overlay.hotbar_current_page + 1}, "  "))
	file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
