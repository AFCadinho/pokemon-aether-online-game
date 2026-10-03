extends "res://scripts/ui/aether_confirmation_dialog.gd"

signal difficulty_selected(difficulty: String)

const DIFFICULTIES: Array[String] = ["easy", "intermediate", "hard"]
const CARD_COLORS: Array[Color] = [Color("75cca0"), Color("69d8e7"), Color("ff8585")]
const GOLD := Color("e3bd68")

var difficulty_buttons: Array[Button] = []
var difficulty_grid: GridContainer
var card_scroll: ScrollContainer


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
			message = LocalizationManager.text("weekly_boss.choose")
			_build_difficulty_cards(status.get("difficulties", {}))
			if not unlock_message.is_empty():
				var hint := _label(unlock_message, 14, GOLD)
				hint.name = "HardUnlockHint"
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				add_custom_control(hint)
		"completed":
			message = LocalizationManager.text("weekly_boss.completed", {"reset": str(status.get("nextResetAt", ""))})
		"in_battle":
			message = LocalizationManager.text("weekly_boss.in_battle")
	configure(
		LocalizationManager.text("weekly_boss.title", {"boss": boss_name}),
		message, "", LocalizationManager.text("weekly_boss.close")
	)


func popup_centered(_requested_size: Vector2i = Vector2i.ZERO) -> void:
	_adapt_cards()
	super.popup_centered(Vector2i(780, 0))
	if not difficulty_buttons.is_empty():
		difficulty_buttons[0].grab_focus.call_deferred()
	else:
		cancel_button.grab_focus.call_deferred()


func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_adapt_cards)


func _adapt_cards() -> void:
	if difficulty_grid == null:
		return
	var narrow := get_viewport().get_visible_rect().size.x < 740
	difficulty_grid.columns = 1 if narrow else 3
	card_scroll.custom_minimum_size.y = 228 if narrow else 216
	# Keep the modal within short windows; the cards remain scrollable.
	card_scroll.custom_minimum_size.y = minf(card_scroll.custom_minimum_size.y, maxf(120, get_viewport().get_visible_rect().size.y - 280))
	panel.custom_minimum_size.x = minf(780, get_viewport().get_visible_rect().size.x - 32)


func _build_difficulty_cards(profiles: Dictionary) -> void:
	card_scroll = ScrollContainer.new()
	card_scroll.name = "DifficultyScroll"
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.follow_focus = true
	var scrollbar := card_scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", _make_style(COLOR_SURFACE, Color.TRANSPARENT, 4, 0))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var style := _make_style(COLOR_BORDER if state == "grabber" else COLOR_ACCENT, Color.TRANSPARENT, 4, 0)
		style.content_margin_left = 4
		style.content_margin_right = 4
		scrollbar.add_theme_stylebox_override(state, style)
	add_custom_control(card_scroll)
	difficulty_grid = GridContainer.new()
	difficulty_grid.name = "Difficulties"
	difficulty_grid.columns = 3
	difficulty_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_grid.add_theme_constant_override("h_separation", 12)
	difficulty_grid.add_theme_constant_override("v_separation", 10)
	card_scroll.add_child(difficulty_grid)
	for index: int in DIFFICULTIES.size():
		var difficulty := DIFFICULTIES[index]
		var profile: Dictionary = profiles.get(difficulty, {})
		var accent := CARD_COLORS[index]
		var button := Button.new()
		button.name = difficulty.capitalize()
		button.custom_minimum_size = Vector2(200, 212)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = LocalizationManager.text("weekly_boss.challenge") + " · " + LocalizationManager.text("weekly_boss." + difficulty)
		button.add_theme_stylebox_override("normal", _make_style(COLOR_SURFACE, Color(accent, 0.5), 10, 1))
		button.add_theme_stylebox_override("hover", _make_style(COLOR_SURFACE_HOVER, accent, 10, 2))
		button.add_theme_stylebox_override("pressed", _make_style(COLOR_ACCENT_DARK, accent, 10, 2))
		button.add_theme_stylebox_override("focus", _make_style(Color.TRANSPARENT, accent, 10, 2))
		button.pressed.connect(_select_difficulty.bind(difficulty))
		difficulty_grid.add_child(button)
		difficulty_buttons.append(button)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 16)
		button.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		margin.add_child(content)
		content.add_child(_label(LocalizationManager.text("weekly_boss." + difficulty), 20, accent))
		content.add_child(_label(LocalizationManager.text("weekly_boss.team_level", {"count": int(profile.get("teamSize", 6)), "level": int(profile.get("level", 0))}), 14, COLOR_MUTED))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(spacer)
		content.add_child(_label(LocalizationManager.text("weekly_boss.money", {"amount": int(profile.get("money", 0))}), 17, COLOR_TEXT))
		content.add_child(_label(LocalizationManager.text("weekly_boss.bp", {"amount": int(profile.get("battlePoints", 0))}), 14, COLOR_MUTED))
		content.add_child(_label(LocalizationManager.text("weekly_boss.item_rolls", {"count": int(profile.get("itemRolls", 0))}), 14, COLOR_MUTED))
		content.add_child(_label(LocalizationManager.text("weekly_boss.challenge") + "  →", 15, accent))
		_ignore_mouse(margin)


func _select_difficulty(difficulty: String) -> void:
	difficulty_selected.emit(difficulty)
	hide_dialog()


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.get_children():
		if child is Control:
			_ignore_mouse(child)
