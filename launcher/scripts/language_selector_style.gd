extends RefCounted

class_name LauncherLanguageSelectorStyle

const FLAG_EN: Texture2D = preload("res://assets/ui/language_flags/en.svg")
const FLAG_NL: Texture2D = preload("res://assets/ui/language_flags/nl.svg")
const FLAG_PT_BR: Texture2D = preload("res://assets/ui/language_flags/pt_BR.svg")
const FLAG_ZH_CN: Texture2D = preload("res://assets/ui/language_flags/zh_CN.svg")
const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/language_dropdown_arrow.svg")

const TEXT := Color("#f7f5ff")
const MUTED_TEXT := Color("#b5b8c9")
const INPUT_BG := Color("#10162ae8")
const INPUT_HOVER_BG := Color("#181f3cf2")
const INPUT_PRESSED_BG := Color("#16152ff5")
const POPUP_BG := Color("#090c1cfa")
const BORDER := Color("#343c5e")
const BORDER_HOVER := Color("#7652bd")
const BORDER_FOCUS := Color("#a271ff")


static func configure(button: OptionButton) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 44.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_constant_override("arrow_margin", 12)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(MUTED_TEXT, 0.46))
	button.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	button.add_theme_stylebox_override("normal", _button_style(INPUT_BG, BORDER))
	button.add_theme_stylebox_override("hover", _button_style(INPUT_HOVER_BG, BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", _button_style(INPUT_PRESSED_BG, BORDER_FOCUS))
	button.add_theme_stylebox_override("focus", _button_style(INPUT_BG, BORDER_FOCUS, 2))
	button.add_theme_stylebox_override(
		"disabled",
		_button_style(Color("#0c1020b8"), Color("#282c4499"))
	)
	_configure_popup(button.get_popup())


static func add_locale_item(
	button: OptionButton,
	locale: String,
	display_name: String,
	item_id: int
) -> int:
	var index := button.item_count
	button.add_icon_item(_flag_for_locale(locale), display_name, item_id)
	button.set_item_metadata(index, locale)
	button.set_item_tooltip(index, "%s · %s" % [display_name, _locale_code(locale)])
	return index


static func _configure_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	popup.transparent_bg = true
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(MUTED_TEXT, 0.46))
	popup.add_theme_constant_override("icon_max_width", 24)
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", _popup_style())
	popup.add_theme_stylebox_override(
		"hover",
		_button_style(Color("#2b1e50f5"), BORDER_HOVER)
	)


static func _flag_for_locale(locale: String) -> Texture2D:
	match locale:
		"nl":
			return FLAG_NL
		"pt_BR":
			return FLAG_PT_BR
		"zh_CN":
			return FLAG_ZH_CN
		_:
			return FLAG_EN


static func _locale_code(locale: String) -> String:
	match locale:
		"pt_BR":
			return "PT-BR"
		"zh_CN":
			return "ZH-CN"
		_:
			return locale.to_upper()


static func _button_style(
	background: Color,
	border: Color,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style


static func _popup_style() -> StyleBoxFlat:
	var style := _button_style(POPUP_BG, BORDER_HOVER)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.52)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style
