extends MarginContainer

class_name BattleDamageCalcPanel

signal defender_assumptions_changed(assumptions: Dictionary, edited_fields: Dictionary)

const TEXT_PRIMARY := Color(0.95686275, 0.94509804, 0.91764706, 1.0)
const TEXT_SECONDARY := Color(0.72156864, 0.72156864, 0.72156864, 1.0)
const TEXT_MUTED := Color(0.56, 0.6, 0.68, 1.0)
const TEXT_ACCENT := Color(0.84705883, 0.7058824, 0.41568628, 1.0)
const TEXT_ERROR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const ROW_BG := Color(0.014, 0.023, 0.043, 0.94)
const ROW_BORDER := Color(0.1764706, 0.3372549, 0.5568628, 0.82)
const PROFILE_BG := Color(0.026, 0.039, 0.07, 0.92)
const PROFILE_BORDER := Color(0.13, 0.24, 0.4, 0.78)
const CHIP_BG := Color(0.035, 0.052, 0.088, 0.92)
const CHIP_BORDER := Color(0.1764706, 0.3372549, 0.5568628, 0.85)
const TAB_BG := Color(0.024, 0.036, 0.062, 0.92)
const TAB_ACTIVE_BG := Color(0.124, 0.203, 0.332, 0.98)
const TAB_BORDER := Color(0.19, 0.31, 0.48, 0.9)
const SUSPICIOUS_PERCENT_LIMIT := 999.0
const KO_COLUMN_WIDTH := 104.0
const SUBTAB_YOUR_DAMAGE := "your"
const SUBTAB_THEIR_DAMAGE := "their"
const EV_TOTAL_LIMIT := 508
const ASSUMPTION_CHANGE_DEBOUNCE_SECONDS := 0.35
const NATURE_OPTIONS := ["Hardy", "Adamant", "Modest", "Jolly", "Timid", "Bold", "Calm", "Impish", "Careful"]
const EV_PRESETS := [
	{"label": "EVs 0", "chip": "EVs 0", "evs": {}},
	{"label": "252 HP", "chip": "EVs HP", "evs": {"hp": 252}},
	{"label": "252 Def", "chip": "EVs Def", "evs": {"def": 252}},
	{"label": "252 SpD", "chip": "EVs SpD", "evs": {"spd": 252}},
	{"label": "252 HP / 252 Def", "chip": "EVs HP/Def", "evs": {"hp": 252, "def": 252}},
	{"label": "252 HP / 252 SpD", "chip": "EVs HP/SpD", "evs": {"hp": 252, "spd": 252}},
]
const EV_INPUT_ROWS := [["hp", "atk"], ["def", "spa"], ["spd", "spe"]]

@onready var content: VBoxContainer = $VBoxContainer

var active_subtab := SUBTAB_YOUR_DAMAGE
var is_loading := false
var loading_attacker_name := ""
var loading_defender_name := ""
var last_response: Dictionary = {}
var last_error := ""
var defender_assumptions: Dictionary = {}
var edited_assumption_fields: Dictionary = {}
var live_ev_spinboxes: Dictionary = {}
var live_ev_total_label: Label
var live_ev_focus_stat := ""
var live_ev_focus_caret := -1
var assumption_change_timer: Timer
var is_syncing_assumption_controls := false


func _ready() -> void:
	clip_contents = true
	content.clip_contents = true
	content.add_theme_constant_override("separation", 4)
	assumption_change_timer = Timer.new()
	assumption_change_timer.one_shot = true
	assumption_change_timer.wait_time = ASSUMPTION_CHANGE_DEBOUNCE_SECONDS
	assumption_change_timer.timeout.connect(_emit_defender_assumptions_changed)
	add_child(assumption_change_timer)


func show_idle() -> void:
	close_assumption_popover()
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_response = {}
	last_error = ""
	active_subtab = SUBTAB_YOUR_DAMAGE
	_render_current_state()


func show_loading(attacker_name: String = "", defender_name: String = "") -> void:
	is_loading = true
	loading_attacker_name = attacker_name
	loading_defender_name = defender_name
	last_error = ""
	_render_current_state()


func show_error(message: String) -> void:
	close_assumption_popover()
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_response = {}
	last_error = _fallback_text(message, "Damage calculation failed.")
	_render_current_state()


func show_response(response: Dictionary) -> void:
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_error = ""

	if not bool(response.get("success", false)):
		last_response = {}
		last_error = str(response.get("error", "Damage calculation failed."))
	else:
		last_response = response

	_render_current_state()


func set_defender_assumptions(assumptions: Dictionary, edited_fields: Dictionary = {}) -> void:
	defender_assumptions = _duplicate_dictionary(assumptions)
	edited_assumption_fields = _duplicate_dictionary(edited_fields)
	if is_inside_tree():
		_render_current_state()


func close_assumption_popover() -> void:
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	live_ev_spinboxes.clear()
	live_ev_total_label = null
	live_ev_focus_stat = ""
	live_ev_focus_caret = -1


func _render_current_state() -> void:
	_clear_content()
	_add_subtabs()

	if active_subtab == SUBTAB_THEIR_DAMAGE:
		_add_profile_summary("Opponent", "Your Pokemon", "HP ?", "Lv ?")
		_add_status("Coming soon", TEXT_SECONDARY)
		return

	if not last_response.is_empty():
		_render_your_damage_response(last_response)
		return

	if is_loading:
		_add_profile_summary(
			_fallback_text(loading_attacker_name, "Your Pokemon"),
			_fallback_text(loading_defender_name, "Opponent"),
			"HP ?",
			"Lv ?"
		)
		_add_status("Calculating damage...", TEXT_SECONDARY)
		return

	if last_error != "":
		_add_profile_summary("Your Pokemon", "Opponent", "HP ?", "Lv ?")
		_add_status(last_error, TEXT_ERROR)
		return

	if last_response.is_empty():
		_add_profile_summary("Your Pokemon", "Opponent", "HP ?", "Lv ?")
		_add_status("Open Calc to load current damage ranges.", TEXT_SECONDARY)
		return

	_render_your_damage_response(last_response)


func _render_your_damage_response(response: Dictionary) -> void:
	var attacker: Dictionary = _as_dictionary(response.get("attacker", {}))
	var defender: Dictionary = _as_dictionary(response.get("defender", {}))
	_add_profile_summary(
		_get_pokemon_label(attacker, "Your Pokemon"),
		_get_pokemon_label(defender, "Opponent"),
		_get_hp_label(defender),
		_get_level_label(defender)
	)
	_add_assumption_chips(defender, response)

	var results: Array = _as_array(response.get("results", []))
	if results.is_empty():
		_add_status(_fallback_text(str(response.get("emptyReason", "")), "No damage results available."), TEXT_SECONDARY)
		return

	for result_value: Variant in results:
		if result_value is Dictionary:
			_add_move_result_row(result_value as Dictionary, defender)


func _clear_content() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _add_subtabs() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)

	row.add_child(_make_subtab_button("Your Dmg", SUBTAB_YOUR_DAMAGE))
	row.add_child(_make_subtab_button("Their Dmg", SUBTAB_THEIR_DAMAGE))


func _make_subtab_button(text: String, tab_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT_PRIMARY if active_subtab == tab_id else TEXT_SECONDARY)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if active_subtab == tab_id else TAB_BG, TAB_BORDER, 4, 5.0, 2.0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(TAB_ACTIVE_BG.lightened(0.08), TAB_BORDER.lightened(0.1), 4, 5.0, 2.0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(TAB_ACTIVE_BG, TAB_BORDER.lightened(0.18), 4, 5.0, 2.0)
	)
	if tab_id == SUBTAB_YOUR_DAMAGE:
		button.pressed.connect(_on_your_damage_tab_pressed)
	else:
		button.pressed.connect(_on_their_damage_tab_pressed)
	return button


func _on_your_damage_tab_pressed() -> void:
	if active_subtab == SUBTAB_YOUR_DAMAGE:
		return
	close_assumption_popover()
	active_subtab = SUBTAB_YOUR_DAMAGE
	_render_current_state()


func _on_their_damage_tab_pressed() -> void:
	if active_subtab == SUBTAB_THEIR_DAMAGE:
		return
	close_assumption_popover()
	active_subtab = SUBTAB_THEIR_DAMAGE
	_render_current_state()


func _add_profile_summary(attacker_name: String, defender_name: String, hp_label: String, level_label: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 5, 7.0, 4.0))
	content.add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var matchup := _make_label(
		"%s -> %s" % [
			_fallback_text(attacker_name, "Your Pokemon"),
			_fallback_text(defender_name, "Opponent"),
		],
		13,
		TEXT_PRIMARY
	)
	matchup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(matchup)

	var info := HBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.clip_contents = true
	info.add_theme_constant_override("separation", 10)
	box.add_child(info)

	info.add_child(_make_info_label(_fallback_text(hp_label, "HP ?")))
	info.add_child(_make_info_label(_fallback_text(level_label, "Lv ?")))


func _add_status(text: String, color: Color) -> void:
	var label := _make_label(text, 13, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)


func _add_assumption_chips(defender: Dictionary, response: Dictionary) -> void:
	var assumptions := _get_display_assumptions(defender)
	_add_live_assumption_controls(assumptions)

	if not _as_array(response.get("warnings", [])).is_empty():
		var info := _make_label("Info", 10, TEXT_MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(info)


func _add_move_result_row(result: Dictionary, defender: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(ROW_BG, ROW_BORDER, 5, 6.0, 4.0))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.clip_contents = true
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)

	var move_name := _get_move_name(result)
	var move_label := _make_label(_fallback_text(move_name, "Unknown move"), 13, TEXT_PRIMARY)
	move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(move_label)

	var ko_label := _make_label(_get_primary_result_label(result, defender), 12, TEXT_ACCENT)
	ko_label.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 0)
	ko_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(ko_label)

	var percent_label := _get_percent_label(result)
	var meta := _get_move_meta(result)
	if (percent_label != "" and percent_label != "--") or meta != "":
		var bottom := HBoxContainer.new()
		bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.clip_contents = true
		bottom.add_theme_constant_override("separation", 6)
		box.add_child(bottom)

		if percent_label != "" and percent_label != "--":
			var percent := _make_label(percent_label, 12, TEXT_SECONDARY)
			percent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom.add_child(percent)

		if meta != "":
			var meta_label := _make_label(meta, 10, TEXT_MUTED)
			meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			bottom.add_child(meta_label)

	if not _as_array(result.get("warnings", [])).is_empty():
		var info := _make_label("Info", 10, TEXT_MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(info)

	content.add_child(panel)


func _make_chip(text: String) -> Label:
	var label := _make_label(text, 11, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(44, 20)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 4, 5.0, 2.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_info_label(text: String) -> Label:
	var label := _make_label(text, 11, TEXT_SECONDARY)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_live_assumption_controls(assumptions: Dictionary) -> void:
	is_syncing_assumption_controls = true
	live_ev_spinboxes.clear()
	live_ev_total_label = null
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 5, 6.0, 5.0))
	content.add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var item := _make_chip(_get_named_assumption_label(assumptions, "item", "Item ?"))
	item.modulate = Color(1, 1, 1, 0.72)
	row.add_child(item)

	var ability := _make_chip(_get_named_assumption_label(assumptions, "ability", "Ability ?"))
	ability.modulate = Color(1, 1, 1, 0.72)
	row.add_child(ability)

	var reset_button := _make_small_button("Reset", _reset_live_assumptions)
	row.add_child(reset_button)

	var label := _make_label("Nature", 12, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(52, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var dropdown := OptionButton.new()
	dropdown.focus_mode = Control.FOCUS_NONE
	dropdown.custom_minimum_size = Vector2(0, 26)
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.clip_text = true
	dropdown.add_theme_font_size_override("font_size", 12)
	var selected_nature: String = _fallback_text(str(assumptions.get("nature", "")).strip_edges(), "Hardy")
	for index in range(NATURE_OPTIONS.size()):
		var nature := str(NATURE_OPTIONS[index])
		dropdown.add_item(nature, index)
		if nature == selected_nature:
			dropdown.select(index)
	dropdown.item_selected.connect(_on_live_nature_selected.bind(dropdown))

	var nature_row := HBoxContainer.new()
	nature_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nature_row.clip_contents = true
	nature_row.add_theme_constant_override("separation", 6)
	box.add_child(nature_row)
	nature_row.add_child(label)
	nature_row.add_child(dropdown)

	var ev_header := HBoxContainer.new()
	ev_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_header.clip_contents = true
	box.add_child(ev_header)

	var title := _make_label("EVs", 12, TEXT_SECONDARY)
	ev_header.add_child(title)

	live_ev_total_label = _make_label("", 11, TEXT_MUTED)
	live_ev_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ev_header.add_child(live_ev_total_label)

	var evs: Dictionary = _as_dictionary(assumptions.get("evs", {}))
	for pair_value: Variant in EV_INPUT_ROWS:
		var pair: Array = pair_value as Array
		var ev_row := HBoxContainer.new()
		ev_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev_row.clip_contents = true
		ev_row.add_theme_constant_override("separation", 8)
		box.add_child(ev_row)
		for stat_key_value: Variant in pair:
			var stat_key: String = str(stat_key_value)
			ev_row.add_child(_make_live_ev_input(stat_key, int(evs.get(stat_key, 0))))

	_update_live_ev_total()
	is_syncing_assumption_controls = false
	if live_ev_focus_stat != "":
		call_deferred("_restore_live_ev_input_focus")


func _make_live_ev_input(stat_key: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 5)

	var label := _make_label(_get_ev_display_name(stat_key), 10, TEXT_MUTED)
	label.custom_minimum_size = Vector2(30, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var input := SpinBox.new()
	input.min_value = 0
	input.max_value = 252
	input.step = 4
	input.value = clampi(value, 0, 252)
	input.custom_minimum_size = Vector2(58, 24)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.allow_greater = false
	input.allow_lesser = false
	input.rounded = true
	input.add_theme_font_size_override("font_size", 11)
	input.value_changed.connect(_on_live_ev_changed.bind(stat_key))
	var line_edit: LineEdit = input.get_line_edit()
	if line_edit != null:
		line_edit.text_changed.connect(_on_live_ev_text_changed.bind(stat_key))
	live_ev_spinboxes[stat_key] = input
	row.add_child(input)
	return row


func _make_small_button(text: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_SECONDARY)
	button.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 4, 5.0, 2.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), CHIP_BORDER.lightened(0.12), 4, 5.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, CHIP_BORDER.lightened(0.18), 4, 5.0, 2.0))
	button.pressed.connect(pressed_callback)
	return button


func _on_live_nature_selected(index: int, dropdown: OptionButton) -> void:
	if is_syncing_assumption_controls:
		return
	defender_assumptions["nature"] = dropdown.get_item_text(index)
	edited_assumption_fields["nature"] = true
	_emit_defender_assumptions_changed()


func _on_live_ev_changed(value: float, stat_key: String) -> void:
	if is_syncing_assumption_controls:
		return
	_remember_live_ev_input_focus(stat_key)
	_apply_live_ev_value(stat_key, int(round(value)), true)


func _on_live_ev_text_changed(text: String, stat_key: String) -> void:
	if is_syncing_assumption_controls:
		return
	_remember_live_ev_input_focus(stat_key)
	var stripped_text: String = text.strip_edges()
	var parsed_value: int = 0
	if stripped_text != "":
		if not stripped_text.is_valid_int():
			return
		parsed_value = int(stripped_text)
	_apply_live_ev_value(stat_key, parsed_value, false)


func _apply_live_ev_value(stat_key: String, raw_value: int, sync_spinbox_value: bool) -> void:
	var evs: Dictionary = _as_dictionary(defender_assumptions.get("evs", {})).duplicate(true)
	var other_total: int = 0
	for other_stat: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if other_stat == stat_key:
			continue
		other_total += clampi(int(evs.get(other_stat, 0)), 0, 252)

	var remaining_budget: int = maxi(EV_TOTAL_LIMIT - other_total, 0)
	var clamped_value: int = mini(clampi(raw_value, 0, 252), remaining_budget)
	var spinbox: SpinBox = live_ev_spinboxes.get(stat_key) as SpinBox
	if sync_spinbox_value and spinbox != null and not is_equal_approx(spinbox.value, float(clamped_value)):
		spinbox.value = clamped_value

	if clamped_value <= 0:
		evs.erase(stat_key)
	else:
		evs[stat_key] = clamped_value
	defender_assumptions["evs"] = evs
	edited_assumption_fields["evs"] = true
	_update_live_ev_total()
	_queue_defender_assumptions_changed()


func _remember_live_ev_input_focus(stat_key: String) -> void:
	live_ev_focus_stat = stat_key
	live_ev_focus_caret = -1
	var spinbox: SpinBox = live_ev_spinboxes.get(stat_key) as SpinBox
	if spinbox == null:
		return
	var line_edit: LineEdit = spinbox.get_line_edit()
	if line_edit != null:
		live_ev_focus_caret = line_edit.caret_column


func _restore_live_ev_input_focus() -> void:
	if live_ev_focus_stat == "":
		return
	var spinbox: SpinBox = live_ev_spinboxes.get(live_ev_focus_stat) as SpinBox
	if spinbox == null:
		return
	var line_edit: LineEdit = spinbox.get_line_edit()
	if line_edit == null:
		spinbox.grab_focus()
		return
	line_edit.grab_focus()
	if live_ev_focus_caret >= 0:
		line_edit.caret_column = mini(live_ev_focus_caret, line_edit.text.length())


func _update_live_ev_total() -> void:
	if live_ev_total_label == null:
		return

	var total: int = 0
	var evs: Dictionary = _as_dictionary(defender_assumptions.get("evs", {}))
	for stat_key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		total += clampi(int(evs.get(stat_key, 0)), 0, 252)

	live_ev_total_label.text = "%d / %d" % [total, EV_TOTAL_LIMIT]
	live_ev_total_label.add_theme_color_override("font_color", TEXT_ERROR if total > EV_TOTAL_LIMIT else TEXT_MUTED)


func _reset_live_assumptions() -> void:
	defender_assumptions.clear()
	edited_assumption_fields.clear()
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	_emit_defender_assumptions_changed()
	_render_current_state()


func _queue_defender_assumptions_changed() -> void:
	if assumption_change_timer == null:
		_emit_defender_assumptions_changed()
		return
	assumption_change_timer.start()


func _emit_defender_assumptions_changed() -> void:
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	defender_assumptions_changed.emit(_duplicate_dictionary(defender_assumptions), _duplicate_dictionary(edited_assumption_fields))


func _get_ev_display_name(stat_key: String) -> String:
	match stat_key:
		"hp":
			return "HP"
		"atk":
			return "Atk"
		"def":
			return "Def"
		"spa":
			return "SpA"
		"spd":
			return "SpD"
		"spe":
			return "Spe"
		_:
			return stat_key.to_upper()


func _make_stylebox(
	bg_color: Color,
	border_color: Color,
	radius: int,
	horizontal_margin: float = 6.0,
	vertical_margin: float = 4.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_bottom = vertical_margin
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _get_pokemon_label(value: Variant, fallback: String) -> String:
	if not (value is Dictionary):
		return fallback

	var pokemon: Dictionary = value as Dictionary
	for key: String in ["displayName", "name", "species"]:
		var text := str(pokemon.get(key, "")).strip_edges()
		if text != "":
			return text
	return fallback


func _get_hp_label(pokemon: Dictionary) -> String:
	var hp := _as_dictionary(pokemon.get("hp", {}))
	var display := str(hp.get("display", "")).strip_edges()
	if display != "":
		return "HP %s" % display

	var percent_value: Variant = _get_percent_number(hp.get("percent"))
	if percent_value != null:
		return "HP %s%%" % _format_percent_value(percent_value)
	return "HP ?"


func _get_level_label(pokemon: Dictionary) -> String:
	var level := str(pokemon.get("level", "")).strip_edges()
	return "Lv %s" % level if level != "" else "Lv ?"


func _get_move_name(result: Dictionary) -> String:
	for key: String in ["moveName", "name"]:
		var text := str(result.get(key, "")).strip_edges()
		if text != "":
			return text

	var move_value: Variant = result.get("move", {})
	if move_value is Dictionary:
		var move: Dictionary = move_value as Dictionary
		for key: String in ["name", "move", "id"]:
			var text := str(move.get(key, "")).strip_edges()
			if text != "":
				return text
	return ""


func _get_move_meta(result: Dictionary) -> String:
	var move_value: Variant = result.get("move", {})
	var move: Dictionary = {}
	if move_value is Dictionary:
		move = move_value as Dictionary
	var move_type := _first_non_empty_string(result, move, ["moveType", "type"])
	var category := _first_non_empty_string(result, move, ["moveCategory", "category"])
	var parts := []
	if move_type != "":
		parts.append(move_type)
	if category != "":
		parts.append(category)
	return _join_string_array(parts, " / ")


func _get_percent_label(result: Dictionary) -> String:
	for key: String in ["shortLabel", "compactPercentLabel", "percentLabel", "damagePercentLabel"]:
		var text := str(result.get(key, "")).strip_edges()
		if text != "":
			return text

	if result.has("minPercent") and result.has("maxPercent"):
		if _has_suspicious_percent_values(result):
			push_warning(
				"Damage Calc received suspicious percent range for %s: min=%s max=%s" % [
					_fallback_text(_get_move_name(result), "unknown move"),
					str(result.get("minPercent")),
					str(result.get("maxPercent")),
				]
			)
			return "Calc issue"
		return "%s-%s%%" % [
			_format_percent_value(result.get("minPercent")),
			_format_percent_value(result.get("maxPercent")),
		]
	return ""


func _get_primary_result_label(result: Dictionary, defender: Dictionary) -> String:
	if _is_status_result(result):
		return "Status"

	var hp_percent_value: Variant = _get_defender_hp_percent(defender)
	var min_percent_value: Variant = _get_percent_number(result.get("minPercent"))
	var max_percent_value: Variant = _get_percent_number(result.get("maxPercent"))
	if hp_percent_value != null and min_percent_value != null and max_percent_value != null:
		var hp_percent := float(hp_percent_value)
		var min_percent := float(min_percent_value)
		var max_percent := float(max_percent_value)
		if hp_percent > 0.0 and min_percent >= 0.0 and max_percent >= 0.0 and max_percent <= SUSPICIOUS_PERCENT_LIMIT:
			if min_percent >= hp_percent:
				return "OHKO"
			if max_percent >= hp_percent:
				return "Possible OHKO"
			if max_percent > 0.0:
				var best_hits := int(ceil(hp_percent / max_percent))
				var worst_hits := best_hits
				if min_percent > 0.0:
					worst_hits = int(ceil(hp_percent / min_percent))
				if best_hits >= 5:
					return "No KO"
				if best_hits == worst_hits:
					return "%dHKO" % best_hits
				return "%d-%dHKO" % [best_hits, worst_hits]

	var hko_label := _get_hko_label(result)
	return hko_label


func _get_hko_label(result: Dictionary) -> String:
	for key: String in ["compactHkoLabel", "hkoLabel", "hitsToKoLabel", "koChanceLabel"]:
		var text := str(result.get(key, "")).strip_edges()
		if text != "":
			return text
	if result.has("hitsToKo"):
		return str(result.get("hitsToKo"))
	return ""


func _is_status_result(result: Dictionary) -> bool:
	var meta := _get_move_meta(result).to_lower()
	if meta.contains("status"):
		return true
	var percent_label := _get_percent_label(result)
	return percent_label == "--"


func _get_named_assumption_label(assumptions: Dictionary, key: String, fallback: String) -> String:
	var value := str(assumptions.get(key, "")).strip_edges()
	return fallback if value == "" or value == "<null>" else value


func _get_display_assumptions(defender: Dictionary) -> Dictionary:
	var assumptions := _as_dictionary(defender.get("assumptions", {})).duplicate(true)
	for key: Variant in defender_assumptions.keys():
		assumptions[key] = defender_assumptions[key]
	if not assumptions.has("nature") or str(assumptions.get("nature", "")).strip_edges() == "":
		assumptions["nature"] = "Hardy"
	if not assumptions.has("evs"):
		assumptions["evs"] = {}
	if not assumptions.has("ivs"):
		assumptions["ivs"] = {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}
	return assumptions


func _get_nature_chip_label(assumptions: Dictionary) -> String:
	var label := _fallback_text(str(assumptions.get("nature", "")).strip_edges(), "Hardy")
	return "%s*" % label if bool(edited_assumption_fields.get("nature", false)) else label


func _get_evs_chip_label(evs: Dictionary) -> String:
	var label := _get_evs_label(evs)
	return "%s*" % label if bool(edited_assumption_fields.get("evs", false)) else label


func _get_assumptions_summary_label(assumptions: Dictionary) -> String:
	var parts: Array[String] = [
		_get_named_assumption_label(assumptions, "item", "Item ?"),
		_get_named_assumption_label(assumptions, "ability", "Ability ?"),
		_get_nature_chip_label(assumptions),
		_get_evs_chip_label(_as_dictionary(assumptions.get("evs", {}))),
		_get_ivs_label(_as_dictionary(assumptions.get("ivs", {}))),
	]
	return "Assumptions: %s" % ", ".join(parts)


func _get_evs_label(evs: Dictionary) -> String:
	if evs.is_empty():
		return "EVs 0"

	for preset_value: Variant in EV_PRESETS:
		var preset := preset_value as Dictionary
		var preset_evs := _as_dictionary(preset.get("evs", {}))
		if _evs_equal(evs, preset_evs):
			return str(preset.get("chip", "EVs custom"))

	var total := 0
	for value: Variant in evs.values():
		var number_value: Variant = _get_percent_number(value)
		if number_value != null:
			total += int(number_value)
	return "EVs %d" % total if total > 0 else "EVs 0"


func _get_ivs_label(ivs: Dictionary) -> String:
	if ivs.is_empty():
		return "IVs 31"

	var values := []
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if ivs.has(key):
			values.append(int(ivs.get(key)))
	if values.is_empty():
		return "IVs 31"

	var first_value := int(values[0])
	for value: Variant in values:
		if int(value) != first_value:
			return "IVs custom"
	return "IVs %d" % first_value


func _evs_equal(left: Dictionary, right: Dictionary) -> bool:
	var stat_keys := ["hp", "atk", "def", "spa", "spd", "spe"]
	for key: String in stat_keys:
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _get_defender_hp_percent(defender: Dictionary) -> Variant:
	var hp := _as_dictionary(defender.get("hp", {}))
	return _get_percent_number(hp.get("percent"))


func _format_percent_value(value: Variant) -> String:
	var number_value: Variant = _get_percent_number(value)
	if number_value == null:
		return "--"

	var number := float(number_value)
	if is_equal_approx(number, round(number)):
		return str(int(round(number)))
	return "%.1f" % number


func _has_suspicious_percent_values(result: Dictionary) -> bool:
	var min_percent_value: Variant = _get_percent_number(result.get("minPercent"))
	var max_percent_value: Variant = _get_percent_number(result.get("maxPercent"))
	if min_percent_value == null:
		return true
	if max_percent_value == null:
		return true

	var min_percent := float(min_percent_value)
	var max_percent := float(max_percent_value)
	return min_percent < 0.0 or max_percent < 0.0 or min_percent > SUSPICIOUS_PERCENT_LIMIT or max_percent > SUSPICIOUS_PERCENT_LIMIT


func _get_percent_number(value: Variant) -> Variant:
	var number := 0.0
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		number = float(value)
	elif typeof(value) == TYPE_STRING and str(value).strip_edges().is_valid_float():
		number = float(str(value).strip_edges())
	else:
		return null

	if is_nan(number) or is_inf(number):
		return null
	return number


func _first_non_empty_string(primary: Dictionary, secondary: Dictionary, keys: Array) -> String:
	for key: String in keys:
		var text := str(primary.get(key, "")).strip_edges()
		if text != "":
			return text
	for key: String in keys:
		var text := str(secondary.get(key, "")).strip_edges()
		if text != "":
			return text
	return ""


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return value.duplicate(true)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []


func _join_string_array(values: Array, separator: String) -> String:
	var parts: Array[String] = []
	for value: Variant in values:
		var text := str(value).strip_edges()
		if text != "":
			parts.append(text)
	return separator.join(parts)


func _fallback_text(value: String, fallback: String) -> String:
	var text := value.strip_edges()
	return fallback if text == "" else text
