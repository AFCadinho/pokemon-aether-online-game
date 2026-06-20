extends PanelContainer

class_name PremiumConfirmDialog

signal confirmed
signal cancelled

const UI_BG := Color("#070b14f4")
const UI_PANEL := Color("#0d1625f2")
const UI_BORDER := Color("#d8b767")
const UI_BORDER_SOFT := Color("#315070")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")

@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/Header/CloseButton
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CancelButton
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ConfirmButton


func _ready() -> void:
	visible = false
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	_apply_styles()
	close_button.pressed.connect(_cancel)
	cancel_button.pressed.connect(_cancel)
	confirm_button.pressed.connect(_confirm)


func configure(dialog_title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel", danger_confirm: bool = false) -> void:
	if title_label != null:
		title_label.text = dialog_title
	if message_label != null:
		message_label.text = message
	if confirm_button != null:
		confirm_button.text = confirm_text
		_apply_button_style(confirm_button, "danger" if danger_confirm else "default")
	if cancel_button != null:
		cancel_button.text = cancel_text


func popup_centered(requested_size: Vector2i = Vector2i.ZERO) -> void:
	var dialog_size := Vector2(requested_size)
	if dialog_size == Vector2.ZERO:
		dialog_size = custom_minimum_size
	if dialog_size == Vector2.ZERO:
		dialog_size = Vector2(460, 178)

	custom_minimum_size = dialog_size
	size = dialog_size
	_center_in_viewport(dialog_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()


func hide_dialog() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _center_in_viewport(dialog_size: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	global_position = (viewport_size - dialog_size) * 0.5


func _confirm() -> void:
	hide_dialog()
	confirmed.emit()


func _cancel() -> void:
	hide_dialog()
	cancelled.emit()


func _apply_styles() -> void:
	add_theme_stylebox_override("panel", _make_panel_style(UI_BG, UI_BORDER, 10, 1, true))

	title_label.add_theme_color_override("font_color", UI_BORDER)
	title_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", UI_TEXT)
	message_label.add_theme_font_size_override("font_size", 15)

	_apply_button_style(close_button, "quiet")
	_apply_button_style(cancel_button, "danger")
	_apply_button_style(confirm_button)


func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_PANEL
	var hover_bg := Color("#151f36f2")
	var pressed_bg := Color("#080d18f2")
	var border := UI_BORDER_SOFT
	var hover_border := UI_BORDER
	var font_color := UI_TEXT

	if variant == "danger":
		normal_bg = UI_DANGER_BG
		hover_bg = Color("#3a151cee")
		pressed_bg = Color("#19090dee")
		border = Color("#7a2b33")
		hover_border = UI_DANGER
		font_color = UI_DANGER
	elif variant == "quiet":
		normal_bg = Color("#0d1625aa")
		hover_bg = Color("#172744ee")
		pressed_bg = Color("#080d18f2")

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, hover_border))
	button.add_theme_stylebox_override("focus", _make_button_style(UI_PANEL, Color("#7aa7f4")))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _make_button_style(background_color: Color, border_color: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, corner_radius, border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _make_panel_style(background_color: Color, border_color: Color, corner_radius: int, border_width: int, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.42)
		style.shadow_size = 14
		style.shadow_offset = Vector2(0, 5)
	return style
