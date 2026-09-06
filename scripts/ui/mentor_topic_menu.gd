extends CanvasLayer

class_name MentorTopicMenu

signal topic_selected(topic_id: String)

const PANEL_SIZE := Vector2(540, 0)

var _resolved := false


func choose_topic(
	title_text: String,
	prompt_text: String,
	topics: Array[Dictionary],
	eyebrow_text: String = "MENTOR NOTES",
	close_text: String = "Close",
	column_count: int = 1,
	compact: bool = false,
	show_close_button: bool = true
) -> String:
	layer = 105
	_build_menu(
		title_text,
		prompt_text,
		topics,
		eyebrow_text,
		close_text,
		column_count,
		compact,
		show_close_button
	)
	return await topic_selected


func _build_menu(
	title_text: String,
	prompt_text: String,
	topics: Array[Dictionary],
	eyebrow_text: String,
	close_text: String,
	column_count: int = 1,
	compact: bool = false,
	show_close_button: bool = true
) -> void:
	var root := Control.new()
	root.name = "MentorTopicMenu"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#02060bd1")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "TopicPanel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16 if compact else 22)
	margin.add_theme_constant_override("margin_top", 14 if compact else 18)
	margin.add_theme_constant_override("margin_right", 16 if compact else 22)
	margin.add_theme_constant_override("margin_bottom", 16 if compact else 20)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7 if compact else 10)
	margin.add_child(layout)

	var eyebrow := Label.new()
	eyebrow.text = eyebrow_text
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color("#e3bd68"))
	layout.add_child(eyebrow)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20 if compact else 23)
	title.add_theme_color_override("font_color", Color("#f4f0de"))
	layout.add_child(title)

	var prompt := Label.new()
	prompt.text = prompt_text
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 12 if compact else 13)
	prompt.add_theme_color_override("font_color", Color("#afbdca"))
	layout.add_child(prompt)

	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	layout.add_child(separator)

	var topic_container: Container = layout
	if column_count > 1:
		var topic_grid := GridContainer.new()
		topic_grid.name = "TopicGrid"
		topic_grid.columns = maxi(1, column_count)
		topic_grid.add_theme_constant_override("h_separation", 7)
		topic_grid.add_theme_constant_override("v_separation", 7)
		layout.add_child(topic_grid)
		topic_container = topic_grid

	var first_topic_button: Button
	for topic: Dictionary in topics:
		var topic_id := str(topic.get("id", "")).strip_edges()
		if topic_id.is_empty():
			continue
		var button := Button.new()
		button.text = str(topic.get("label", topic_id))
		button.custom_minimum_size = Vector2(0, 38 if compact else 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 13 if compact else 15)
		button.add_theme_color_override("font_color", Color("#e8eef4"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.add_theme_stylebox_override("normal", _button_style(Color("#0b1a2bf5"), Color("#315070"), compact))
		button.add_theme_stylebox_override("hover", _button_style(Color("#14314cf8"), Color("#60d3ff"), compact))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#091521"), Color("#e3bd68"), compact))
		button.pressed.connect(_finish.bind(topic_id))
		topic_container.add_child(button)
		if first_topic_button == null:
			first_topic_button = button

	if show_close_button:
		var close_button := Button.new()
		close_button.text = close_text
		close_button.custom_minimum_size = Vector2(0, 36 if compact else 42)
		close_button.focus_mode = Control.FOCUS_ALL
		close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_button.add_theme_font_size_override("font_size", 13 if compact else 14)
		close_button.add_theme_color_override("font_color", Color("#c4cfda"))
		close_button.add_theme_stylebox_override("normal", _button_style(Color("#111c29f5"), Color("#40556a"), compact))
		close_button.add_theme_stylebox_override("hover", _button_style(Color("#26384af5"), Color("#8fa8bb"), compact))
		close_button.pressed.connect(_finish.bind(""))
		layout.add_child(close_button)
	if first_topic_button != null:
		first_topic_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _finish(topic_id: String) -> void:
	if _resolved:
		return
	_resolved = true
	topic_selected.emit(topic_id)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081522fa")
	style.border_color = Color("#d4af5d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color("#000000a8")
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style


func _button_style(background: Color, border: Color, compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12 if compact else 15
	style.content_margin_right = 12 if compact else 15
	style.content_margin_top = 6 if compact else 8
	style.content_margin_bottom = 6 if compact else 8
	return style
