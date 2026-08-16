extends CanvasLayer

class_name AetherBeaconMenu

signal resolved(action: String)

const ACTION_SET_ANCHOR_1 := "set_anchor_1"
const ACTION_SET_ANCHOR_2 := "set_anchor_2"
const ACTION_EXPLAIN := "explain"
const COLOR_PANEL := Color("07101cf7")
const COLOR_SURFACE := Color("0e1b2af8")
const COLOR_SURFACE_HOVER := Color("173149ff")
const COLOR_BORDER := Color("315d78")
const COLOR_ACCENT := Color("69d8e7")
const COLOR_TEXT := Color("eef8ff")
const COLOR_MUTED := Color("9eb3c5")

var _resolved := false
var _destination_id := ""


func open(destination_name: String, destination_id: String, anchor_destination_ids: Array[String], anchor_limit: int) -> void:
	_destination_id = destination_id
	layer = 120
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.0039, 0.0118, 0.0235, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_ACCENT, 14, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 22, 22, 18, 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = LocalizationManager.text("ui.transit.beacon_menu.title")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(title)
	var message := Label.new()
	message.text = LocalizationManager.text("ui.transit.beacon_menu.message", {"name": destination_name})
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", COLOR_MUTED)
	message.add_theme_font_size_override("font_size", 15)
	content.add_child(message)

	var is_anchor := _destination_id in anchor_destination_ids
	var anchor_button := _button(
		_anchor_button_text(1, anchor_destination_ids, is_anchor),
		not is_anchor,
		true
	)
	if not is_anchor:
		anchor_button.pressed.connect(_finish.bind(ACTION_SET_ANCHOR_1))
	content.add_child(anchor_button)
	if anchor_limit >= 2:
		var second_anchor_button := _button(
			_anchor_button_text(2, anchor_destination_ids, is_anchor),
			not is_anchor,
			false
		)
		if not is_anchor:
			second_anchor_button.pressed.connect(_finish.bind(ACTION_SET_ANCHOR_2))
		content.add_child(second_anchor_button)
	var explain_button := _button(LocalizationManager.text("ui.transit.beacon_menu.explain"), true, false)
	explain_button.pressed.connect(_finish.bind(ACTION_EXPLAIN))
	content.add_child(explain_button)
	var close_button := _button(LocalizationManager.text("common.close"), true, false)
	close_button.pressed.connect(_finish.bind(""))
	content.add_child(close_button)
	(anchor_button if not is_anchor else explain_button).grab_focus.call_deferred()


static func anchor_slot_for_action(action: String) -> int:
	return 2 if action == ACTION_SET_ANCHOR_2 else 1


func _anchor_button_text(slot: int, anchor_destination_ids: Array[String], is_anchor: bool) -> String:
	if is_anchor:
		var current_slot := anchor_destination_ids.find(_destination_id) + 1
		return LocalizationManager.text("ui.transit.beacon_menu.anchor_current_slot", {"slot": current_slot})
	return LocalizationManager.text("ui.transit.beacon_menu.anchor_slot", {"slot": slot})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _finish(action: String) -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit(action)
	queue_free()


func _button(text: String, enabled: bool, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_TEXT if enabled else COLOR_MUTED)
	var background := Color("16485b") if primary else COLOR_SURFACE
	var border := COLOR_ACCENT if primary else COLOR_BORDER
	button.add_theme_stylebox_override("normal", _style(background, border, 9, 1))
	button.add_theme_stylebox_override("hover", _style(COLOR_SURFACE_HOVER, COLOR_ACCENT, 9, 1))
	button.add_theme_stylebox_override("disabled", _style(Color("101827"), COLOR_BORDER, 9, 1))
	return button


func _style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)
