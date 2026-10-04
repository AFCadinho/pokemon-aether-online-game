extends "res://scripts/ui/aether_confirmation_dialog.gd"
## First-run desktop choice. Static examples need no model download or 3D scene.
const DOWNLOAD_INFO = preload("res://data/battle_visual_download_info.json")
const EXAMPLES := {
	"2d": preload("res://assets/ui/presentation/2d.png"),
	"3d": preload("res://assets/ui/presentation/3d.png"),
}
var selected_mode := ""
var choices := {}
var descriptions := {}
var sizes := {}
var hint: Label
var error_label: Label

func _ready() -> void:
	super._ready()
	name = "BattleVisualChoice"
	close_button.hide()
	cancel_button.hide()
	confirm_button.disabled = true
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	var group := ButtonGroup.new()
	for mode: String in ["2d", "3d"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_style(COLOR_SURFACE, COLOR_BORDER, 10, 1))
		cards.add_child(card)
		var margin := MarginContainer.new()
		for edge: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 14)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		margin.add_child(content)
		var example := TextureRect.new()
		example.name = "Example" + mode.to_upper()
		example.texture = EXAMPLES[mode]
		example.texture_filter = Control.TEXTURE_FILTER_NEAREST if mode == "2d" else Control.TEXTURE_FILTER_LINEAR
		example.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		example.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		example.custom_minimum_size = Vector2(0, 156)
		content.add_child(example)
		var description := _label()
		descriptions[mode] = description
		content.add_child(description)
		var footprint := _label()
		footprint.add_theme_font_size_override("font_size", 14)
		footprint.add_theme_color_override("font_color", COLOR_MUTED)
		sizes[mode] = footprint
		content.add_child(footprint)
		var button := Button.new()
		button.name = "Choose" + mode.to_upper()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.y = 44
		_style_button(button, "primary")
		button.pressed.connect(func():
			selected_mode = mode
			confirm_button.disabled = false
			error_label.hide()
		)
		choices[mode] = button
		content.add_child(button)
	add_custom_control(cards)
	hint = _label()
	add_custom_control(hint)
	error_label = _label()
	error_label.add_theme_color_override("font_color", Color("ff9393"))
	error_label.hide()
	add_custom_control(error_label)
	# Keep keyboard navigation within the chooser while login stays behind it.
	var focus_order: Array[Control] = [choices["2d"], choices["3d"], confirm_button]
	for index in focus_order.size():
		var button := focus_order[index]
		button.focus_next = button.get_path_to(focus_order[(index + 1) % focus_order.size()])
		button.focus_previous = button.get_path_to(focus_order[(index + focus_order.size() - 1) % focus_order.size()])
	refresh_locale()

func _label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label

func refresh_locale() -> void:
	configure(LocalizationManager.text("ui.visual_choice.title"),
		LocalizationManager.text("ui.visual_choice.intro"),
		LocalizationManager.text("ui.visual_choice.confirm"), "")
	for mode: String in ["2d", "3d"]:
		descriptions[mode].text = LocalizationManager.text("ui.visual_choice.description." + mode)
		choices[mode].text = LocalizationManager.text("ui.visual_choice.choose." + mode)
		var info: Dictionary = DOWNLOAD_INFO.data[mode]
		sizes[mode].text = LocalizationManager.text("ui.visual_choice.size", {
			"download": _gib(int(info.download_bytes)), "installed": _gib(int(info.installed_bytes))})
	hint.text = LocalizationManager.text("ui.visual_choice.hint")
	error_label.text = LocalizationManager.text("ui.visual_choice.save_error")

static func _gib(bytes: int) -> String:
	return "%.2f GiB" % (bytes / 1073741824.0)

func _confirm() -> void:
	if selected_mode.is_empty():
		return
	if not SettingsManager.confirm_battle_visual_choice(selected_mode):
		error_label.show()
		return
	hide()
	confirmed.emit()

func _cancel() -> void:
	# Escape/outside clicks cannot accept an implicit renderer preference.
	pass
