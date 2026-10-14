class_name DaycarePopup
extends PanelContainer

signal closed
const ExternalLinks := preload("res://scripts/core/external_links.gd")
const STATS: Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]
const CYAN := Color("69d8e7")
const MUTED := Color("9eb3c5")
const GREEN := Color("70d6a1")
const RED := Color("ef7085")
const STAT_COLORS: Array[Color] = [Color("70d6a1"), Color("ef9b78"), Color("e4c66c"), Color("9ba9ef"), Color("c697df"), Color("69d8e7")]
var guide_button: Button
var pokemon_select: Button
var selected_index := -1
var party_entries: Array = []
var picker: Control
var picker_panel: PanelContainer
var picker_grid: GridContainer
var picker_hint: Label
var picker_title: Label
var picker_cancel: Button
var picker_close: Button
var picker_rows: Array = []
var picker_buttons: Array[Button] = []
var picker_compact := false
var exp_check: CheckBox
var ev_check: CheckBox
var level_input: SpinBox
var ev_inputs: Dictionary = {}
var ev_grid: GridContainer
var current_label: Label
var quote_label: Label
var status_label: Label
var preview_button: Button
var confirm_button: Button
var close_button: Button
var refresh_button: Button
var retry_button: Button
var job_container: VBoxContainer
var tabs: TabContainer
var confirmation: AetherConfirmationDialog
var entries: Array = []
var jobs: Array = []
var job_views: Array = []
var quote: Dictionary = {}
var daycare_cap := 5
var busy := false
var generation := 0
var clock_ticks := 0
var training_form: VBoxContainer
var training_notice: VBoxContainer
var notice_label: Label
var quote_card: PanelContainer
var help_label: Label
var state_loaded := false
var quote_price: Label
var quote_duration: Label
var quote_heading: Label
var training_columns: GridContainer
var ev_details: VBoxContainer

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.daycare." + key, values)

func _number(value: Variant) -> String:
	var digits := str(int(value))
	var separator := "." if LocalizationManager.current_locale in ["nl", "pt_BR"] else ","
	var result := ""
	while digits.length() > 3:
		result = separator + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

func _label(text_value: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color("eef8ff"))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer or parent is GridContainer else TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER if parent is HBoxContainer or parent is GridContainer else Control.SIZE_FILL
	parent.add_child(label)
	return label

func _button(text_value: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	_style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _surface(background: Color, border: Color, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style

func _style_button(button: Button, primary := false) -> void:
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("eef8ff"))
	button.add_theme_color_override("font_disabled_color", Color("627a8e"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var highlighted := state in ["hover", "focus", "pressed"]
		var background := Color("16485b") if primary else Color("0c1d2d")
		var border := CYAN if primary or highlighted else Color("315d78")
		if highlighted:
			background = Color("205568") if primary else Color("173149")
		if state == "disabled":
			background = Color("0c1826")
			border = Color("233b4d")
		var style := _surface(background, border, 9)
		style.content_margin_left = 14
		style.content_margin_right = 14
		button.add_theme_stylebox_override(state, style)

func _card(parent: Node, border := Color("27465b")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _surface(Color("0b1b2a"), border))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content

func _status(text_value: String, error := false) -> void:
	status_label.text = text_value
	status_label.add_theme_color_override("font_color", RED if error else MUTED)

func _clear_quote() -> void:
	quote.clear()
	quote_label.text = ""
	quote_card.hide()

func _show_load_error(message: String) -> void:
	_status(message, true)
	if not state_loaded:
		training_form.hide()
		training_notice.get_parent().show()
		notice_label.text = _t("load_error")
		notice_label.add_theme_color_override("font_color", RED)

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07101cfb")
	style.border_color = Color("#397b9c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	var title := _label(_t("title"), header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", CYAN)
	title.clip_text = true
	guide_button = _button(LocalizationManager.text("ui.daycare.forum_guide"), header, ExternalLinks.open_daycare_guide)
	guide_button.tooltip_text = LocalizationManager.text("ui.daycare.forum_guide_hint")
	refresh_button = _button(_t("refresh"), header, _load_state)
	close_button = _button("×", header, close_popup)
	close_button.tooltip_text = LocalizationManager.text("common.close")
	help_label = _label(_t("explanation"), layout)
	help_label.add_theme_color_override("font_color", MUTED)
	tabs = TabContainer.new()
	tabs.add_theme_stylebox_override("panel", _surface(Color("07101c00"), Color("00000000"), 0))
	var tab_bar := tabs.get_tab_bar()
	for state: String in ["selected", "unselected", "hovered", "disabled", "focus"]:
		var tab_style := _surface(Color("16485b") if state == "selected" else Color("0c1d2d"), CYAN if state in ["selected", "focus"] else Color("27465b"), 10)
		tab_bar.add_theme_stylebox_override("tab_" + state, tab_style)
		tabs.add_theme_stylebox_override("tab_" + state, tab_style)
	tabs.add_theme_color_override("font_selected_color", Color("eef8ff"))
	tabs.add_theme_color_override("font_unselected_color", MUTED)
	tabs.add_theme_font_size_override("font_size", 14)
	tab_bar.add_theme_color_override("font_selected_color", Color("eef8ff"))
	tab_bar.add_theme_color_override("font_unselected_color", MUTED)
	tab_bar.add_theme_font_size_override("font_size", 14)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var training_scroll := ScrollContainer.new()
	training_scroll.name = _t("new_training")
	training_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(training_scroll)
	_style_scroll(training_scroll)
	var training := VBoxContainer.new()
	training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training.add_theme_constant_override("separation", 10)
	training_scroll.add_child(training)
	training_notice = _card(training)
	notice_label = _label(_t("loading"), training_notice)
	notice_label.add_theme_color_override("font_color", MUTED)
	training_form = VBoxContainer.new()
	training_form.add_theme_constant_override("separation", 10)
	training_form.hide()
	training.add_child(training_form)
	training_columns = GridContainer.new()
	training_columns.columns = 2
	training_columns.add_theme_constant_override("h_separation", 12)
	training_columns.add_theme_constant_override("v_separation", 10)
	training_form.add_child(training_columns)
	var pokemon_column := VBoxContainer.new()
	pokemon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pokemon_column.add_theme_constant_override("separation", 10)
	training_columns.add_child(pokemon_column)
	var selection_card := _card(pokemon_column)
	var selection_title := _label(_t("choose_pokemon"), selection_card)
	selection_title.add_theme_color_override("font_color", CYAN)
	pokemon_select = _button(_t("choose_pokemon"), selection_card, _open_picker)
	pokemon_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_select.clip_text = true
	_build_picker()
	current_label = _label("", selection_card)
	current_label.add_theme_color_override("font_color", MUTED)
	current_label.add_theme_font_size_override("font_size", 12)
	var exp_card := _card(pokemon_column)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	exp_card.add_child(level_row)
	exp_check = CheckBox.new()
	exp_check.text = _t("exp_training")
	exp_check.toggled.connect(_targets_changed)
	exp_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(exp_check)
	_label(_t("target_level"), level_row)
	level_input = SpinBox.new()
	level_input.min_value = 1
	level_input.max_value = 100
	level_input.step = 1
	level_input.custom_minimum_size.x = 88
	level_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_input.value_changed.connect(_targets_changed)
	level_row.add_child(level_input)
	ev_check = CheckBox.new()
	ev_check.text = _t("ev_training")
	ev_check.toggled.connect(_targets_changed)
	var ev_card := _card(training_columns)
	(ev_card.get_parent() as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ev_card.add_child(ev_check)
	ev_details = VBoxContainer.new()
	ev_details.add_theme_constant_override("separation", 8)
	ev_card.add_child(ev_details)
	var grid := GridContainer.new()
	ev_grid = grid
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	ev_details.add_child(grid)
	for stat: String in STATS:
		var stat_column := VBoxContainer.new()
		stat_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(stat_column)
		var stat_label := _label(stat.to_upper(), stat_column)
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_label.add_theme_color_override("font_color", STAT_COLORS[STATS.find(stat)])
		var input := SpinBox.new()
		input.min_value = 0
		input.max_value = 252
		input.step = 1
		input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.custom_minimum_size.x = 76
		input.value_changed.connect(_targets_changed)
		stat_column.add_child(input)
		ev_inputs[stat] = input
	var hint := _label(_t("ev_hint"), ev_details)
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	var quote_content := _card(layout, CYAN.darkened(0.4))
	quote_card = quote_content.get_parent() as PanelContainer
	quote_card.hide()
	var quote_title := _label(_t("quote_title"), quote_content)
	quote_heading = quote_title
	quote_title.add_theme_color_override("font_color", CYAN)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 16)
	quote_content.add_child(metrics)
	var metric_values: Array[Label] = []
	for key: String in ["total_cost", "duration"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_child(column)
		var caption := _label(_t(key), column)
		caption.add_theme_color_override("font_color", MUTED)
		caption.add_theme_font_size_override("font_size", 12)
		var value := _label("", column)
		value.add_theme_color_override("font_color", CYAN)
		value.add_theme_font_size_override("font_size", 20)
		metric_values.append(value)
	quote_price = metric_values[0]
	quote_duration = metric_values[1]
	quote_label = _label("", quote_content)
	quote_label.add_theme_font_size_override("font_size", 13)
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.name = _t("in_training")
	jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(jobs_scroll)
	_style_scroll(jobs_scroll)
	job_container = VBoxContainer.new()
	job_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_container.add_theme_constant_override("separation", 12)
	jobs_scroll.add_child(job_container)
	status_label = _label("", layout)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", MUTED)
	var footer := HFlowContainer.new()
	layout.add_child(footer)
	preview_button = _button(_t("preview"), footer, _preview)
	confirm_button = _button(_t("deposit"), footer, _ask_confirm)
	_style_button(confirm_button, true)
	retry_button = _button(_t("retry"), footer, _retry)
	confirmation = preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)
	confirmation.style_spin_box(level_input)
	confirmation.style_checkbox(exp_check)
	confirmation.style_checkbox(ev_check)
	for stat: String in STATS:
		confirmation.style_spin_box(ev_inputs[stat] as SpinBox)
	for input: SpinBox in [level_input] + ev_inputs.values():
		input.get_line_edit().add_theme_stylebox_override("read_only", _surface(Color("0a1723"), Color("233b4d"), 10))
		input.get_line_edit().add_theme_color_override("font_uneditable_color", Color("627a8e"))
	pokemon_select.add_theme_stylebox_override("disabled", _surface(Color("0a1723"), Color("233b4d"), 10))
	tabs.tab_changed.connect(_tab_changed)
	var timer := Timer.new()
	timer.wait_time = 1
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	get_viewport().size_changed.connect(_fit_window)
	minimum_size_changed.connect(_queue_fit)
	_fit_window()
	_queue_fit()
	_set_busy(false)

func _tab_changed(index: int) -> void:
	preview_button.visible = index == 0 and training_form.visible
	confirm_button.visible = index == 0 and training_form.visible
	quote_card.visible = index == 0 and not quote.is_empty()
	_queue_fit()

func _style_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", _surface(Color("07101c"), Color("00000000"), 3))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _surface(Color("315d78") if state == "grabber" else CYAN.darkened(0.25), Color("00000000"), 3))

func _queue_fit() -> void:
	_fit_window.call_deferred()

func _fit_window() -> void:
	var screen := get_viewport_rect().size
	var available_width := minf(840, screen.x - 32)
	if training_columns != null:
		training_columns.columns = 2 if available_width >= 820 else 1
	if ev_grid != null:
		ev_grid.columns = 2 if available_width < 560 else 3
	size.x = available_width
	if help_label != null:
		help_label.visible = screen.y >= 480
	if quote_label != null:
		quote_label.visible = screen.y >= 480
		quote_heading.visible = screen.y >= 480
	# Keep the same frame across modes, quotes, tabs and loading states.
	size.y = minf(720, screen.y - 32)
	position = (screen - size) * 0.5
	_fit_picker()

func open_daycare() -> void:
	picker.hide()
	visible = true
	generation += 1
	quote.clear()
	await _load_state()

func close_popup() -> void:
	if busy:
		return
	generation += 1
	confirmation.hide_dialog()
	picker.hide()
	visible = false
	closed.emit()

func _set_busy(value: bool) -> void:
	busy = value
	var pending := not DaycareService.pending_request.is_empty() or picker.visible
	pokemon_select.disabled = value or pending or party_entries.is_empty()
	var current_level := int(entries[selected_index].get("pokemon", {}).get("level", 1)) if not entries.is_empty() else 100
	exp_check.disabled = value or pending or entries.is_empty() or current_level >= daycare_cap
	ev_check.disabled = value or pending or entries.is_empty()
	ev_details.visible = ev_check.button_pressed
	level_input.editable = not value and not pending and exp_check.button_pressed and not entries.is_empty()
	for stat: String in STATS:
		(ev_inputs[stat] as SpinBox).editable = not value and not pending and ev_check.button_pressed and not entries.is_empty()
	preview_button.disabled = value or pending or entries.is_empty() or jobs.size() >= 6 or not (exp_check.button_pressed or ev_check.button_pressed)
	confirm_button.disabled = value or pending or quote.is_empty()
	close_button.disabled = value or picker.visible
	refresh_button.disabled = value or picker.visible
	retry_button.visible = not DaycareService.pending_request.is_empty()
	retry_button.disabled = value
	_tab_changed(tabs.current_tab)
	_tick()
	if picker.visible:
		_render_picker()

func _load_state() -> void:
	if busy:
		return
	_set_busy(true)
	_status(_t("loading"))
	var current := generation
	var response: Dictionary = await DaycareService.state()
	if current != generation:
		return
	if bool(response.get("success", false)):
		_apply_state(response.get("body", {}))
	else:
		_show_load_error(str(response.get("error", "")))
	_set_busy(false)

func _apply_state(data: Dictionary) -> void:
	var previous_id := _entry_id(entries[selected_index]) if selected_index >= 0 and selected_index < entries.size() else 0
	state_loaded = true
	entries = data.get("pokemon", []).filter(_is_party_entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["location"]["partySlot"]) < int(b["location"]["partySlot"]))
	party_entries = data.get("party", data.get("pokemon", [])).filter(_is_party_entry)
	selected_index = -1 if entries.is_empty() else 0
	for index in range(entries.size()):
		if _entry_id(entries[index]) == previous_id:
			selected_index = index
	jobs = data.get("jobs", [])
	training_form.visible = not party_entries.is_empty()
	training_notice.get_parent().visible = party_entries.is_empty()
	notice_label.text = _t("no_pokemon")
	notice_label.add_theme_color_override("font_color", MUTED)
	daycare_cap = int(data.get("daycareLevelCap", 5))
	clock_ticks = Time.get_ticks_msec()
	_clear_quote()
	_pokemon_changed(0)
	_build_jobs()
	_render_picker()
	_status(_t("state", {"count": jobs.size(), "money": _number(data.get("money", 0)), "cap": daycare_cap}))
	if not DaycareService.pending_request.is_empty():
		_status(_t("pending"))

func _name(pokemon: Dictionary) -> String:
	var nickname: Variant = pokemon.get("nickname")
	return str(nickname) if nickname is String and not str(nickname).is_empty() else str(pokemon.get("displaySpecies", pokemon.get("species", "Pokémon")))

func _pokemon_changed(_index: int) -> void:
	_clear_quote()
	if entries.is_empty():
		pokemon_select.text = _t("choose_pokemon")
		exp_check.set_pressed_no_signal(false)
		ev_check.set_pressed_no_signal(false)
		current_label.text = _t("no_pokemon")
		_set_busy(busy)
		return
	var p: Dictionary = entries[selected_index].get("pokemon", {})
	pokemon_select.text = "%s · Lv.%s · %s" % [_name(p), _number(p.get("level", 1)), _t("party_slot", {"slot": int(entries[selected_index]["location"]["partySlot"]) + 1})]
	var level := int(p.get("level", 1))
	level_input.max_value = max(daycare_cap, level)
	level_input.min_value = level
	level_input.set_value_no_signal(mini(level + 1, int(level_input.max_value)))
	exp_check.set_pressed_no_signal(level < daycare_cap)
	ev_check.set_pressed_no_signal(false)
	var current_evs: Dictionary = p.get("evs", {})
	var stored_evs: Dictionary = p.get("storedEvs", p.get("stored_evs", {}))
	var stored_text: Array[String] = []
	for stat: String in STATS:
		var input := ev_inputs[stat] as SpinBox
		input.min_value = int(current_evs.get(stat, 0))
		input.set_value_no_signal(input.min_value)
		stored_text.append("%s %s" % [stat.to_upper(), _number(stored_evs.get(stat, 0))])
	current_label.text = _t("current", {"level": level, "experience": _number(p.get("experience", 0)), "stored": " · ".join(stored_text)})
	_set_busy(busy)

func _targets_changed(_value: Variant) -> void:
	_clear_quote()
	_set_busy(busy)

func _selection() -> Dictionary:
	if entries.is_empty():
		return {}
	var p: Dictionary = entries[selected_index].get("pokemon", {})
	var selection := {"pokemonId": int(p.get("ownedPokemonId", p.get("pokemonId", 0)))}
	if exp_check.button_pressed:
		selection["targetLevel"] = int(level_input.value)
	if ev_check.button_pressed:
		var evs: Dictionary = {}
		for stat: String in STATS:
			evs[stat] = int((ev_inputs[stat] as SpinBox).value)
		selection["targetEvs"] = evs
	return selection

func _preview() -> void:
	if busy or picker.visible or entries.is_empty():
		return
	if ev_check.button_pressed:
		var total := 0
		for stat: String in STATS:
			total += int((ev_inputs[stat] as SpinBox).value)
		if total > 510:
			_status(_t("ev_total_error"), true)
			return
	_set_busy(true)
	var current := generation
	var response: Dictionary = await DaycareService.preview(_selection())
	if current != generation:
		return
	if bool(response.get("success", false)):
		_show_quote(response.get("body", {}))
	else:
		_status(str(response.get("error", "")), true)
	_set_busy(false)

func _show_quote(data: Dictionary) -> void:
	quote = data
	quote_card.show()
	quote_price.text = _number(data.get("price", 0)) + " ₽"
	quote_duration.text = _duration(int(data.get("durationSeconds", 0)))
	var lines: Array[String] = []
	var exp_selected := bool(data.get("expSelected", exp_check.button_pressed))
	var ev_selected := bool(data.get("evSelected", ev_check.button_pressed))
	if exp_selected:
		var current_level := int(entries[selected_index].get("pokemon", {}).get("level", 1)) if not entries.is_empty() else 1
		lines.append(_t("summary_exp", {"start": _number(data.get("startLevel", current_level)), "level": _number(data.get("targetLevel", 1)), "experience": _number(data.get("requiredExperience", 0)), "time": _duration(int(data.get("expDurationSeconds", 0)))}))
	else:
		lines.append(_t("summary_no_exp", {"level": _number(data.get("targetLevel", 1))}))
	var target_evs: Array[String] = []
	var stored_used := 0
	for stat: String in STATS:
		var target := int(data.get("targetEvs", {}).get(stat, 0))
		if target > 0:
			target_evs.append("%s %s" % [stat.to_upper(), _number(target)])
		stored_used += int(data.get("consumeStoredEvs", {}).get(stat, 0))
	if ev_selected:
		lines.append(_t("summary_evs", {"evs": " · ".join(target_evs) if not target_evs.is_empty() else "0"}))
		if int(data.get("requiredEvs", 0)) == 0 and stored_used == 0:
			lines.append(_t("summary_ev_reached"))
		else:
			lines.append(_t("summary_ev_work", {"new": _number(data.get("requiredEvs", 0)), "stored": _number(stored_used), "time": _duration(int(data.get("evDurationSeconds", 0)))}))
	else:
		lines.append(_t("summary_no_evs"))
	var costs: Dictionary = data.get("priceBreakdown", {})
	if not costs.is_empty():
		lines.append(_t("summary_costs", {"start": _number(costs.get("start", 0)), "exp": _number(costs.get("experience", 0)), "ev": _number(costs.get("evs", 0))}))
	quote_label.text = "\n".join(lines)
	_fit_window()
	_status(_t("review"))

func _ask_confirm() -> void:
	if busy or picker.visible or quote.is_empty():
		return
	confirmation.configure(_t("title"), _t("confirmation", {"price": _number(quote.get("price", 0)), "time": _duration(int(quote.get("durationSeconds", 0)))}), _t("deposit"), LocalizationManager.text("common.cancel"))
	confirmation.popup_centered()

func _confirm() -> void:
	if busy or picker.visible or quote.is_empty():
		return
	confirmation.hide_dialog()
	_set_busy(true)
	var response: Dictionary = await DaycareService.confirm(str(quote.get("previewId", "")), quote)
	await _after_write(response, false)

func _pickup(job_id: String) -> void:
	if busy or not DaycareService.pending_request.is_empty():
		return
	_set_busy(true)
	var response: Dictionary = await DaycareService.pickup(job_id)
	await _after_write(response, true)

func _retry() -> void:
	if busy:
		return
	var was_pickup := str(DaycareService.pending_request.get("kind", "")) == "pickup"
	_set_busy(true)
	var response: Dictionary = await DaycareService.retry()
	await _after_write(response, was_pickup)

func _after_write(response: Dictionary, pickup: bool) -> void:
	_set_busy(false)
	if bool(response.get("success", false)):
		await _load_state()
		_status(_t("picked_up") if pickup else _t("deposited"))
		if not pickup:
			tabs.current_tab = 1
		else:
			var scene := get_tree().current_scene
			var overlay := scene.get_node_or_null("UIOverlay") if scene != null else null
			if overlay != null and overlay.has_method("queue_reward_move_learn_candidates"):
				overlay.call("queue_reward_move_learn_candidates", response.get("body", {}).get("reward", {}))
	else:
		if DaycareService.pending_request.is_empty():
			await _load_state()
			_status(str(response.get("error", "")), true)
		else:
			_status(_t("pending"))
	_set_busy(false)

func _build_jobs() -> void:
	for node in job_container.get_children():
		job_container.remove_child(node)
		node.queue_free()
	job_views.clear()
	for job: Dictionary in jobs:
		var card := _card(job_container)
		var p: Dictionary = job.get("pokemon", {})
		var plan: Dictionary = job.get("plan", {})
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 12)
		card.add_child(header)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = PokemonAssets.load_party_icon(str(p.get("speciesId", p.get("species_id", p.get("species", "")))), bool(p.get("shiny", false)))
		header.add_child(icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 5)
		header.add_child(details)
		var title := _label(_t("job_title", {"place": int(job.get("bed", 0)) + 1, "pokemon": _name(p), "level": _number(plan.get("targetLevel", 1))}), details)
		title.add_theme_color_override("font_color", CYAN)
		var goal: Array[String] = []
		if bool(plan.get("expSelected", false)):
			goal.append(_t("exp_goal", {"level": _number(plan.get("targetLevel", 1))}))
		if bool(plan.get("evSelected", false)):
			var spread: Array[String] = []
			for stat: String in STATS:
				spread.append("%s %s" % [stat.to_upper(), _number(plan.get("targetEvs", {}).get(stat, 0))])
			goal.append("EV: " + " · ".join(spread))
		var goal_label := _label("\n".join(goal), details)
		goal_label.add_theme_color_override("font_color", MUTED)
		goal_label.add_theme_font_size_override("font_size", 12)
		var countdown := _label("", details)
		var progress := ProgressBar.new()
		progress.show_percentage = false
		progress.custom_minimum_size.y = 8
		progress.add_theme_stylebox_override("background", _surface(Color("07101c"), Color("00000000"), 0))
		progress.add_theme_stylebox_override("fill", _surface(CYAN.darkened(0.25), Color("00000000"), 0))
		progress.max_value = maxi(int(plan.get("durationSeconds", 0)), 1)
		card.add_child(progress)
		var pickup := _button(_t("pickup"), card, _pickup.bind(str(job.get("id", ""))))
		_style_button(pickup, true)
		job_views.append({"job": job, "icon": icon, "countdown": countdown, "progress": progress, "pickup": pickup})
	if jobs.is_empty():
		var empty := _label(_t("no_jobs"), _card(job_container))
		empty.add_theme_color_override("font_color", MUTED)
	_tick()

func _tick() -> void:
	if not visible:
		return
	var elapsed := maxi(0, int((Time.get_ticks_msec() - clock_ticks) / 1000))
	for view: Dictionary in job_views:
		var job: Dictionary = view.get("job", {})
		var remaining := maxi(0, int(job.get("remainingSeconds", 0)) - elapsed)
		(view.get("countdown") as Label).text = _t("ready") if remaining == 0 else _t("remaining", {"time": _duration(remaining)})
		(view.get("countdown") as Label).add_theme_color_override("font_color", GREEN if remaining == 0 else MUTED)
		var duration := int(job.get("plan", {}).get("durationSeconds", 0))
		var progress := view.get("progress") as ProgressBar
		progress.value = progress.max_value if remaining == 0 else maxi(0, duration - remaining)
		(view.get("pickup") as Button).disabled = busy or remaining > 0 or not DaycareService.pending_request.is_empty()

func _duration(seconds: int) -> String:
	return "%02d:%02d:%02d" % [int(seconds / 3600), int((seconds % 3600) / 60), seconds % 60]

static func _entry_id(entry: Dictionary) -> int:
	var pokemon: Dictionary = entry.get("pokemon", {})
	return int(pokemon.get("ownedPokemonId", pokemon.get("pokemonId", 0)))

static func _is_party_entry(entry: Dictionary) -> bool:
	var location: Dictionary = entry.get("location", {})
	return location.get("type") == "party" and int(location.get("partySlot", -1)) >= 0 and int(location.get("partySlot", -1)) < 6

func _picker_reason(entry: Dictionary) -> String:
	if entry.is_empty():
		return _t("picker.empty")
	if not bool(entry.get("eligible", true)):
		var code := str(entry.get("blockedReason", ""))
		var key := "ui.daycare.picker.reason." + code
		var translated := LocalizationManager.text(key)
		return _t("picker.unavailable") if translated == key else translated
	for candidate: Dictionary in entries:
		if _entry_id(candidate) == _entry_id(entry):
			return ""
	return _t("picker.unavailable")

func _picker_label(text_value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _build_picker() -> void:
	picker = Control.new()
	picker.name = "PartyPicker"
	picker.top_level = true
	picker.z_index = 4096
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.hide()
	add_child(picker)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.add_child(center)
	picker_panel = PanelContainer.new()
	picker_panel.add_theme_stylebox_override("panel", _surface(Color("07101c"), CYAN.darkened(0.4), 12))
	center.add_child(picker_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	picker_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	picker_title = _label(_t("choose_pokemon"), header)
	picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_title.clip_text = true
	picker_title.add_theme_font_size_override("font_size", 20)
	picker_title.add_theme_color_override("font_color", CYAN)
	picker_close = _button("×", header, _close_picker)
	picker_close.tooltip_text = LocalizationManager.text("common.close")
	picker_hint = _label(_t("picker.hint"), stack)
	picker_hint.add_theme_color_override("font_color", MUTED)
	picker_hint.add_theme_font_size_override("font_size", 12)
	picker_grid = GridContainer.new()
	picker_grid.add_theme_constant_override("h_separation", 8)
	picker_grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(picker_grid)
	picker_cancel = _button(LocalizationManager.text("common.cancel"), stack, _close_picker)

func _fit_picker() -> void:
	if picker == null:
		return
	var screen := get_viewport_rect().size
	picker.global_position = Vector2.ZERO
	picker.size = screen
	picker_panel.custom_minimum_size.x = minf(1120, screen.x - 24)
	var columns := 6 if screen.x >= 900 else 3 if screen.x >= 500 else 2
	var compact := screen.y < 700 or columns == 2
	var changed := picker_grid.columns != columns or picker_compact != compact
	picker_grid.columns = columns
	picker_compact = compact
	picker_hint.visible = not compact
	if changed and picker.visible:
		_render_picker()

func _open_picker() -> void:
	if busy or not state_loaded or party_entries.is_empty() or not DaycareService.pending_request.is_empty() or confirmation.visible:
		return
	picker.show()
	_fit_picker()
	_set_busy(busy)

func _close_picker() -> void:
	picker.hide()
	_set_busy(busy)
	if is_visible_in_tree() and not pokemon_select.disabled:
		pokemon_select.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if picker.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_picker()

func _render_picker() -> void:
	var focused_slot := picker_buttons.find(get_viewport().gui_get_focus_owner())
	for child: Node in picker_grid.get_children():
		picker_grid.remove_child(child)
		child.queue_free()
	picker_buttons.clear()
	picker_rows = [{}, {}, {}, {}, {}, {}]
	for entry: Dictionary in party_entries:
		picker_rows[int(entry["location"]["partySlot"])] = entry
	picker_title.text = _t("choose_pokemon")
	picker_hint.text = _t("picker.hint")
	picker_cancel.text = LocalizationManager.text("common.cancel")
	for slot in range(6):
		var entry: Dictionary = picker_rows[slot]
		var reason := _picker_reason(entry)
		var selected := not entry.is_empty() and selected_index >= 0 and _entry_id(entry) == _entry_id(entries[selected_index])
		var button := _button("", picker_grid, _picker_pressed.bind(slot, _entry_id(entry)))
		_style_button(button, selected)
		button.custom_minimum_size = Vector2(0, (126 if get_viewport_rect().size.y >= 500 else 104) if picker_compact else 220)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not reason.is_empty() or busy or not DaycareService.pending_request.is_empty()
		picker_buttons.append(button)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_right = -6
		content.offset_top = 6
		content.offset_bottom = -6
		content.add_theme_constant_override("separation", 2)
		button.add_child(content)
		content.add_child(_picker_label(_t("party_slot", {"slot": slot + 1}), MUTED, 10 if picker_compact else 12))
		var pokemon: Dictionary = entry.get("pokemon", {})
		var sprite := TextureRect.new()
		sprite.custom_minimum_size.y = (40 if get_viewport_rect().size.y >= 500 else 24) if picker_compact else 64
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not entry.is_empty():
			sprite.texture = PokemonAssets.load_home_sprite(str(pokemon.get("speciesId", pokemon.get("species", ""))), bool(pokemon.get("shiny", false)))
			sprite.modulate.a = 1.0 if reason.is_empty() else 0.45
		content.add_child(sprite)
		var name_label := _picker_label(_t("picker.empty") if entry.is_empty() else _name(pokemon) + (" ★" if pokemon.get("shiny", false) else ""), MUTED if entry.is_empty() else CYAN, 12 if picker_compact else 14)
		name_label.max_lines_visible = 1 if picker_compact else 2
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(name_label)
		content.add_child(_picker_label("—" if entry.is_empty() else _t("picker.level", {"level": _number(pokemon.get("level", 1))}), MUTED, 10 if picker_compact else 12))
		var state_label := _picker_label(reason if not reason.is_empty() else _t("picker.selected" if selected else "picker.available"), GREEN if reason.is_empty() else MUTED if entry.is_empty() else RED, 10 if picker_compact else 12)
		state_label.max_lines_visible = 1 if picker_compact else 2
		state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(state_label)
		button.tooltip_text = _t("picker.empty") if entry.is_empty() else "\n".join([_name(pokemon), _t("party_slot", {"slot": slot + 1}), _t("picker.level", {"level": _number(pokemon.get("level", 1))}), reason])
	var focus_order: Array[Button] = [picker_close]
	for button: Button in picker_buttons:
		if not button.disabled:
			focus_order.append(button)
	focus_order.append(picker_cancel)
	for index in range(focus_order.size()):
		var button := focus_order[index]
		button.focus_next = button.get_path_to(focus_order[(index + 1) % focus_order.size()])
		button.focus_previous = button.get_path_to(focus_order[(index - 1 + focus_order.size()) % focus_order.size()])
	if picker.is_visible_in_tree():
		if focused_slot >= 0 and not picker_buttons[focused_slot].disabled:
			picker_buttons[focused_slot].grab_focus()
		else:
			(focus_order[1] if focus_order.size() > 2 else picker_cancel).grab_focus()

func _picker_pressed(slot: int, expected_id: int) -> void:
	if busy or not picker.visible or not DaycareService.pending_request.is_empty() or slot < 0 or slot >= picker_rows.size():
		return
	var entry: Dictionary = picker_rows[slot]
	if _entry_id(entry) != expected_id or not _picker_reason(entry).is_empty():
		return
	for index in range(entries.size()):
		if _entry_id(entries[index]) == expected_id:
			var changed := selected_index != index
			selected_index = index
			picker.hide()
			if changed:
				_pokemon_changed(index)
			_set_busy(busy)
			pokemon_select.grab_focus()
			return
