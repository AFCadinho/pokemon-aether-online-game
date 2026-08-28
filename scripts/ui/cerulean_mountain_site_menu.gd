extends CanvasLayer

class_name CeruleanMountainSiteMenu

signal resolved(site_id: String)

const WEST_SITE := "west"
const EAST_SITE := "east"
const WEST_LEVEL := 20
const EAST_LEVEL := 50

var _resolved := false


func open(rock_smash_level: int) -> void:
	layer = 120
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color("02060bd1")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("07101cf7"), Color("69d8e7"), 14, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 22 if side in ["left", "right"] else 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = LocalizationManager.text("ui.cerulean_mountains.title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("eef8ff"))
	content.add_child(title)
	var description := Label.new()
	description.text = LocalizationManager.text("ui.cerulean_mountains.description")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("9eb3c5"))
	content.add_child(description)

	var west_button := _site_button(WEST_SITE, WEST_LEVEL, rock_smash_level)
	content.add_child(west_button)
	var east_button := _site_button(EAST_SITE, EAST_LEVEL, rock_smash_level)
	content.add_child(east_button)
	var close_button := _button(LocalizationManager.text("common.close"), true)
	close_button.pressed.connect(_finish.bind(""))
	content.add_child(close_button)
	(west_button if not west_button.disabled else close_button).grab_focus.call_deferred()


func _site_button(site_id: String, required_level: int, current_level: int) -> Button:
	var unlocked := current_level >= required_level
	var key := "ui.cerulean_mountains.%s" % site_id
	var label := LocalizationManager.text(key)
	if not unlocked:
		label = LocalizationManager.text("ui.cerulean_mountains.locked_site", {
			"site": label,
			"level": required_level,
		})
	var button := _button(label, unlocked)
	if unlocked:
		button.pressed.connect(_finish.bind(site_id))
	return button


func _button(label: String, enabled: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("eef8ff") if enabled else Color("718294"))
	button.add_theme_stylebox_override("normal", _style(Color("0e1b2af8"), Color("315d78"), 9, 1))
	button.add_theme_stylebox_override("hover", _style(Color("173149ff"), Color("69d8e7"), 9, 1))
	button.add_theme_stylebox_override("disabled", _style(Color("101827"), Color("263a4d"), 9, 1))
	return button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _finish(site_id: String) -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit(site_id)
	queue_free()


func _style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
