extends "res://scripts/ui/aether_confirmation_dialog.gd"

signal difficulty_selected(difficulty: String)

const DIFFICULTIES: Array[String] = ["easy", "intermediate", "hard"]
const CARD_COLORS: Array[Color] = [Color("75cca0"), Color("69d8e7"), Color("ff8585")]
const GOLD := Color("e3bd68")

var difficulty_buttons: Array[Button] = []
var difficulty_grid: GridContainer


func configure_boss(boss_name: String, status: Dictionary, unlock_message := "") -> void:
	confirm_button.hide()
	get_node("Center/Panel/Margin/Content/MessagePanel").custom_minimum_size.y = 0
	panel.add_theme_stylebox_override("panel", _make_style(COLOR_BACKGROUND, GOLD, 14, 2, true))
	var portrait := PokemonAssets.load_home_sprite(boss_name)
	if portrait != null:
		accent_icon.texture = portrait
		accent_icon.custom_minimum_size = Vector2(52, 52)
	var message := LocalizationManager.text("weekly_boss.unavailable")
	match str(status.get("state", "")):
		"available":
			get_node("Center/Panel/Margin/Content/MessagePanel").hide()
			_build_difficulty_buttons()
		"completed":
			message = LocalizationManager.text("weekly_boss.completed", {"reset": str(status.get("nextResetAt", ""))})
		"in_battle":
			message = LocalizationManager.text("weekly_boss.in_battle")
	if str(status.get("state", "")) in ["available", "completed"] and not bool(status.get("hardDefeated", false)) and not unlock_message.is_empty():
		var hint := Label.new()
		hint.name = "HardUnlockHint"
		hint.text = unlock_message
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", GOLD)
		add_custom_control(hint)
	configure(
		LocalizationManager.text("weekly_boss.title", {"boss": boss_name}),
		message, "", LocalizationManager.text("weekly_boss.close")
	)


func popup_centered(_requested_size: Vector2i = Vector2i.ZERO, _force: bool = false) -> void:
	_adapt_buttons()
	super.popup_centered(Vector2i(620, 0), _force)
	if not difficulty_buttons.is_empty():
		difficulty_buttons[0].grab_focus.call_deferred()
	else:
		cancel_button.grab_focus.call_deferred()


func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_adapt_buttons)


func _adapt_buttons() -> void:
	if difficulty_grid == null:
		return
	var narrow := get_viewport().get_visible_rect().size.x < 600
	difficulty_grid.columns = 1 if narrow else 3
	panel.custom_minimum_size.x = minf(620, get_viewport().get_visible_rect().size.x - 32)


func _build_difficulty_buttons() -> void:
	difficulty_grid = GridContainer.new()
	difficulty_grid.name = "Difficulties"
	difficulty_grid.columns = 3
	difficulty_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_grid.add_theme_constant_override("h_separation", 12)
	difficulty_grid.add_theme_constant_override("v_separation", 10)
	add_custom_control(difficulty_grid)
	for index: int in DIFFICULTIES.size():
		var difficulty := DIFFICULTIES[index]
		var accent := CARD_COLORS[index]
		var button := Button.new()
		button.name = difficulty.capitalize()
		button.text = LocalizationManager.text("weekly_boss." + difficulty)
		button.custom_minimum_size = Vector2(160, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", accent)
		button.add_theme_color_override("font_hover_color", COLOR_TEXT)
		button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
		button.add_theme_color_override("font_focus_color", accent)
		button.add_theme_stylebox_override("normal", _make_style(COLOR_SURFACE, Color(accent, 0.5), 10, 1))
		button.add_theme_stylebox_override("hover", _make_style(COLOR_SURFACE_HOVER, accent, 10, 2))
		button.add_theme_stylebox_override("pressed", _make_style(COLOR_ACCENT_DARK, accent, 10, 2))
		button.add_theme_stylebox_override("focus", _make_style(Color.TRANSPARENT, accent, 10, 2))
		button.pressed.connect(_select_difficulty.bind(difficulty))
		difficulty_grid.add_child(button)
		difficulty_buttons.append(button)


func _select_difficulty(difficulty: String) -> void:
	difficulty_selected.emit(difficulty)
	hide_dialog()
