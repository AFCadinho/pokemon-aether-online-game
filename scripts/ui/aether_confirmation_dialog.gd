extends Control

class_name AetherConfirmationDialog

signal confirmed
signal canceled

const DEFAULT_SIZE := Vector2(520, 230)
const COLOR_BACKGROUND := Color("07101cf7")
const COLOR_SURFACE := Color("0e1b2af8")
const COLOR_SURFACE_HOVER := Color("173149ff")
const COLOR_BORDER := Color("315d78")
const COLOR_ACCENT := Color("69d8e7")
const COLOR_ACCENT_DARK := Color("16485b")
const COLOR_TEXT := Color("eef8ff")
const COLOR_MUTED := Color("9eb3c5")

@onready var panel: PanelContainer = $Center/Panel
@onready var accent_icon: Label = $Center/Panel/Margin/Content/Header/AccentIcon
@onready var title_label: Label = $Center/Panel/Margin/Content/Header/Title
@onready var close_button: Button = $Center/Panel/Margin/Content/Header/CloseButton
@onready var message_label: Label = $Center/Panel/Margin/Content/MessagePanel/MessageMargin/Message
@onready var cancel_button: Button = $Center/Panel/Margin/Content/Actions/CancelButton
@onready var confirm_button: Button = $Center/Panel/Margin/Content/Actions/ConfirmButton


func _ready() -> void:
	visible = false
	top_level = true
	z_index = 4096
	_fit_to_viewport()
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_fit_to_viewport)
	_apply_styles()
	close_button.pressed.connect(_cancel)
	cancel_button.pressed.connect(_cancel)
	confirm_button.pressed.connect(_confirm)


func configure(
	dialog_title: String,
	message: String,
	confirm_text: String,
	cancel_text: String
) -> void:
	title_label.text = dialog_title
	message_label.text = message
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text


func popup_centered(requested_size: Vector2i = Vector2i.ZERO) -> void:
	_fit_to_viewport()
	var target_size := Vector2(requested_size)
	if target_size == Vector2.ZERO:
		target_size = DEFAULT_SIZE
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(target_size.x, maxf(viewport_size.x - 32.0, 300.0)),
		minf(target_size.y, maxf(viewport_size.y - 32.0, 190.0))
	)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.grab_focus.call_deferred()


func hide_dialog() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fit_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	global_position = Vector2.ZERO
	size = viewport_size


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _confirm() -> void:
	hide_dialog()
	confirmed.emit()


func _cancel() -> void:
	hide_dialog()
	canceled.emit()


func _apply_styles() -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_style(COLOR_BACKGROUND, COLOR_ACCENT, 14, 2, true)
	)
	accent_icon.add_theme_color_override("font_color", COLOR_ACCENT)
	accent_icon.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", COLOR_MUTED)
	message_label.add_theme_font_size_override("font_size", 15)
	_style_button(close_button, "quiet")
	_style_button(cancel_button, "secondary")
	_style_button(confirm_button, "primary")


func _style_button(button: Button, variant: String) -> void:
	var normal_background := Color("0c1826")
	var normal_border := COLOR_BORDER
	var hover_background := COLOR_SURFACE_HOVER
	var hover_border := COLOR_ACCENT
	var text_color := COLOR_TEXT
	if variant == "primary":
		normal_background = COLOR_ACCENT_DARK
		normal_border = COLOR_ACCENT
		text_color = Color("effdffff")
	elif variant == "quiet":
		normal_background = Color("07101c00")
		normal_border = Color("315d7800")
		text_color = COLOR_MUTED

	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _button_style(normal_background, normal_border))
	button.add_theme_stylebox_override("hover", _button_style(hover_background, hover_border))
	button.add_theme_stylebox_override("pressed", _button_style(COLOR_SURFACE, COLOR_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(normal_background, COLOR_ACCENT))


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _make_style(background, border, 8, 1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _make_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int,
	with_shadow := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if with_shadow:
		style.shadow_color = Color(0, 0, 0, 0.55)
		style.shadow_size = 18
		style.shadow_offset = Vector2(0, 7)
	return style
