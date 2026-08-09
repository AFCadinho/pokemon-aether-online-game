extends MarginContainer

class_name BattleDamageCalcPanel

const CALCDEX_SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
signal defender_assumptions_changed(assumptions: Dictionary, edited_fields: Dictionary)
signal assumption_catalog_requested(kind: String, query: String, species: String)
signal matchup_selection_changed()

const TEXT_PRIMARY := Color(0.95686275, 0.94509804, 0.91764706, 1.0)
const TEXT_SECONDARY := Color(0.72156864, 0.72156864, 0.72156864, 1.0)
const TEXT_MUTED := Color(0.56, 0.6, 0.68, 1.0)
const TEXT_ACCENT := Color(0.84705883, 0.7058824, 0.41568628, 1.0)
const TEXT_ERROR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const ROW_BG := Color(0.014, 0.021, 0.036, 0.98)
const ROW_BORDER := Color(0.14, 0.26, 0.42, 0.76)
const PROFILE_BG := Color(0.021, 0.033, 0.058, 0.95)
const PROFILE_BORDER := Color(0.18, 0.31, 0.49, 0.74)
const HERO_BG := Color(0.018, 0.047, 0.078, 0.98)
const HERO_BORDER := Color(0.16, 0.48, 0.70, 0.92)
const CHIP_BG := Color(0.028, 0.043, 0.073, 0.96)
const CHIP_BORDER := Color(0.2, 0.34, 0.52, 0.82)
const CHIP_EDITED_BORDER := Color(0.62, 0.48, 0.23, 0.9)
const CHIP_PUBLIC_BORDER := Color(0.25, 0.39, 0.58, 0.9)
const KO_BG := Color(0.13, 0.094, 0.032, 0.95)
const KO_BORDER := Color(0.72, 0.55, 0.23, 0.88)
const TAB_BG := Color(0.024, 0.036, 0.062, 0.92)
const TAB_ACTIVE_BG := Color(0.124, 0.203, 0.332, 0.98)
const TAB_BORDER := Color(0.19, 0.31, 0.48, 0.9)
const SUSPICIOUS_PERCENT_LIMIT := 999.0
const DAMAGE_COLUMN_WIDTH := 132.0
const KO_COLUMN_WIDTH := 92.0
const SUBTAB_YOUR_DAMAGE := "your"
const SUBTAB_THEIR_DAMAGE := "their"
const SELECTOR_NONE := ""
const SELECTOR_ITEM := "item"
const SELECTOR_ABILITY := "ability"
const SELECTOR_NATURE := "nature"
const SELECTOR_EVS := "evs"
const EV_TOTAL_LIMIT := 508
const ASSUMPTION_CHANGE_DEBOUNCE_SECONDS := 0.35
const CATALOG_SEARCH_DEBOUNCE_SECONDS := 0.3
const FALLBACK_NATURE_OPTIONS := ["Hardy", "Adamant", "Modest", "Jolly", "Timid", "Bold", "Calm", "Impish", "Careful"]
const EV_PRESETS := [
	{"label": "EVs 0", "chip": "EVs 0", "evs": {}},
	{"label": "252 HP", "chip": "EVs HP", "evs": {"hp": 252}},
	{"label": "252 Def", "chip": "EVs Def", "evs": {"def": 252}},
	{"label": "252 SpD", "chip": "EVs SpD", "evs": {"spd": 252}},
	{"label": "252 HP / 252 Def", "chip": "EVs HP/Def", "evs": {"hp": 252, "def": 252}},
	{"label": "252 HP / 252 SpD", "chip": "EVs HP/SpD", "evs": {"hp": 252, "spd": 252}},
]
const EV_INPUT_ROWS := [["hp", "atk"], ["def", "spa"], ["spd", "spe"]]

var content: VBoxContainer

var active_subtab := SUBTAB_YOUR_DAMAGE
var is_loading := false
var loading_attacker_name := ""
var loading_defender_name := ""
var last_response: Dictionary = {}
var last_error := ""
var defender_assumptions: Dictionary = {}
var edited_assumption_fields: Dictionary = {}
var knowledge_snapshot: Dictionary = {}
var live_ev_inputs: Dictionary = {}
var live_ev_total_label: Label
var live_ev_focus_stat := ""
var live_ev_focus_caret := -1
var item_assumption_input: LineEdit
var ability_assumption_input: LineEdit
var catalog_suggestions_box: VBoxContainer
var catalog_results_box: VBoxContainer
var assumption_change_timer: Timer
var catalog_search_timer: Timer
var active_selector: String = SELECTOR_NONE
var selector_query: String = ""
var selector_results: Array = []
var selector_loading: bool = false
var selector_error: String = ""
var nature_catalog_options: Array = []
var is_syncing_assumption_controls := false
var localization_manager: Node
var selected_viewer_ref := ""
var selected_opponent_ref := ""
var field_scenario: Dictionary = {}
var smart_range_mode := "likely"
var pinned_candidate_id := ""
var use_observation_inference := false
var advanced_scenario_expanded := false
var warning_details_expanded := false


func _ready() -> void:
	content = get_node_or_null("CalcScroll/VBoxContainer") as VBoxContainer
	if content == null:
		content = get_node_or_null("VBoxContainer") as VBoxContainer
	if content == null:
		push_error("BattleDamageCalcPanel requires a VBoxContainer content node")
		return
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	clip_contents = true
	content.clip_contents = true
	content.add_theme_constant_override("separation", 5)
	assumption_change_timer = Timer.new()
	assumption_change_timer.one_shot = true
	assumption_change_timer.wait_time = ASSUMPTION_CHANGE_DEBOUNCE_SECONDS
	assumption_change_timer.timeout.connect(_emit_defender_assumptions_changed)
	add_child(assumption_change_timer)
	catalog_search_timer = Timer.new()
	catalog_search_timer.one_shot = true
	catalog_search_timer.wait_time = CATALOG_SEARCH_DEBOUNCE_SECONDS
	catalog_search_timer.timeout.connect(_request_active_catalog)
	add_child(catalog_search_timer)


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
	if _is_catalog_search_active():
		return
	_render_current_state()


func show_error(message: String) -> void:
	close_assumption_popover()
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_response = {}
	last_error = _fallback_text(message, _t("battle.calc.error.failed"))
	_render_current_state()


func show_response(response: Dictionary) -> void:
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_error = ""

	if not bool(response.get("success", false)):
		last_response = {}
		last_error = str(response.get("error", _t("battle.calc.error.failed")))
	else:
		last_response = response

	if _is_catalog_search_active():
		return
	_render_current_state()


func set_defender_assumptions(assumptions: Dictionary, edited_fields: Dictionary = {}) -> void:
	defender_assumptions = _duplicate_dictionary(assumptions)
	edited_assumption_fields = _duplicate_dictionary(edited_fields)
	if _is_catalog_search_active():
		return
	if is_inside_tree():
		_render_current_state()


func set_knowledge_snapshot(snapshot: Dictionary) -> void:
	knowledge_snapshot = snapshot.duplicate(true)
	selected_viewer_ref = _resolve_selected_ref("viewer", selected_viewer_ref)
	selected_opponent_ref = _resolve_selected_ref("opponent", selected_opponent_ref)
	if _is_catalog_search_active():
		return
	if is_inside_tree():
		_render_current_state()


func close_assumption_popover() -> void:
	_flush_pending_assumption_changes()
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	live_ev_inputs.clear()
	live_ev_total_label = null
	live_ev_focus_stat = ""
	live_ev_focus_caret = -1
	item_assumption_input = null
	ability_assumption_input = null
	catalog_suggestions_box = null
	catalog_results_box = null
	active_selector = SELECTOR_NONE
	selector_query = ""
	selector_results = []
	selector_loading = false
	selector_error = ""


func _flush_pending_assumption_changes() -> void:
	if assumption_change_timer == null or assumption_change_timer.is_stopped():
		return
	var evs: Dictionary = _as_dictionary(defender_assumptions.get("evs", {}))
	if _get_evs_total(evs) > EV_TOTAL_LIMIT:
		assumption_change_timer.stop()
		return
	_emit_defender_assumptions_changed()


func _render_current_state() -> void:
	_clear_content()
	_add_subtabs()
	_add_smart_range_controls()

	if not last_response.is_empty():
		_render_your_damage_response(last_response)
		return

	if is_loading:
		_add_profile_summary(
			_fallback_text(loading_attacker_name, _t("battle.calc.your_pokemon")),
			_fallback_text(loading_defender_name, _t("battle.calc.opponent")),
			_t("battle.calc.hp_unknown"),
			_t("battle.calc.level_unknown")
		)
		_add_status(_t("battle.calc.calculating"), TEXT_SECONDARY)
		return

	if last_error != "":
		_add_profile_summary(_t("battle.calc.your_pokemon"), _t("battle.calc.opponent"), _t("battle.calc.hp_unknown"), _t("battle.calc.level_unknown"))
		_add_status(last_error, TEXT_ERROR)
		return

	if last_response.is_empty():
		_add_profile_summary(_t("battle.calc.your_pokemon"), _t("battle.calc.opponent"), _t("battle.calc.hp_unknown"), _t("battle.calc.level_unknown"))
		_add_status(_t("battle.calc.open_to_load"), TEXT_SECONDARY)
		return

	_render_your_damage_response(last_response)


func _is_catalog_search_active() -> bool:
	return (
		catalog_suggestions_box != null
		and (active_selector == SELECTOR_ITEM or active_selector == SELECTOR_ABILITY)
	)


func _render_your_damage_response(response: Dictionary) -> void:
	var attacker: Dictionary = _as_dictionary(response.get("attacker", {}))
	var defender: Dictionary = _as_dictionary(response.get("defender", {}))
	_add_profile_summary(
		_get_pokemon_label(attacker, _t("battle.calc.your_pokemon")),
		_get_pokemon_label(defender, _t("battle.calc.opponent")),
		_get_hp_label(defender),
		_get_level_label(defender),
		_get_boosts_label(attacker),
		_get_hp_label(attacker),
		_get_level_label(attacker)
	)
	_add_assumption_chips(attacker if str(attacker.get("relation", "")) == "opponent" else defender, response)
	_add_candidate_summary(response)

	var results: Array = _as_array(response.get("results", []))
	if results.is_empty():
		_add_status(_fallback_text(str(response.get("emptyReason", "")), _t("battle.calc.no_results")), TEXT_SECONDARY)
		return

	_add_move_results_table(results, defender)
	_add_result_footnotes(response, results)


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

	row.add_child(_make_subtab_button(_t("battle.calc.your_damage"), SUBTAB_YOUR_DAMAGE))
	row.add_child(_make_subtab_button(_t("battle.calc.their_damage"), SUBTAB_THEIR_DAMAGE))


func _make_subtab_button(text: String, tab_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT_PRIMARY if active_subtab == tab_id else TEXT_SECONDARY)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if active_subtab == tab_id else TAB_BG, TAB_BORDER, 4, 5.0, 1.0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(TAB_ACTIVE_BG.lightened(0.08), TAB_BORDER.lightened(0.1), 4, 5.0, 1.0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(TAB_ACTIVE_BG, TAB_BORDER.lightened(0.18), 4, 5.0, 1.0)
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
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _on_their_damage_tab_pressed() -> void:
	if active_subtab == SUBTAB_THEIR_DAMAGE:
		return
	close_assumption_popover()
	active_subtab = SUBTAB_THEIR_DAMAGE
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func get_matchup_selection() -> Dictionary:
	return {
		"direction": "opponent-to-own" if active_subtab == SUBTAB_THEIR_DAMAGE else "own-to-opponent",
		"attackerRef": selected_opponent_ref if active_subtab == SUBTAB_THEIR_DAMAGE else selected_viewer_ref,
		"defenderRef": selected_viewer_ref if active_subtab == SUBTAB_THEIR_DAMAGE else selected_opponent_ref,
	}


func get_field_scenario() -> Dictionary:
	return field_scenario.duplicate(true)


func get_smart_options() -> Dictionary:
	return {
		"rangeMode": smart_range_mode,
		"pinnedCandidateId": pinned_candidate_id,
		"useObservationInference": use_observation_inference,
	}


func _add_smart_range_controls() -> void:
	if knowledge_snapshot.is_empty():
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	for mode: String in ["likely", "full"]:
		var button := _make_small_button(
			_t("battle.calc.range_%s" % mode),
			_on_smart_range_pressed.bind(mode)
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = smart_range_mode == mode
		row.add_child(button)
	var inference_button := _make_small_button(
		_t("battle.calc.inference_use" if use_observation_inference else "battle.calc.inference_ignore"),
		_on_inference_toggle_pressed
	)
	inference_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inference_button.toggle_mode = true
	inference_button.button_pressed = use_observation_inference
	inference_button.tooltip_text = _t("battle.calc.inference_tooltip")
	row.add_child(inference_button)


func _on_smart_range_pressed(mode: String) -> void:
	if mode == smart_range_mode:
		return
	smart_range_mode = mode
	last_response = {}
	matchup_selection_changed.emit()


func _on_inference_toggle_pressed() -> void:
	use_observation_inference = not use_observation_inference
	last_response = {}
	matchup_selection_changed.emit()


func _add_candidate_summary(response: Dictionary) -> void:
	var candidates: Array = _as_array(response.get("candidates", []))
	if candidates.is_empty():
		return
	var title := _make_label(_t("battle.calc.candidate_estimates"), 10, TEXT_MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	for explanation_value: Variant in _as_array(response.get("inferenceExplanationKeys", [])):
		var explanation_key := str(explanation_value)
		var explanation := _t(explanation_key)
		if explanation != explanation_key:
			_add_status(explanation, TEXT_MUTED)
	for candidate_value: Variant in candidates:
		var candidate := _as_dictionary(candidate_value)
		var candidate_id := str(candidate.get("candidateId", ""))
		var label_key := str(candidate.get("labelKey", ""))
		var label := _t(label_key)
		if label == label_key:
			label = candidate_id
		var effective := _as_dictionary(candidate.get("effectiveInput", {}))
		var details: Array[String] = []
		for key: String in ["nature", "item", "ability"]:
			var value := str(effective.get(key, "")).strip_edges()
			if value != "":
				details.append(value)
		var weight_percent := roundi(float(candidate.get("weight", 0.0)) * 100.0)
		var text := _t("battle.calc.candidate_estimate", {
			"label": label,
			"weight": weight_percent,
			"details": _join_string_array(details, " · "),
		})
		var button := _make_small_button(text, _on_candidate_pin_pressed.bind(candidate_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = _t("battle.calc.candidate_not_confirmed")
		button.button_pressed = bool(candidate.get("pinned", false))
		content.add_child(button)


func _on_candidate_pin_pressed(candidate_id: String) -> void:
	pinned_candidate_id = "" if pinned_candidate_id == candidate_id else candidate_id
	last_response = {}
	matchup_selection_changed.emit()


func _make_pokemon_selector(relation: String, is_attacker: bool) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = _t("battle.calc.attacker_selector" if is_attacker else "battle.calc.defender_selector")
	var collection: Array = _as_array(knowledge_snapshot.get("viewerPokemon" if relation == "viewer" else "opponentPokemon", []))
	var selected_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	for entry_value: Variant in collection:
		var entry := _as_dictionary(entry_value)
		if entry.is_empty() or bool(entry.get("fainted", false)):
			continue
		var pokemon_ref := str(entry.get("pokemonRef", ""))
		selector.add_item(_snapshot_pokemon_name(entry))
		selector.set_item_metadata(selector.item_count - 1, pokemon_ref)
		if pokemon_ref == selected_ref:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_pokemon_selected.bind(selector, relation))
	return selector


func _on_pokemon_selected(index: int, selector: OptionButton, relation: String) -> void:
	var pokemon_ref := str(selector.get_item_metadata(index))
	if relation == "viewer":
		selected_viewer_ref = pokemon_ref
	else:
		selected_opponent_ref = pokemon_ref
	last_response = {}
	matchup_selection_changed.emit()


func _resolve_selected_ref(relation: String, current_ref: String) -> String:
	var collection: Array = _as_array(knowledge_snapshot.get("viewerPokemon" if relation == "viewer" else "opponentPokemon", []))
	var fallback := ""
	for entry_value: Variant in collection:
		var entry := _as_dictionary(entry_value)
		if entry.is_empty() or bool(entry.get("fainted", false)):
			continue
		var pokemon_ref := str(entry.get("pokemonRef", ""))
		if pokemon_ref == current_ref:
			return current_ref
		if bool(entry.get("active", false)):
			fallback = pokemon_ref
		elif fallback == "":
			fallback = pokemon_ref
	return fallback


func _snapshot_pokemon_name(entry: Dictionary) -> String:
	var identity := _as_dictionary(entry.get("identity", {}))
	var name := str(identity.get("value", "")).strip_edges()
	return _fallback_text(name, _t("battle.move.unknown"))


func _add_profile_summary(
	attacker_name: String,
	defender_name: String,
	hp_label: String,
	level_label: String,
	boosts_label: String = "",
	attacker_hp_label: String = "",
	attacker_level_label: String = ""
) -> void:
	var matchup_row := HBoxContainer.new()
	matchup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	matchup_row.add_theme_constant_override("separation", 6)
	content.add_child(matchup_row)
	var attacker_relation := "opponent" if active_subtab == SUBTAB_THEIR_DAMAGE else "viewer"
	var defender_relation := "viewer" if active_subtab == SUBTAB_THEIR_DAMAGE else "opponent"
	var attacker_details: Array[String] = []
	if attacker_hp_label.strip_edges() != "":
		attacker_details.append(attacker_hp_label)
	attacker_details.append(_fallback_text(attacker_level_label, _t("battle.calc.level_unknown")))
	if boosts_label.strip_edges() != "":
		attacker_details.append(boosts_label)
	matchup_row.add_child(_make_matchup_side(
		_t("battle.calc.attacker"),
		_fallback_text(attacker_name, _t("battle.calc.your_pokemon")),
		attacker_relation,
		_join_string_array(attacker_details, "  ·  "),
		true
	))
	var arrow := _make_label("VS", 10, TEXT_ACCENT)
	arrow.custom_minimum_size = Vector2(30, 0)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	matchup_row.add_child(arrow)
	matchup_row.add_child(_make_matchup_side(
		_t("battle.calc.target"),
		_fallback_text(defender_name, _t("battle.calc.opponent")),
		defender_relation,
		"%s  ·  %s" % [
			_fallback_text(hp_label, _t("battle.calc.hp_unknown")),
			_fallback_text(level_label, _t("battle.calc.level_unknown")),
		],
		false
	))


func _make_matchup_side(caption: String, pokemon_name: String, relation: String, details: String, is_attacker: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(HERO_BG, HERO_BORDER, 7, 8.0, 6.0))
	var side := VBoxContainer.new()
	side.clip_contents = true
	side.add_theme_constant_override("separation", 2)
	panel.add_child(side)
	var caption_label := _make_label(caption.to_upper(), 9, TEXT_MUTED)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(caption_label)
	if knowledge_snapshot.is_empty():
		var name_label := _make_label(pokemon_name, 14, TEXT_PRIMARY)
		name_label.tooltip_text = pokemon_name
		side.add_child(name_label)
	else:
		var selector := _make_pokemon_selector(relation, is_attacker)
		selector.custom_minimum_size = Vector2(0, 26)
		selector.add_theme_font_size_override("font_size", 13)
		side.add_child(selector)
	var detail_label := _make_label(details, 9, TEXT_SECONDARY)
	detail_label.tooltip_text = details
	side.add_child(detail_label)
	return panel


func _add_status(text: String, color: Color) -> void:
	var label := _make_label(text, 13, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)


func _add_assumption_chips(defender: Dictionary, _response: Dictionary) -> void:
	_add_public_fact_chips()
	var assumptions := _get_display_assumptions(defender)
	_add_live_assumption_controls(assumptions)


func _add_public_fact_chips() -> void:
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	if opponent.is_empty():
		return
	var facts: Array[String] = []
	for field_name: String in ["item", "ability"]:
		var knowledge := CALCDEX_SNAPSHOT.get_knowledge_value(opponent, field_name)
		if str(knowledge.get("state", "")) != "known":
			continue
		var value := str(knowledge.get("value", "")).strip_edges()
		if value == "":
			continue
		facts.append(_t("battle.calc.fact_with_provenance", {
			"field": _t("battle.calc.%s" % field_name),
			"value": value,
			"provenance": _get_provenance_label(knowledge),
		}))
	var boosts := CALCDEX_SNAPSHOT.get_knowledge_value(opponent, "boosts")
	var boost_values := _as_dictionary(boosts.get("value", {}))
	if str(boosts.get("state", "")) == "known" and not boost_values.is_empty():
		facts.append(_t("battle.calc.fact_with_provenance", {
			"field": _t("battle.calc.boosts_field"),
			"value": _get_boosts_text(boost_values),
			"provenance": _get_provenance_label(boosts),
		}))
	if facts.is_empty():
		return
	var title := _make_label(_t("battle.calc.public_facts"), 10, TEXT_MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	for fact: String in facts:
		var chip := _make_chip(fact)
		chip.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_PUBLIC_BORDER, 4, 5.0, 2.0))
		content.add_child(chip)


func _get_snapshot_pokemon_by_ref(pokemon_ref: String) -> Dictionary:
	for collection_key: String in ["viewerPokemon", "opponentPokemon"]:
		for entry_value: Variant in _as_array(knowledge_snapshot.get(collection_key, [])):
			var entry := _as_dictionary(entry_value)
			if str(entry.get("pokemonRef", "")) == pokemon_ref:
				return entry
	return {}


func _get_provenance_label(knowledge: Dictionary) -> String:
	var provenance := _as_dictionary(knowledge.get("provenance", {}))
	var source := str(provenance.get("source", "unknown"))
	return _t("battle.calc.provenance.%s" % source)


func _add_move_results_table(results: Array, defender: Dictionary) -> void:
	var table := PanelContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.clip_contents = true
	table.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 8, 5.0, 5.0))
	content.add_child(table)
	var table_box := VBoxContainer.new()
	table_box.clip_contents = true
	table_box.add_theme_constant_override("separation", 3)
	table.add_child(table_box)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	table_box.add_child(header)
	var move_header := _make_table_header(_t("battle.calc.move_header"))
	move_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(move_header)
	var damage_header := _make_table_header(_t("battle.calc.damage_header"))
	damage_header.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	damage_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	damage_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(damage_header)
	var ko_header := _make_table_header(_t("battle.calc.ko_header"))
	ko_header.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 0)
	ko_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	ko_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(ko_header)
	for result_value: Variant in results:
		if result_value is Dictionary:
			_add_move_result_row(result_value as Dictionary, defender, table_box)


func _make_table_header(text: String) -> Label:
	var label := _make_label(text.to_upper(), 9, TEXT_MUTED)
	label.custom_minimum_size = Vector2(0, 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _add_move_result_row(result: Dictionary, defender: Dictionary, parent: VBoxContainer) -> void:
	var primary_result_label := _get_primary_result_label(result, defender)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(ROW_BG, _get_result_border(primary_result_label), 5, 7.0, 4.0))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var result_row := HBoxContainer.new()
	result_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_row.clip_contents = true
	result_row.add_theme_constant_override("separation", 6)
	box.add_child(result_row)

	var move_box := VBoxContainer.new()
	move_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_box.clip_contents = true
	move_box.add_theme_constant_override("separation", 0)
	result_row.add_child(move_box)
	var move_name := _get_move_name(result)
	var move_label := _make_label(_fallback_text(move_name, _t("battle.move.unknown")), 12, TEXT_PRIMARY)
	move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_box.add_child(move_label)

	var is_status_move: bool = _is_status_result(result)
	var percent_label: String = "" if is_status_move else _get_percent_label(result)
	var meta := _get_move_meta(result)
	if meta != "":
		var meta_label := _make_label(meta, 9, TEXT_MUTED)
		meta_label.tooltip_text = meta
		move_box.add_child(meta_label)
	var percent := _make_label(percent_label if percent_label != "" else "--", 12, TEXT_PRIMARY)
	percent.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	percent.size_flags_horizontal = Control.SIZE_SHRINK_END
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_row.add_child(percent)
	var ko_label := _make_result_badge(primary_result_label)
	ko_label.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 22)
	ko_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	result_row.add_child(ko_label)

	var result_state := str(result.get("resultState", "supported"))
	if result_state == "unsupported":
		_add_row_notice(box, _t("battle.calc.unsupported_mechanic"), TEXT_ERROR)
	elif result_state == "partial":
		_add_row_notice(box, _t("battle.calc.partial_result"), TEXT_ACCENT)

	for warning_value: Variant in _as_array(result.get("warnings", [])) + _as_array(result.get("koWarnings", [])):
		var warning := str(warning_value).strip_edges()
		if warning != "":
			_add_row_notice(box, _warning_label(warning), TEXT_ERROR if result_state in ["unsupported", "error"] else TEXT_MUTED)

	parent.add_child(panel)


func _get_result_border(primary_result_label: String) -> Color:
	var label := primary_result_label.to_upper()
	if label == "OHKO" or label.contains("CHANCE"):
		return KO_BORDER
	if label.contains("2HKO"):
		return Color(0.28, 0.48, 0.66, 0.9)
	return ROW_BORDER


func _add_result_footnotes(response: Dictionary, results: Array) -> void:
	var excludes_end_of_turn := false
	for result_value: Variant in results:
		var result := _as_dictionary(result_value)
		var end_of_turn := _as_dictionary(result.get("endOfTurn", {}))
		if str(end_of_turn.get("state", "")) == "not_included":
			excludes_end_of_turn = true
			break
	if excludes_end_of_turn:
		var direct_note := _make_label(_t("battle.calc.end_of_turn_not_included"), 10, TEXT_MUTED)
		direct_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		direct_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		direct_note.clip_text = false
		content.add_child(direct_note)
	var details: Array[String] = []
	for warning_value: Variant in _as_array(response.get("warnings", [])):
		var warning := str(warning_value).strip_edges()
		if warning != "":
			details.append(_warning_label(warning))
	if details.is_empty():
		return
	var notes_panel := PanelContainer.new()
	notes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_panel.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 6, 7.0, 5.0))
	content.add_child(notes_panel)
	var notes_box := VBoxContainer.new()
	notes_box.add_theme_constant_override("separation", 3)
	notes_panel.add_child(notes_box)
	var summary := _make_disclosure_button(
		_t("battle.calc.notes_count", {"count": details.size()}),
		warning_details_expanded,
		_on_warning_details_pressed
	)
	notes_box.add_child(summary)
	if warning_details_expanded:
		for detail: String in details:
			var detail_label := _make_label("• %s" % detail, 10, TEXT_MUTED)
			detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_label.clip_text = false
			notes_box.add_child(detail_label)


func _on_warning_details_pressed() -> void:
	warning_details_expanded = not warning_details_expanded
	_render_current_state()


func _add_row_notice(parent: VBoxContainer, text: String, color: Color) -> void:
	var label := _make_label(text, 10, color)
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	parent.add_child(label)


func _warning_label(value: String) -> String:
	if not value.begins_with("CALC_"):
		return value
	if value.begins_with("CALC_SCENARIO_ATTACKER_") or value.begins_with("CALC_SCENARIO_DEFENDER_"):
		return _t("battle.calc.warning.field_scenario")
	var key := "battle.calc.warning.%s" % value.to_lower()
	var translated := _t(key)
	return value if translated == key else translated


func _make_chip(text: String) -> Label:
	var label := _make_label(text, 11, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(44, 20)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 4, 5.0, 2.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_result_badge(text: String) -> Label:
	var label := _make_label(_get_compact_result_label(text), 10, TEXT_ACCENT)
	label.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 20)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(KO_BG, KO_BORDER, 4, 6.0, 2.0))
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
	live_ev_inputs.clear()
	live_ev_total_label = null
	item_assumption_input = null
	ability_assumption_input = null
	catalog_results_box = null
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 5, 7.0, 5.0))
	content.add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)
	var setup_title := _make_label(_t("battle.calc.opponent_setup"), 11, TEXT_SECONDARY)
	setup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	setup_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(setup_title)
	var reset_button := _make_small_button(_t("common.reset"), _reset_live_assumptions)
	reset_button.custom_minimum_size = Vector2(48, 22)
	title_row.add_child(reset_button)

	var primary_row := HBoxContainer.new()
	primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_row.clip_contents = true
	primary_row.add_theme_constant_override("separation", 4)
	box.add_child(primary_row)

	primary_row.add_child(_make_assumption_summary_button(_get_assumption_chip_label(assumptions, "item", _t("battle.calc.item_unknown")), SELECTOR_ITEM))
	primary_row.add_child(_make_assumption_summary_button(_get_assumption_chip_label(assumptions, "ability", _t("battle.calc.ability_unknown")), SELECTOR_ABILITY))
	primary_row.add_child(_make_assumption_summary_button(_get_nature_chip_label(assumptions), SELECTOR_NATURE))
	primary_row.add_child(_make_assumption_summary_button(_get_evs_summary_chip_label(_as_dictionary(assumptions.get("evs", {}))), SELECTOR_EVS))

	catalog_suggestions_box = VBoxContainer.new()
	catalog_suggestions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_suggestions_box.clip_contents = true
	catalog_suggestions_box.add_theme_constant_override("separation", 3)
	box.add_child(catalog_suggestions_box)
	_add_advanced_scenario_controls(box, assumptions)
	_render_active_assumption_editor(assumptions)

	is_syncing_assumption_controls = false
	if live_ev_focus_stat != "":
		call_deferred("_restore_live_ev_input_focus")


func _add_advanced_scenario_controls(parent: VBoxContainer, assumptions: Dictionary) -> void:
	var active_conditions: Array[String] = []
	for key: String in ["weather", "terrain"]:
		var condition := str(field_scenario.get(key, "")).strip_edges()
		if condition != "":
			active_conditions.append(condition)
	var condition_summary := _t("common.none") if active_conditions.is_empty() else _join_string_array(active_conditions, " · ")
	parent.add_child(_make_disclosure_button(
		_t("battle.calc.battle_conditions", {"conditions": condition_summary}),
		advanced_scenario_expanded,
		_on_advanced_scenario_pressed
	))
	if not advanced_scenario_expanded:
		return
	var field_row := HBoxContainer.new()
	field_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_row.add_theme_constant_override("separation", 5)
	field_row.add_child(_make_field_scenario_selector("weather", ["", "Rain", "Sun", "Sand", "Hail", "Snow"]))
	field_row.add_child(_make_field_scenario_selector("terrain", ["", "Electric", "Grassy", "Misty", "Psychic"]))
	parent.add_child(field_row)
	if active_subtab == SUBTAB_THEIR_DAMAGE:
		var moves_input := LineEdit.new()
		moves_input.placeholder_text = _t("battle.calc.assumed_moves_placeholder")
		moves_input.text = _join_string_array(_as_array(assumptions.get("assumedMoves", [])), ", ")
		moves_input.max_length = 403
		moves_input.text_changed.connect(_on_assumed_moves_changed)
		parent.add_child(moves_input)


func _on_advanced_scenario_pressed() -> void:
	advanced_scenario_expanded = not advanced_scenario_expanded
	_render_current_state()


func _make_disclosure_button(text: String, expanded: bool, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s  %s" % ["-" if expanded else "+", text]
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 26)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_MUTED)
	button.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 4, 6.0, 2.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG, CHIP_BORDER.lightened(0.12), 4, 6.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, TEXT_ACCENT, 4, 6.0, 2.0))
	button.pressed.connect(pressed_callback)
	return button


func _make_field_scenario_selector(key: String, values: Array) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value: Variant in values:
		var normalized := str(value)
		selector.add_item(_t("common.none") if normalized == "" else normalized)
		selector.set_item_metadata(selector.item_count - 1, normalized)
		if normalized == str(field_scenario.get(key, "")):
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_field_scenario_selected.bind(selector, key))
	return selector


func _on_field_scenario_selected(index: int, selector: OptionButton, key: String) -> void:
	var value := str(selector.get_item_metadata(index))
	if value == "":
		field_scenario.erase(key)
	else:
		field_scenario[key] = value
	matchup_selection_changed.emit()


func _on_assumed_moves_changed(text: String) -> void:
	var moves: Array[String] = []
	for raw_name: String in text.split(","):
		var name := raw_name.strip_edges()
		if name != "" and name.length() <= 100 and name not in moves and moves.size() < 4:
			moves.append(name)
	if moves.is_empty():
		defender_assumptions.erase("assumedMoves")
	else:
		defender_assumptions["assumedMoves"] = moves
	edited_assumption_fields["assumedMoves"] = true
	_queue_defender_assumptions_changed()


func _make_live_ev_input(stat_key: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 2)

	var label := _make_label(_get_ev_display_name(stat_key), 10, TEXT_MUTED)
	label.custom_minimum_size = Vector2(24, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var input := LineEdit.new()
	input.text = str(clampi(value, 0, 252))
	input.placeholder_text = "0"
	input.custom_minimum_size = Vector2(36, 24)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.max_length = 3
	input.add_theme_font_size_override("font_size", 11)
	input.focus_entered.connect(_remember_live_ev_input_focus.bind(stat_key))
	input.text_changed.connect(_on_live_ev_text_changed.bind(stat_key))
	live_ev_inputs[stat_key] = input
	row.add_child(input)

	row.add_child(_make_ev_quick_button("0", _on_live_ev_quick_value_pressed.bind(stat_key, 0)))
	row.add_child(_make_ev_quick_button("252", _on_live_ev_quick_value_pressed.bind(stat_key, 252)))
	return row


func _make_ev_quick_button(text: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(28, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", TEXT_SECONDARY)
	button.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 4, 3.0, 1.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), CHIP_BORDER.lightened(0.12), 4, 3.0, 1.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, CHIP_BORDER.lightened(0.18), 4, 3.0, 1.0))
	button.pressed.connect(pressed_callback)
	return button


func _make_small_button(text: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(52, 23)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_MUTED)
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(CHIP_BG.r, CHIP_BG.g, CHIP_BG.b, 0.62), Color(CHIP_BORDER.r, CHIP_BORDER.g, CHIP_BORDER.b, 0.52), 4, 5.0, 1.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.06), CHIP_BORDER.lightened(0.1), 4, 5.0, 1.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, CHIP_BORDER.lightened(0.18), 4, 5.0, 1.0))
	button.pressed.connect(pressed_callback)
	return button


func _get_catalog_assumption_value(assumptions: Dictionary, kind: String) -> String:
	var value: String = str(assumptions.get(kind, "")).strip_edges()
	return "" if value == "<null>" else value


func _make_assumption_summary_button(text: String, editor_kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 25)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 11)
	var is_active: bool = active_selector == editor_kind
	var is_edited: bool = bool(edited_assumption_fields.get(editor_kind, false))
	var chip_border: Color = CHIP_BORDER
	if is_edited:
		chip_border = CHIP_EDITED_BORDER
	var font_color: Color = TEXT_SECONDARY
	if is_active:
		font_color = TEXT_PRIMARY
	elif is_edited:
		font_color = TEXT_ACCENT
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if is_active else CHIP_BG, chip_border, 4, 6.0, 2.0)
	)
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), chip_border.lightened(0.12), 4, 6.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, chip_border.lightened(0.18), 4, 6.0, 2.0))
	button.pressed.connect(_on_assumption_summary_pressed.bind(editor_kind))
	return button


func _get_assumption_fallback_label(editor_kind: String) -> String:
	match editor_kind:
		SELECTOR_ITEM:
			return _t("battle.calc.item_unknown")
		SELECTOR_ABILITY:
			return _t("battle.calc.ability_unknown")
		SELECTOR_NATURE:
			return _localized_nature_name("Hardy")
		SELECTOR_EVS:
			return _t("battle.calc.evs_total", {"total": 0, "limit": EV_TOTAL_LIMIT})
		_:
			return ""


func _on_assumption_summary_pressed(editor_kind: String) -> void:
	if active_selector == editor_kind:
		_close_assumption_suggestions()
		_render_current_state()
		return
	active_selector = editor_kind
	selector_query = ""
	selector_results = []
	selector_loading = false
	selector_error = ""
	live_ev_focus_stat = ""
	live_ev_focus_caret = -1
	_render_current_state()
	if editor_kind == SELECTOR_ITEM or editor_kind == SELECTOR_ABILITY or editor_kind == SELECTOR_NATURE:
		selector_query = _get_catalog_input_text(editor_kind)
		selector_loading = true
		if editor_kind == SELECTOR_ITEM or editor_kind == SELECTOR_ABILITY:
			_refresh_catalog_results()
		_request_active_catalog()


func _render_active_assumption_editor(assumptions: Dictionary) -> void:
	if catalog_suggestions_box == null:
		return
	for child: Node in catalog_suggestions_box.get_children():
		catalog_suggestions_box.remove_child(child)
		child.queue_free()

	catalog_suggestions_box.visible = active_selector != SELECTOR_NONE
	if active_selector == SELECTOR_NONE:
		return

	match active_selector:
		SELECTOR_ITEM, SELECTOR_ABILITY:
			_render_catalog_assumption_editor(active_selector, assumptions)
		SELECTOR_NATURE:
			_render_nature_assumption_editor(assumptions)
		SELECTOR_EVS:
			_render_evs_assumption_editor(_as_dictionary(assumptions.get("evs", {})))


func _render_catalog_assumption_editor(kind: String, assumptions: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)
	catalog_suggestions_box.add_child(row)

	var input := LineEdit.new()
	input.text = _get_catalog_assumption_value(assumptions, kind)
	input.placeholder_text = _t("battle.calc.search_item") if kind == SELECTOR_ITEM else _t("battle.calc.search_ability")
	input.custom_minimum_size = Vector2(0, 24)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 11)
	input.focus_entered.connect(_on_catalog_assumption_focus_entered.bind(kind))
	input.focus_exited.connect(_on_catalog_assumption_focus_exited.bind(kind))
	input.text_changed.connect(_on_catalog_assumption_text_changed.bind(kind))
	row.add_child(input)

	var clear_button := _make_small_button(_t("common.none"), _on_catalog_assumption_clear_pressed.bind(kind))
	clear_button.custom_minimum_size = Vector2(46, 22)
	row.add_child(clear_button)

	if kind == SELECTOR_ITEM:
		item_assumption_input = input
	else:
		ability_assumption_input = input

	catalog_results_box = VBoxContainer.new()
	catalog_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_results_box.clip_contents = true
	catalog_results_box.add_theme_constant_override("separation", 2)
	catalog_suggestions_box.add_child(catalog_results_box)
	_refresh_catalog_results()
	input.call_deferred("grab_focus")
	input.caret_column = input.text.length()


func _render_nature_assumption_editor(assumptions: Dictionary) -> void:
	if selector_loading and selector_results.is_empty() and nature_catalog_options.is_empty():
		_add_selector_status(catalog_suggestions_box, _t("battle.calc.loading_natures"), TEXT_SECONDARY)
		return
	if selector_error != "" and nature_catalog_options.is_empty():
		_add_selector_status(catalog_suggestions_box, selector_error, TEXT_MUTED)

	var selected_nature: String = _fallback_text(str(assumptions.get("nature", "")).strip_edges(), "Hardy")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.clip_contents = true
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	catalog_suggestions_box.add_child(grid)
	for nature_value: Variant in _get_nature_option_names():
		var nature: String = str(nature_value)
		var button := _make_compact_option_button(
			_localized_nature_name(nature),
			nature == selected_nature,
			_on_nature_option_pressed.bind(nature)
		)
		grid.add_child(button)


func _render_evs_assumption_editor(evs: Dictionary) -> void:
	var header := VBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.clip_contents = true
	header.add_theme_constant_override("separation", 3)
	catalog_suggestions_box.add_child(header)

	live_ev_total_label = _make_label("", 11, TEXT_MUTED)
	live_ev_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(live_ev_total_label)

	_update_live_ev_total()

	for pair_value: Variant in EV_INPUT_ROWS:
		var pair: Array = pair_value as Array
		var ev_row := HBoxContainer.new()
		ev_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev_row.clip_contents = true
		ev_row.add_theme_constant_override("separation", 6)
		catalog_suggestions_box.add_child(ev_row)
		for stat_key_value: Variant in pair:
			var stat_key: String = str(stat_key_value)
			ev_row.add_child(_make_live_ev_input(stat_key, int(evs.get(stat_key, 0))))
	_update_live_ev_total()


func _make_compact_option_button(text: String, selected: bool, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_PRIMARY if selected else TEXT_SECONDARY)
	button.add_theme_stylebox_override("normal", _make_stylebox(TAB_ACTIVE_BG if selected else CHIP_BG, CHIP_BORDER, 4, 4.0, 2.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), CHIP_BORDER.lightened(0.12), 4, 4.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, CHIP_BORDER.lightened(0.18), 4, 4.0, 2.0))
	button.pressed.connect(pressed_callback)
	return button


func _on_nature_option_pressed(nature: String) -> void:
	defender_assumptions["nature"] = nature
	edited_assumption_fields["nature"] = true
	_close_assumption_suggestions()
	_emit_defender_assumptions_changed()
	_render_current_state()


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


func _on_live_ev_quick_value_pressed(stat_key: String, value: int) -> void:
	if is_syncing_assumption_controls:
		return
	_remember_live_ev_input_focus(stat_key)
	_apply_live_ev_value(stat_key, value, true)


func _apply_live_ev_value(stat_key: String, raw_value: int, sync_input_text: bool) -> void:
	var evs: Dictionary = _as_dictionary(defender_assumptions.get("evs", {})).duplicate(true)
	var clamped_value: int = clampi(raw_value, 0, 252)
	var input: LineEdit = live_ev_inputs.get(stat_key) as LineEdit
	if (sync_input_text or raw_value != clamped_value) and input != null and input.text != str(clamped_value):
		input.text = str(clamped_value)
		input.caret_column = input.text.length()

	if clamped_value <= 0:
		evs.erase(stat_key)
	else:
		evs[stat_key] = clamped_value
	defender_assumptions["evs"] = evs
	edited_assumption_fields["evs"] = true
	_update_live_ev_total()
	if _get_evs_total(evs) <= EV_TOTAL_LIMIT:
		_queue_defender_assumptions_changed()
	elif assumption_change_timer != null:
		assumption_change_timer.stop()


func _remember_live_ev_input_focus(stat_key: String) -> void:
	live_ev_focus_stat = stat_key
	live_ev_focus_caret = -1
	var input: LineEdit = live_ev_inputs.get(stat_key) as LineEdit
	if input == null:
		return
	live_ev_focus_caret = input.caret_column


func _restore_live_ev_input_focus() -> void:
	if live_ev_focus_stat == "":
		return
	var input: LineEdit = live_ev_inputs.get(live_ev_focus_stat) as LineEdit
	if input == null:
		return
	input.grab_focus()
	if live_ev_focus_caret >= 0:
		input.caret_column = mini(live_ev_focus_caret, input.text.length())


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
	field_scenario.clear()
	defender_assumptions["item"] = ""
	defender_assumptions["ability"] = ""
	defender_assumptions["nature"] = "Hardy"
	defender_assumptions["evs"] = {}
	edited_assumption_fields.clear()
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = SELECTOR_NONE
	selector_query = ""
	selector_results = []
	selector_loading = false
	selector_error = ""
	_emit_defender_assumptions_changed()
	_render_current_state()


func show_assumption_catalog_loading(kind: String, query: String) -> void:
	if kind != active_selector:
		return
	selector_query = query
	selector_loading = true
	selector_error = ""
	selector_results = []
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY:
		_refresh_catalog_results()
	elif kind == SELECTOR_NATURE:
		_render_current_state()


func show_assumption_catalog_response(kind: String, response: Dictionary) -> void:
	if kind != active_selector:
		return
	selector_loading = false
	if not bool(response.get("success", false)):
		selector_error = str(response.get("error", _t("battle.calc.error.assumptions")))
		selector_results = []
		_refresh_catalog_results()
		return

	selector_error = str(response.get("warning", ""))
	if kind == SELECTOR_ITEM:
		selector_results = _as_array(response.get("items", []))
	elif kind == SELECTOR_ABILITY:
		selector_results = _as_array(response.get("abilities", []))
	elif kind == SELECTOR_NATURE:
		selector_results = _as_array(response.get("natures", []))
		nature_catalog_options = selector_results.duplicate(true)
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY:
		_refresh_catalog_results()
	elif kind == SELECTOR_NATURE:
		_render_current_state()


func show_assumption_catalog_error(kind: String, message: String) -> void:
	if kind != active_selector:
		return
	selector_loading = false
	selector_error = _fallback_text(message, _t("battle.calc.error.assumptions"))
	selector_results = []
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY:
		_refresh_catalog_results()
	elif kind == SELECTOR_NATURE:
		_render_current_state()


func is_assumption_catalog_request_current(kind: String, query: String) -> bool:
	return kind == active_selector and query == selector_query


func _make_selector_result_button(title: String, subtitle: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = title if subtitle == "" else "%s  %s" % [title, subtitle]
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_stylebox_override("normal", _make_stylebox(ROW_BG, ROW_BORDER, 4, 6.0, 3.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), ROW_BORDER.lightened(0.1), 4, 6.0, 3.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, ROW_BORDER.lightened(0.18), 4, 6.0, 3.0))
	button.pressed.connect(pressed_callback)
	return button


func _add_selector_status(parent: VBoxContainer, text: String, color: Color) -> void:
	var label := _make_label(text, 11, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _on_catalog_assumption_focus_entered(kind: String) -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	var input_text: String = _get_catalog_input_text(kind)
	if active_selector == kind and selector_query == input_text and selector_loading:
		return
	active_selector = kind
	selector_query = input_text
	selector_results = []
	selector_error = ""
	selector_loading = true
	_refresh_catalog_results()
	_request_active_catalog()


func _on_catalog_assumption_focus_exited(kind: String) -> void:
	call_deferred("_close_assumption_suggestions_if_focus_left", kind)


func _close_assumption_suggestions_if_focus_left(kind: String) -> void:
	if active_selector != kind:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == item_assumption_input or focus_owner == ability_assumption_input:
		return
	if catalog_suggestions_box != null and focus_owner != null and catalog_suggestions_box.is_ancestor_of(focus_owner):
		return
	_close_assumption_suggestions()


func _close_assumption_suggestions() -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = SELECTOR_NONE
	selector_query = ""
	selector_results = []
	selector_loading = false
	selector_error = ""
	_render_current_state()


func _on_catalog_assumption_text_changed(text: String, kind: String) -> void:
	if is_syncing_assumption_controls:
		return
	active_selector = kind
	selector_query = text
	if catalog_search_timer == null:
		_request_active_catalog()
		return
	catalog_search_timer.start()


func _request_active_catalog() -> void:
	if active_selector == SELECTOR_NONE:
		return
	selector_loading = true
	selector_error = ""
	selector_results = []
	_refresh_catalog_results()
	assumption_catalog_requested.emit(active_selector, selector_query, _get_selector_species())


func _on_catalog_assumption_clear_pressed(kind: String) -> void:
	var key: String = kind
	defender_assumptions[key] = ""
	edited_assumption_fields.erase(key)
	_set_catalog_input_text(kind, "")
	_close_assumption_suggestions()
	_emit_defender_assumptions_changed()


func _on_selector_result_pressed(result: Dictionary) -> void:
	if active_selector == SELECTOR_NONE:
		return
	var calc_name: String = str(result.get("calcName", result.get("name", ""))).strip_edges()
	if calc_name == "":
		return
	var key: String = active_selector
	defender_assumptions[key] = calc_name
	edited_assumption_fields[key] = true
	_set_catalog_input_text(key, calc_name)
	_close_assumption_suggestions()
	_emit_defender_assumptions_changed()


func _refresh_catalog_results() -> void:
	if catalog_results_box == null:
		return
	for child: Node in catalog_results_box.get_children():
		catalog_results_box.remove_child(child)
		child.queue_free()

	catalog_results_box.visible = active_selector == SELECTOR_ITEM or active_selector == SELECTOR_ABILITY
	if not catalog_results_box.visible:
		return

	var clear_button := _make_selector_result_button(_t("battle.calc.unknown_none"), _t("common.clear"), Callable(self, "_on_catalog_assumption_clear_pressed").bind(active_selector))
	catalog_results_box.add_child(clear_button)

	if selector_loading:
		_add_selector_status(catalog_results_box, _t("common.loading"), TEXT_SECONDARY)
		return

	if selector_error != "":
		_add_selector_status(catalog_results_box, selector_error, TEXT_MUTED)

	if selector_results.is_empty():
		_add_selector_status(catalog_results_box, _t("battle.calc.no_results_short"), TEXT_SECONDARY)
		return

	var result_count: int = mini(selector_results.size(), 4)
	for index in range(result_count):
		var result: Dictionary = _as_dictionary(selector_results[index])
		var name: String = str(result.get("name", result.get("calcName", ""))).strip_edges()
		catalog_results_box.add_child(_make_selector_result_button(
			_fallback_text(name, _t("common.unknown")),
			"",
			Callable(self, "_on_selector_result_pressed").bind(result)
		))


func _get_catalog_input_text(kind: String) -> String:
	var input: LineEdit = _get_catalog_input(kind)
	return input.text.strip_edges() if input != null else ""


func _set_catalog_input_text(kind: String, value: String) -> void:
	var input: LineEdit = _get_catalog_input(kind)
	if input == null:
		return
	input.text = value
	input.caret_column = input.text.length()


func _get_catalog_input(kind: String) -> LineEdit:
	if kind == SELECTOR_ITEM:
		return item_assumption_input
	if kind == SELECTOR_ABILITY:
		return ability_assumption_input
	return null


func _get_selector_species() -> String:
	if last_response.is_empty():
		return ""
	var defender: Dictionary = _as_dictionary(last_response.get("defender", {}))
	for key: String in ["speciesId", "species", "displayName", "name"]:
		var value: String = str(defender.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


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
			return _t("battle.calc.hp_short")
		"atk":
			return _t("battle.stat.short.attack")
		"def":
			return _t("battle.stat.short.defense")
		"spa":
			return _t("battle.stat.short.special_attack")
		"spd":
			return _t("battle.stat.short.special_defense")
		"spe":
			return _t("battle.stat.short.speed")
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
	var hp := _get_pokemon_hp(pokemon)
	var display_value: Variant = hp.get("display", "")
	var display := str(display_value).strip_edges() if not (display_value is Dictionary) else ""
	if display != "":
		return _t("battle.calc.hp_value", {"value": display})
	if display_value is Dictionary:
		var display_data := _as_dictionary(display_value)
		var current_value: Variant = display_data.get("current")
		var maximum_value: Variant = display_data.get("maximum")
		if typeof(current_value) == TYPE_INT and typeof(maximum_value) == TYPE_INT and int(maximum_value) > 0:
			if str(display_data.get("scale", "")) == "public_percent_100":
				return _t("battle.calc.hp_percent", {"percent": int(current_value)})
			return _t("battle.calc.hp_value", {"value": "%d/%d" % [int(current_value), int(maximum_value)]})

	var percent_value: Variant = _get_percent_number(hp.get("percent"))
	if percent_value != null:
		return _t("battle.calc.hp_percent", {"percent": _format_percent_value(percent_value)})
	return _t("battle.calc.hp_unknown")


func _get_level_label(pokemon: Dictionary) -> String:
	var level_value: Variant = pokemon.get("level", "")
	if level_value is Dictionary:
		level_value = (level_value as Dictionary).get("value", "")
	if str(level_value).strip_edges() == "":
		var snapshot_pokemon := _get_snapshot_pokemon_by_ref(str(pokemon.get("pokemonRef", "")))
		var snapshot_level := _as_dictionary(snapshot_pokemon.get("level", {}))
		level_value = snapshot_level.get("value", "")
	var level := str(level_value).strip_edges()
	return _t("battle.calc.level", {"level": level}) if level != "" else _t("battle.calc.level_unknown")


func _get_pokemon_hp(pokemon: Dictionary) -> Dictionary:
	var hp := _as_dictionary(pokemon.get("hp", {}))
	if not hp.is_empty():
		return hp
	var snapshot_pokemon := _get_snapshot_pokemon_by_ref(str(pokemon.get("pokemonRef", "")))
	return _as_dictionary(snapshot_pokemon.get("hp", {}))


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
					_fallback_text(_get_move_name(result), _t("battle.move.unknown").to_lower()),
					str(result.get("minPercent")),
					str(result.get("maxPercent")),
				]
			)
			return _t("battle.calc.issue")
		return "%s-%s%%" % [
			_format_percent_value(result.get("minPercent")),
			_format_percent_value(result.get("maxPercent")),
		]
	return ""


func _get_primary_result_label(result: Dictionary, defender: Dictionary) -> String:
	if _is_status_result(result):
		return _t("battle.calc.status")

	var min_percent_value: Variant = _get_percent_number(result.get("minPercent"))
	var max_percent_value: Variant = _get_percent_number(result.get("maxPercent"))
	if min_percent_value != null and float(min_percent_value) >= 100.0:
		return "OHKO"
	var ko_summary_label := str(result.get("koSummaryLabel", "")).strip_edges()
	if ko_summary_label != "":
		return ko_summary_label

	var hp_percent_value: Variant = _get_defender_hp_percent(defender)
	if hp_percent_value != null and min_percent_value != null and max_percent_value != null:
		var hp_percent := float(hp_percent_value)
		var min_percent := float(min_percent_value)
		var max_percent := float(max_percent_value)
		if hp_percent > 0.0 and min_percent >= 0.0 and max_percent >= 0.0 and max_percent <= SUSPICIOUS_PERCENT_LIMIT:
			if min_percent >= hp_percent:
				return "OHKO"
			if max_percent >= hp_percent:
				return _t("battle.calc.possible_ohko")
			if max_percent > 0.0:
				var best_hits := int(ceil(hp_percent / max_percent))
				var worst_hits := best_hits
				if min_percent > 0.0:
					worst_hits = int(ceil(hp_percent / min_percent))
				if best_hits >= 5:
					return _t("battle.calc.no_ko")
				if best_hits == worst_hits:
					return "%dHKO" % best_hits
				return "%d-%dHKO" % [best_hits, worst_hits]
	var hko_label := _get_hko_label(result)
	return hko_label


func _get_compact_result_label(text: String) -> String:
	var label := text.strip_edges()
	if label == "":
		return ""
	match label:
		"Guaranteed OHKO":
			return "OHKO"
		"Possible OHKO":
			return _t("battle.calc.chance")
		"Already KO":
			return _t("battle.calc.ko")
		"No KO":
			return _t("battle.calc.no_ko")
	if label.begins_with("100% "):
		return label.substr(5)
	if label.contains(" chance to "):
		label = label.replace(" chance to ", " ")
	label = label.replace("Guaranteed ", "")
	label = label.replace("Possible ", "")
	return label


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


func _get_assumption_chip_label(assumptions: Dictionary, key: String, fallback: String) -> String:
	var label := _get_named_assumption_label(assumptions, key, fallback)
	if label == fallback:
		return "%s · %s" % [label, _t("battle.calc.provenance.unknown")]
	return _get_scenario_label(label, key)


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
	var canonical_nature := _fallback_text(str(assumptions.get("nature", "")).strip_edges(), "Hardy")
	var label := _localized_nature_name(canonical_nature)
	return _get_scenario_label(label, "nature")


func _localized_nature_name(nature: String) -> String:
	var content_localization := _get_content_localization()
	if content_localization != null and content_localization.has_method("nature_name"):
		return str(content_localization.call("nature_name", nature, nature))
	return nature


func _get_content_localization() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/ContentLocalization")
	var scene_tree := Engine.get_main_loop() as SceneTree
	return scene_tree.root.get_node_or_null("ContentLocalization") if scene_tree != null else null


func _get_evs_chip_label(evs: Dictionary) -> String:
	var label := _get_evs_label(evs)
	return "%s*" % label if bool(edited_assumption_fields.get("evs", false)) else label


func _get_evs_summary_chip_label(evs: Dictionary) -> String:
	var label := _t("battle.calc.evs_total", {
		"total": _get_evs_total(evs),
		"limit": EV_TOTAL_LIMIT,
	})
	return _get_scenario_label(label, "evs")


func _get_scenario_label(label: String, field_name: String) -> String:
	var edited_marker := "*" if bool(edited_assumption_fields.get(field_name, false)) else ""
	return "%s%s · %s" % [label, edited_marker, _t("battle.calc.provenance.user_scenario")]


func _get_nature_option_names() -> Array[String]:
	var source: Array = []
	if active_selector == SELECTOR_NATURE and not selector_results.is_empty():
		source = selector_results
	else:
		source = nature_catalog_options
	var names: Array[String] = []
	for nature_value: Variant in source:
		var nature: Dictionary = _as_dictionary(nature_value)
		var name: String = str(nature.get("calcName", nature.get("name", ""))).strip_edges()
		if name != "" and not names.has(name):
			names.append(name)
	if names.is_empty():
		for fallback_name: Variant in FALLBACK_NATURE_OPTIONS:
			names.append(str(fallback_name))
	return names


func _get_assumptions_summary_label(assumptions: Dictionary) -> String:
	var parts: Array[String] = [
		_get_assumption_chip_label(assumptions, "item", _t("battle.calc.item_unknown")),
		_get_assumption_chip_label(assumptions, "ability", _t("battle.calc.ability_unknown")),
		_get_nature_chip_label(assumptions),
		_get_evs_chip_label(_as_dictionary(assumptions.get("evs", {}))),
		_get_ivs_label(_as_dictionary(assumptions.get("ivs", {}))),
	]
	return _t("battle.calc.assumptions", {"values": ", ".join(parts)})


func _get_evs_label(evs: Dictionary) -> String:
	if evs.is_empty():
		return _t("battle.calc.evs_value", {"value": 0})

	for preset_value: Variant in EV_PRESETS:
		var preset := preset_value as Dictionary
		var preset_evs := _as_dictionary(preset.get("evs", {}))
		if _evs_equal(evs, preset_evs):
			return str(preset.get("chip", _t("battle.calc.evs_custom")))

	var total := 0
	for value: Variant in evs.values():
		var number_value: Variant = _get_percent_number(value)
		if number_value != null:
			total += int(number_value)
	return _t("battle.calc.evs_value", {"value": total if total > 0 else 0})


func _get_evs_total(evs: Dictionary) -> int:
	var total: int = 0
	for stat_key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		total += clampi(int(evs.get(stat_key, 0)), 0, 252)
	return total


func _is_custom_evs(evs: Dictionary) -> bool:
	for preset_value: Variant in EV_PRESETS:
		var preset: Dictionary = preset_value as Dictionary
		if _evs_equal(evs, _as_dictionary(preset.get("evs", {}))):
			return false
	return not evs.is_empty()


func _get_ivs_label(ivs: Dictionary) -> String:
	if ivs.is_empty():
		return _t("battle.calc.ivs_value", {"value": 31})

	var values := []
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if ivs.has(key):
			values.append(int(ivs.get(key)))
	if values.is_empty():
		return _t("battle.calc.ivs_value", {"value": 31})

	var first_value := int(values[0])
	for value: Variant in values:
		if int(value) != first_value:
			return _t("battle.calc.ivs_custom")
	return _t("battle.calc.ivs_value", {"value": first_value})


func _evs_equal(left: Dictionary, right: Dictionary) -> bool:
	var stat_keys := ["hp", "atk", "def", "spa", "spd", "spe"]
	for key: String in stat_keys:
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _get_defender_hp_percent(defender: Dictionary) -> Variant:
	var hp := _get_pokemon_hp(defender)
	var percent: Variant = _get_percent_number(hp.get("percent"))
	if percent != null:
		return percent
	var display := _as_dictionary(hp.get("display", {}))
	var current_value: Variant = _get_percent_number(display.get("current"))
	var maximum_value: Variant = _get_percent_number(display.get("maximum"))
	if current_value != null and maximum_value != null and float(maximum_value) > 0.0:
		return float(current_value) * 100.0 / float(maximum_value)
	return null


func _get_boosts_label(pokemon: Dictionary) -> String:
	var boosts := _as_dictionary(pokemon.get("boosts", {}))
	if boosts.is_empty():
		return ""
	var values := _get_boosts_text(boosts)
	return "" if values == "" else _t("battle.calc.boosts", {"values": values})


func _get_boosts_text(boosts: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_key: String in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]:
		if not boosts.has(stat_key):
			continue
		var amount := clampi(int(boosts.get(stat_key, 0)), -6, 6)
		if amount == 0:
			continue
		parts.append("%s %s%d" % [_format_boost_stat_name(stat_key), "+" if amount > 0 else "", amount])
	if parts.is_empty():
		return ""
	return " / ".join(parts)


func _format_boost_stat_name(stat_key: String) -> String:
	match stat_key:
		"atk":
			return _t("battle.stat.short.attack")
		"def":
			return _t("battle.stat.short.defense")
		"spa":
			return _t("battle.stat.short.special_attack")
		"spd":
			return _t("battle.stat.short.special_defense")
		"spe":
			return _t("battle.stat.short.speed")
		"accuracy":
			return _t("battle.stat.short.accuracy")
		"evasion":
			return _t("battle.stat.short.evasion")
		_:
			return stat_key.capitalize()


func _format_percent_value(value: Variant) -> String:
	var number_value: Variant = _get_percent_number(value)
	if number_value == null:
		return "--"

	var number := float(number_value)
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


func _on_locale_changed(_locale: String) -> void:
	_render_current_state()


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
