extends Window

var canvas: Control

func open_preview(room_key: String, items: Array, design_name: String) -> void:
	borderless = true
	transient = true
	exclusive = true
	min_size = Vector2i(400, 360)
	size = Vector2i(Vector2(960, 780).min(get_tree().root.get_visible_rect().size - Vector2(32, 32)))
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	panel.theme = skin._theme()
	panel.add_theme_stylebox_override("panel", skin._style(Color("#0d1d2b"), Color("#65bbc6")))
	skin.free()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = design_name
	heading.add_theme_color_override("font_color", Color("#f6cf72"))
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var label := Label.new()
	label.text = _t("room_1" if room_key == "right_room" else "room_2") + " · " + _t("preview_hint")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	canvas = preload("res://scripts/ui/guild_room_design_canvas.gd").new()
	canvas.custom_minimum_size = Vector2(300, 240)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(canvas)
	canvas.configure(room_key, items)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for choice: String in ["zoom_out", "fit", "zoom_in", "close"]:
		var button := Button.new()
		button.text = _t(choice)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_act.bind(choice))
		actions.add_child(button)
	close_requested.connect(queue_free)
	popup_centered()

func _act(choice: String) -> void:
	match choice:
		"zoom_out": canvas.zoom_at(0.8, canvas.size * 0.5)
		"zoom_in": canvas.zoom_at(1.25, canvas.size * 0.5)
		"fit": canvas.reset_view()
		"close": queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _t(key: String) -> String:
	return get_node("/root/LocalizationManager").text("ui.guild_design." + key)
