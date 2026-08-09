extends MarginContainer

class_name BattleDamageCalcPanel

const CALCDEX_SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/photo_mode_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_unchecked.svg")
signal defender_assumptions_changed(assumptions: Dictionary, edited_fields: Dictionary)
signal assumption_catalog_requested(kind: String, query: String, species: String)
signal sample_set_catalog_requested(species: String)
signal default_ability_requested(species: String)
signal matchup_selection_changed()

const TEXT_PRIMARY := Color(0.95686275, 0.94509804, 0.91764706, 1.0)
const TEXT_SECONDARY := Color(0.72156864, 0.72156864, 0.72156864, 1.0)
const TEXT_MUTED := Color(0.56, 0.6, 0.68, 1.0)
const TEXT_ACCENT := Color(0.84705883, 0.7058824, 0.41568628, 1.0)
const TEXT_ERROR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const ROW_BG := Color(0.014, 0.021, 0.036, 0.98)
const ROW_BG_ALT := Color(0.022, 0.033, 0.052, 0.98)
const ROW_BORDER := Color(0.14, 0.26, 0.42, 0.76)
const PROFILE_BG := Color(0.021, 0.033, 0.058, 0.95)
const PROFILE_BORDER := Color(0.18, 0.31, 0.49, 0.74)
const HERO_BG := Color(0.018, 0.047, 0.078, 0.98)
const HERO_BORDER := Color(0.16, 0.48, 0.70, 0.92)
const CHIP_BG := Color(0.028, 0.043, 0.073, 0.96)
const CHIP_BORDER := Color(0.2, 0.34, 0.52, 0.82)
const CHIP_EDITED_BORDER := Color(0.62, 0.48, 0.23, 0.9)
const CHIP_PUBLIC_BORDER := Color(0.25, 0.39, 0.58, 0.9)
const KO_BORDER := Color(0.72, 0.55, 0.23, 0.88)
const TAB_BG := Color(0.024, 0.036, 0.062, 0.92)
const TAB_ACTIVE_BG := Color(0.124, 0.203, 0.332, 0.98)
const TAB_BORDER := Color(0.19, 0.31, 0.48, 0.9)
const DROPDOWN_BG := Color(0.018, 0.035, 0.059, 0.98)
const DROPDOWN_HOVER_BG := Color(0.035, 0.105, 0.164, 0.99)
const DROPDOWN_PRESSED_BG := Color(0.045, 0.137, 0.211, 1.0)
const DROPDOWN_POPUP_BG := Color(0.008, 0.019, 0.034, 0.995)
const DROPDOWN_BORDER := Color(0.16, 0.34, 0.50, 0.9)
const DROPDOWN_HOVER_BORDER := Color(0.30, 0.67, 0.86, 0.96)
const DROPDOWN_FOCUS_BORDER := Color(0.56, 0.87, 1.0, 1.0)
const SUSPICIOUS_PERCENT_LIMIT := 999.0
const DAMAGE_COLUMN_WIDTH := 132.0
const KO_COLUMN_WIDTH := 92.0
const TYPE_COLORS := {
	"bug": Color(0.52, 0.63, 0.08, 1.0),
	"dark": Color(0.25, 0.22, 0.27, 1.0),
	"dragon": Color(0.30, 0.32, 0.77, 1.0),
	"electric": Color(0.88, 0.68, 0.08, 1.0),
	"fairy": Color(0.82, 0.39, 0.64, 1.0),
	"fighting": Color(0.72, 0.20, 0.22, 1.0),
	"fire": Color(0.90, 0.25, 0.18, 1.0),
	"flying": Color(0.42, 0.58, 0.82, 1.0),
	"ghost": Color(0.37, 0.31, 0.60, 1.0),
	"grass": Color(0.24, 0.61, 0.25, 1.0),
	"ground": Color(0.66, 0.49, 0.20, 1.0),
	"ice": Color(0.25, 0.68, 0.72, 1.0),
	"normal": Color(0.48, 0.48, 0.45, 1.0),
	"poison": Color(0.58, 0.25, 0.65, 1.0),
	"psychic": Color(0.86, 0.31, 0.51, 1.0),
	"rock": Color(0.58, 0.49, 0.19, 1.0),
	"steel": Color(0.40, 0.48, 0.56, 1.0),
	"water": Color(0.20, 0.45, 0.80, 1.0),
}
const SUBTAB_YOUR_DAMAGE := "your"
const SUBTAB_THEIR_DAMAGE := "their"
const SELECTOR_NONE := ""
const SELECTOR_ITEM := "item"
const SELECTOR_ABILITY := "ability"
const SELECTOR_NATURE := "nature"
const SELECTOR_EVS := "evs"
const SELECTOR_MOVE := "move"
const SAMPLE_SET_CUSTOM := "__custom__"
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
var move_assumption_input: LineEdit
var catalog_suggestions_box: VBoxContainer
var catalog_results_box: VBoxContainer
var assumption_change_timer: Timer
var catalog_search_timer: Timer
var active_selector: String = SELECTOR_NONE
var active_move_slot := -1
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
var advanced_scenario_expanded := false
var warning_details_expanded := false
var warning_details_panel: Control
var sample_set_options: Array[Dictionary] = []
var sample_set_species := ""
var sample_set_loading := false
var sample_set_error := ""
var selected_sample_set_id := ""
var current_default_ability := ""
var current_default_ability_species := ""
var current_default_ability_loading := false


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
	content.add_theme_constant_override("separation", 8)
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
	_clear_sample_sets()
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
	elif str(response.get("direction", "")) != str(get_matchup_selection().get("direction", "")):
		last_response = {}
		last_error = _t("battle.calc.error.direction_mismatch")
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
	var previous_opponent_ref := selected_opponent_ref
	knowledge_snapshot = snapshot.duplicate(true)
	selected_viewer_ref = _resolve_selected_ref("viewer", selected_viewer_ref)
	selected_opponent_ref = _resolve_selected_ref("opponent", selected_opponent_ref)
	if previous_opponent_ref != "" and selected_opponent_ref != previous_opponent_ref:
		_clear_sample_sets()
	_request_sample_sets_if_needed()
	_refresh_current_scenario()
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
	move_assumption_input = null
	catalog_suggestions_box = null
	catalog_results_box = null
	active_selector = SELECTOR_NONE
	active_move_slot = -1
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
		and (active_selector == SELECTOR_ITEM or active_selector == SELECTOR_ABILITY or active_selector == SELECTOR_MOVE)
	)


func _render_your_damage_response(response: Dictionary) -> void:
	var attacker: Dictionary = _as_dictionary(response.get("attacker", {}))
	var defender: Dictionary = _as_dictionary(response.get("defender", {}))
	var viewer := attacker if str(attacker.get("relation", "")) == "viewer" else defender
	var opponent := attacker if str(attacker.get("relation", "")) == "opponent" else defender
	_add_profile_summary(
		_get_pokemon_label(viewer, _t("battle.calc.your_pokemon")),
		_get_pokemon_label(opponent, _t("battle.calc.opponent")),
		_get_hp_label(opponent),
		_get_level_label(opponent),
		_get_boosts_label(viewer),
		_get_hp_label(viewer),
		_get_level_label(viewer),
		str(viewer.get("species", "")),
		str(opponent.get("species", "")),
		_get_defender_hp_percent(viewer),
		_get_defender_hp_percent(opponent),
		_get_boosts_label(opponent)
	)
	_add_assumption_chips(opponent, response)

	var results: Array = _as_array(response.get("results", []))
	if results.is_empty():
		var empty_fallback := _t("battle.calc.no_damage_taken_moves") if str(response.get("direction", "")) == "opponent-to-own" else _t("battle.calc.no_results")
		_add_status(_fallback_text(str(response.get("emptyReason", "")), empty_fallback), TEXT_SECONDARY)
		return

	_add_move_results_table(results, defender)
	_add_result_footnotes(response, results)


func _clear_content() -> void:
	warning_details_panel = null
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
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT_PRIMARY if active_subtab == tab_id else TEXT_SECONDARY)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if active_subtab == tab_id else TAB_BG, TEXT_ACCENT if active_subtab == tab_id else TAB_BORDER, 7, 8.0, 3.0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(TAB_ACTIVE_BG.lightened(0.08), TAB_BORDER.lightened(0.1), 7, 8.0, 3.0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(TAB_ACTIVE_BG, TEXT_ACCENT, 7, 8.0, 3.0)
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


func _clear_sample_sets() -> void:
	sample_set_options.clear()
	sample_set_species = ""
	sample_set_loading = false
	sample_set_error = ""
	selected_sample_set_id = ""


func _request_sample_sets_if_needed() -> void:
	var species := _get_selected_opponent_species()
	if species == "" or species.to_lower() == sample_set_species.to_lower():
		return
	sample_set_options.clear()
	sample_set_species = species
	sample_set_loading = true
	sample_set_error = ""
	selected_sample_set_id = ""
	sample_set_catalog_requested.emit(species)


func show_sample_set_catalog_response(species: String, response: Dictionary) -> void:
	if species.to_lower() != sample_set_species.to_lower():
		return
	sample_set_loading = false
	sample_set_error = ""
	var valid_envelope := (
		int(response.get("schemaVersion", 0)) == 1
		and str(response.get("formatId", "")) == "gen9nationaldex"
		and str(response.get("source", "")) == "pokeaether_curated"
		and str(response.get("species", "")).to_lower() == species.to_lower()
		and response.get("sets") is Array
		and (response.get("sets") as Array).size() <= 64
	)
	if not valid_envelope:
		sample_set_options.clear()
		sample_set_error = _t("battle.calc.sample_sets_unavailable")
	else:
		var options: Array[Dictionary] = []
		for value: Variant in response.get("sets", []):
			var entry := _as_dictionary(value)
			if _is_valid_sample_set(entry):
				options.append(entry.duplicate(true))
		sample_set_options = options
	if is_inside_tree():
		_render_current_state()


func show_sample_set_catalog_error(species: String, _error: String) -> void:
	if species.to_lower() != sample_set_species.to_lower():
		return
	sample_set_loading = false
	sample_set_options.clear()
	sample_set_error = _t("battle.calc.sample_sets_unavailable")
	if is_inside_tree():
		_render_current_state()


func _is_valid_sample_set(entry: Dictionary) -> bool:
	if str(entry.get("id", "")).strip_edges() == "" or str(entry.get("name", "")).strip_edges() == "":
		return false
	if str(entry.get("ability", "")).strip_edges() == "" or str(entry.get("nature", "")).strip_edges() == "":
		return false
	if not (entry.get("evs") is Dictionary) or not (entry.get("ivs") is Dictionary) or not (entry.get("moves") is Array):
		return false
	if not _is_valid_sample_stat_table(entry.get("evs"), 252) or not _is_valid_sample_stat_table(entry.get("ivs"), 31):
		return false
	var moves: Array = entry.get("moves") as Array
	return moves.size() <= 4 and moves.all(func(value: Variant) -> bool: return value is String and not str(value).strip_edges().is_empty())


func _is_valid_sample_stat_table(value: Variant, maximum: int) -> bool:
	if not (value is Dictionary):
		return false
	var stats := value as Dictionary
	for key: Variant in stats.keys():
		if str(key) not in ["hp", "atk", "def", "spa", "spd", "spe"]:
			return false
		var stat_value: Variant = stats.get(key)
		if typeof(stat_value) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(stat_value)) or float(stat_value) != float(int(stat_value)):
			return false
		if int(stat_value) < 0 or int(stat_value) > maximum:
			return false
	return true


func _get_selected_opponent_species() -> String:
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	if opponent.is_empty():
		return ""
	var identity := _as_dictionary(opponent.get("identity", {}))
	if str(identity.get("state", "")) != "known":
		return ""
	return str(identity.get("value", "")).strip_edges()


func _refresh_current_scenario() -> void:
	var species := _get_selected_opponent_species()
	if species == "":
		return
	var known_ability := _get_known_opponent_value("ability")
	if known_ability == "" and current_default_ability_species.to_lower() != species.to_lower():
		current_default_ability_species = species
		current_default_ability = ""
		current_default_ability_loading = true
		default_ability_requested.emit(species)
	var previous_assumptions := defender_assumptions.duplicate(true)
	var previous_edited := edited_assumption_fields.duplicate(true)
	if selected_sample_set_id == "" and edited_assumption_fields.is_empty():
		_apply_current_defaults()
	else:
		_apply_known_opponent_facts()
	if defender_assumptions != previous_assumptions or edited_assumption_fields != previous_edited:
		defender_assumptions_changed.emit(defender_assumptions.duplicate(true), edited_assumption_fields.duplicate(true))


func _apply_current_defaults() -> void:
	defender_assumptions = {
		"nature": "Hardy",
		"evs": {},
		"exactStats": true,
	}
	var known_item := _get_known_opponent_value("item")
	if known_item != "":
		defender_assumptions["item"] = known_item
	var known_ability := _get_known_opponent_value("ability")
	if known_ability != "":
		defender_assumptions["ability"] = known_ability
	elif current_default_ability != "":
		defender_assumptions["ability"] = current_default_ability


func _apply_known_opponent_facts() -> void:
	for key: String in ["item", "ability"]:
		var known_value := _get_known_opponent_value(key)
		if known_value == "":
			continue
		defender_assumptions[key] = known_value
		edited_assumption_fields.erase(key)


func _get_known_opponent_value(field_name: String) -> String:
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	var knowledge := _as_dictionary(opponent.get(field_name, {}))
	if str(knowledge.get("state", "")) != "known":
		return ""
	return str(knowledge.get("value", "")).strip_edges()


func show_default_ability_response(species: String, response: Dictionary) -> void:
	if species.to_lower() != current_default_ability_species.to_lower():
		return
	current_default_ability_loading = false
	var abilities := _as_array(response.get("abilities", []))
	if bool(response.get("success", false)) and bool(response.get("filteredBySpecies", false)) and not abilities.is_empty():
		var first_ability := _as_dictionary(abilities[0])
		current_default_ability = str(first_ability.get("calcName", first_ability.get("name", ""))).strip_edges()
	if selected_sample_set_id == "" and edited_assumption_fields.is_empty():
		var previous := defender_assumptions.duplicate(true)
		_apply_current_defaults()
		if defender_assumptions != previous:
			defender_assumptions_changed.emit(defender_assumptions.duplicate(true), {})
	if is_inside_tree():
		_render_current_state()


func show_default_ability_error(species: String) -> void:
	if species.to_lower() != current_default_ability_species.to_lower():
		return
	current_default_ability_loading = false
	if is_inside_tree():
		_render_current_state()


func _is_current_ability_assumed() -> bool:
	return (
		_get_known_opponent_value("ability") == ""
		and current_default_ability != ""
		and str(defender_assumptions.get("ability", "")) == current_default_ability
		and not bool(edited_assumption_fields.get("ability", false))
	)


func _add_sample_set_selector(parent: Container) -> void:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = _t("battle.calc.set_selector_tooltip")
	selector.add_item(_t("battle.calc.current"))
	selector.set_item_metadata(0, "")
	if selected_sample_set_id == "" and (not edited_assumption_fields.is_empty() or not field_scenario.is_empty()):
		selector.add_item(_t("battle.calc.custom_scenario"))
		selector.set_item_metadata(selector.item_count - 1, SAMPLE_SET_CUSTOM)
		selector.select(selector.item_count - 1)
	for option: Dictionary in sample_set_options:
		var option_id := str(option.get("id", ""))
		selector.add_item(str(option.get("name", option_id)))
		selector.set_item_metadata(selector.item_count - 1, option_id)
		selector.set_item_tooltip(selector.item_count - 1, _get_sample_set_tooltip(option))
		if option_id == selected_sample_set_id:
			selector.select(selector.item_count - 1)
	if sample_set_loading:
		selector.add_item(_t("battle.calc.sample_sets_loading"))
		selector.set_item_disabled(selector.item_count - 1, true)
	elif sample_set_error != "":
		selector.add_item(sample_set_error)
		selector.set_item_disabled(selector.item_count - 1, true)
	selector.item_selected.connect(_on_sample_set_selected.bind(selector))
	_apply_calcdex_dropdown_style(selector, 34.0, 12)
	parent.add_child(selector)


func _on_sample_set_selected(index: int, selector: OptionButton) -> void:
	var option_id := str(selector.get_item_metadata(index))
	if option_id == SAMPLE_SET_CUSTOM:
		return
	if option_id == "":
		_reset_to_current()
		return
	for option: Dictionary in sample_set_options:
		if str(option.get("id", "")) == option_id:
			_apply_sample_set(option)
			return


func _reset_to_current() -> void:
	edited_assumption_fields.clear()
	field_scenario.clear()
	selected_sample_set_id = ""
	advanced_scenario_expanded = false
	active_selector = SELECTOR_NONE
	active_move_slot = -1
	_apply_current_defaults()
	_emit_defender_assumptions_changed()
	_render_current_state()


func _apply_sample_set(option: Dictionary) -> void:
	defender_assumptions.clear()
	edited_assumption_fields.clear()
	for key: String in ["item", "ability", "nature"]:
		var value := str(option.get(key, "")).strip_edges()
		if value != "" and value != "<null>":
			defender_assumptions[key] = value
			edited_assumption_fields[key] = true
	defender_assumptions["evs"] = _sanitize_sample_set_stats(_as_dictionary(option.get("evs", {})), 252, false)
	defender_assumptions["ivs"] = _sanitize_sample_set_stats(_as_dictionary(option.get("ivs", {})), 31, true)
	defender_assumptions["exactStats"] = true
	edited_assumption_fields["evs"] = true
	edited_assumption_fields["ivs"] = true
	edited_assumption_fields["exactStats"] = true
	var moves: Array[String] = []
	for move_value: Variant in _as_array(option.get("moves", [])):
		var move_name := str(move_value).strip_edges()
		if move_name != "" and move_name.length() <= 100 and move_name not in moves and moves.size() < 4:
			moves.append(move_name)
	if not moves.is_empty():
		defender_assumptions["assumedMoves"] = moves
		edited_assumption_fields["assumedMoves"] = true
	selected_sample_set_id = str(option.get("id", ""))
	active_selector = SELECTOR_NONE
	active_move_slot = -1
	_apply_known_opponent_facts()
	_emit_defender_assumptions_changed()
	_render_current_state()


func _mark_sample_set_custom() -> void:
	selected_sample_set_id = ""
	edited_assumption_fields["exactStats"] = true


func _sanitize_sample_set_stats(stats: Dictionary, maximum: int, omit_default: bool) -> Dictionary:
	var sanitized: Dictionary = {}
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if not stats.has(key):
			continue
		var value := clampi(int(stats.get(key, maximum if omit_default else 0)), 0, maximum)
		if (omit_default and value == maximum) or (not omit_default and value == 0):
			continue
		sanitized[key] = value
	return sanitized


func _get_sample_set_tooltip(option: Dictionary) -> String:
	var details: Array[String] = []
	for key: String in ["item", "ability", "nature"]:
		var value := str(option.get(key, "")).strip_edges()
		if value != "" and value != "<null>":
			details.append(value)
	return _join_string_array(details, " · ")


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
	_apply_calcdex_dropdown_style(selector, 30.0, 14)
	return selector


func _on_pokemon_selected(index: int, selector: OptionButton, relation: String) -> void:
	var pokemon_ref := str(selector.get_item_metadata(index))
	if relation == "viewer":
		selected_viewer_ref = pokemon_ref
	else:
		if pokemon_ref != selected_opponent_ref:
			_clear_sample_sets()
		selected_opponent_ref = pokemon_ref
		_request_sample_sets_if_needed()
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
	viewer_name: String,
	opponent_name: String,
	opponent_hp_label: String,
	opponent_level_label: String,
	viewer_boosts_label: String = "",
	viewer_hp_label: String = "",
	viewer_level_label: String = "",
	viewer_sprite_species: String = "",
	opponent_sprite_species: String = "",
	viewer_hp_percent: Variant = null,
	opponent_hp_percent: Variant = null,
	opponent_boosts_label: String = ""
) -> void:
	var matchup_row := HBoxContainer.new()
	matchup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	matchup_row.add_theme_constant_override("separation", 6)
	content.add_child(matchup_row)
	var viewer_details: Array[String] = []
	if viewer_hp_label.strip_edges() != "":
		viewer_details.append(viewer_hp_label)
	viewer_details.append(_fallback_text(viewer_level_label, _t("battle.calc.level_unknown")))
	if viewer_boosts_label.strip_edges() != "":
		viewer_details.append(viewer_boosts_label)
	matchup_row.add_child(_make_matchup_side(
		_t("battle.calc.your_pokemon"),
		_fallback_text(viewer_name, _t("battle.calc.your_pokemon")),
		"viewer",
		_join_string_array(viewer_details, "  ·  "),
		active_subtab == SUBTAB_YOUR_DAMAGE,
		_fallback_text(viewer_sprite_species, viewer_name),
		viewer_hp_percent
	))
	var arrow := _make_label("VS", 10, TEXT_ACCENT)
	arrow.custom_minimum_size = Vector2(30, 0)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	matchup_row.add_child(arrow)
	var opponent_details: Array[String] = [
		_fallback_text(opponent_hp_label, _t("battle.calc.hp_unknown")),
		_fallback_text(opponent_level_label, _t("battle.calc.level_unknown")),
	]
	if opponent_boosts_label.strip_edges() != "":
		opponent_details.append(opponent_boosts_label)
	matchup_row.add_child(_make_matchup_side(
		_t("battle.calc.opponent"),
		_fallback_text(opponent_name, _t("battle.calc.opponent")),
		"opponent",
		_join_string_array(opponent_details, "  ·  "),
		active_subtab == SUBTAB_THEIR_DAMAGE,
		_fallback_text(opponent_sprite_species, opponent_name),
		opponent_hp_percent
	))


func _make_matchup_side(
	caption: String,
	pokemon_name: String,
	relation: String,
	details: String,
	is_attacker: bool,
	sprite_species: String,
	hp_percent: Variant
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 98)
	panel.add_theme_stylebox_override("panel", _make_card_stylebox(HERO_BG, HERO_BORDER, 10, 10.0, 8.0))
	var card_row := HBoxContainer.new()
	card_row.clip_contents = true
	card_row.add_theme_constant_override("separation", 9)
	panel.add_child(card_row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = PokemonAssets.load_party_icon(sprite_species)
	card_row.add_child(icon)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.clip_contents = true
	side.add_theme_constant_override("separation", 3)
	card_row.add_child(side)
	var caption_label := _make_label(caption.to_upper(), 10, TEXT_MUTED)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(caption_label)
	if knowledge_snapshot.is_empty():
		var name_label := _make_label(pokemon_name, 16, TEXT_PRIMARY)
		name_label.tooltip_text = pokemon_name
		side.add_child(name_label)
	else:
		var selector := _make_pokemon_selector(relation, is_attacker)
		selector.custom_minimum_size = Vector2(0, 30)
		selector.add_theme_font_size_override("font_size", 14)
		side.add_child(selector)
	var detail_label := _make_label(details, 10, TEXT_SECONDARY)
	detail_label.tooltip_text = details
	side.add_child(detail_label)
	if hp_percent != null:
		side.add_child(_make_hp_bar(float(hp_percent)))
	return panel


func _make_hp_bar(hp_percent: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(hp_percent, 0.0, 100.0)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _make_stylebox(Color(0.015, 0.024, 0.038, 0.98), Color(0.08, 0.16, 0.23, 0.75), 4, 0.0, 0.0)
	var fill_color := Color(0.25, 0.78, 0.42, 1.0)
	if hp_percent <= 20.0:
		fill_color = Color(0.92, 0.25, 0.22, 1.0)
	elif hp_percent <= 50.0:
		fill_color = Color(0.92, 0.68, 0.16, 1.0)
	var fill := _make_stylebox(fill_color, fill_color.lightened(0.12), 4, 0.0, 0.0)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


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
	table.add_theme_stylebox_override("panel", _make_card_stylebox(PROFILE_BG, PROFILE_BORDER, 10, 8.0, 7.0))
	content.add_child(table)
	var table_box := VBoxContainer.new()
	table_box.clip_contents = true
	table_box.add_theme_constant_override("separation", 3)
	table.add_child(table_box)
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.025, 0.045, 0.072, 0.98), Color(0.16, 0.31, 0.48, 0.84), 6, 10.0, 2.0)
	)
	table_box.add_child(header_panel)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	header_panel.add_child(header)
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
	for result_index: int in range(results.size()):
		var result_value: Variant = results[result_index]
		if result_value is Dictionary:
			_add_move_result_row(result_value as Dictionary, defender, table_box, result_index)


func _make_table_header(text: String) -> Label:
	var label := _make_label(text.to_upper(), 9, Color(0.68, 0.76, 0.86, 1.0))
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _add_move_result_row(result: Dictionary, defender: Dictionary, parent: VBoxContainer, row_index: int) -> void:
	var primary_result_label := _get_primary_result_label(result, defender)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 54)
	panel.add_theme_stylebox_override("panel", _make_result_row_style(primary_result_label, row_index))

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
	var move_label := _make_label(_fallback_text(move_name, _t("battle.move.unknown")), 14, TEXT_PRIMARY)
	move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_box.add_child(move_label)

	var is_status_move: bool = _is_status_result(result)
	var percent_label: String = "" if is_status_move else _get_percent_label(result)
	var move_type := _get_move_type(result)
	var move_category := _get_move_category(result)
	var move_source := _get_move_source(result)
	if move_type != "" or move_category != "" or move_source != "":
		var meta_row := HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 5)
		move_box.add_child(meta_row)
		if move_type != "":
			meta_row.add_child(_make_move_type_badge(move_type))
		if move_category != "":
			meta_row.add_child(_make_move_category_label(move_category))
		if move_source != "":
			meta_row.add_child(_make_move_source_label(move_source))
	var percent := _make_label(percent_label if percent_label != "" else "--", 15, TEXT_ACCENT)
	percent.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	percent.size_flags_horizontal = Control.SIZE_SHRINK_END
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_row.add_child(percent)
	var ko_label := _make_result_badge(primary_result_label)
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


func _make_result_row_style(primary_result_label: String, row_index: int) -> StyleBoxFlat:
	var background := ROW_BG_ALT if row_index % 2 == 0 else ROW_BG
	var style := _make_stylebox(background, Color(0, 0, 0, 0), 7, 10.0, 6.0)
	style.border_width_left = 3
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = _get_result_border(primary_result_label)
	return style


func _make_move_type_badge(move_type: String) -> Label:
	var type_color: Color = TYPE_COLORS.get(move_type.to_lower(), PROFILE_BORDER)
	var label := _make_label(move_type.to_upper(), 8, Color(1.0, 1.0, 1.0, 0.96))
	label.custom_minimum_size = Vector2(48, 17)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(type_color.darkened(0.12), type_color.lightened(0.12), 8, 5.0, 1.0))
	return label


func _make_move_category_label(category: String) -> Label:
	var label := _make_label(category.to_upper(), 8, TEXT_MUTED)
	label.custom_minimum_size = Vector2(62, 17)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(Color(0.035, 0.05, 0.075, 0.92), Color(0.20, 0.28, 0.38, 0.75), 8, 5.0, 1.0))
	return label


func _make_move_source_label(source: String) -> Label:
	var provenance_key := source
	if source == "public_usage_prior":
		provenance_key = "aggregate_prior"
	var label := _make_label(_t("battle.calc.provenance.%s" % provenance_key).to_upper(), 8, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(56, 17)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 8, 5.0, 1.0))
	return label


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
		if warning in [
			"CALC_SCENARIO_ABILITY",
			"CALC_SCENARIO_ITEM",
			"CALC_SCENARIO_NATURE",
			"CALC_SCENARIO_EVS",
			"CALC_SCENARIO_IVS",
			"CALC_UNKNOWN_ITEM_NOT_INCLUDED",
		]:
			continue
		if warning != "":
			details.append(_warning_label(warning))
	if details.is_empty():
		return
	var notes_panel := PanelContainer.new()
	notes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_panel.add_theme_stylebox_override("panel", _make_stylebox(PROFILE_BG, PROFILE_BORDER, 6, 7.0, 5.0))
	content.add_child(notes_panel)
	warning_details_panel = notes_panel
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
			var detail_label := _make_label("-  %s" % detail, 11, TEXT_MUTED)
			detail_label.custom_minimum_size = Vector2(0, 20)
			detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_label.clip_text = false
			detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			notes_box.add_child(detail_label)


func _on_warning_details_pressed() -> void:
	warning_details_expanded = not warning_details_expanded
	_render_current_state()
	if warning_details_expanded:
		call_deferred("_scroll_warning_details_into_view")


func _scroll_warning_details_into_view() -> void:
	await get_tree().process_frame
	var scroll := get_node_or_null("CalcScroll") as ScrollContainer
	if scroll == null or not is_instance_valid(warning_details_panel):
		return
	scroll.ensure_control_visible(warning_details_panel)


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
	var compact_text := _get_compact_result_label(text)
	var colors := _get_result_badge_colors(compact_text)
	var label := _make_label(compact_text, 11, colors["text"])
	label.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 28)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_stylebox(colors["background"], colors["border"], 7, 7.0, 3.0))
	return label


func _get_result_badge_colors(text: String) -> Dictionary:
	var normalized := text.to_upper()
	if normalized == "OHKO":
		return {
			"text": Color(1.0, 0.91, 0.66, 1.0),
			"background": Color(0.28, 0.12, 0.035, 0.98),
			"border": Color(0.90, 0.57, 0.16, 0.95),
		}
	if normalized.contains("2HKO") and not normalized.begins_with("0%"):
		return {
			"text": Color(0.76, 0.91, 1.0, 1.0),
			"background": Color(0.035, 0.14, 0.25, 0.98),
			"border": Color(0.19, 0.55, 0.82, 0.92),
		}
	return {
		"text": TEXT_SECONDARY,
		"background": Color(0.035, 0.05, 0.075, 0.98),
		"border": Color(0.22, 0.31, 0.43, 0.80),
	}


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


func _add_live_assumption_controls(assumptions: Dictionary, _prior_provenance: String = "") -> void:
	is_syncing_assumption_controls = true
	live_ev_inputs.clear()
	live_ev_total_label = null
	item_assumption_input = null
	ability_assumption_input = null
	move_assumption_input = null
	catalog_results_box = null
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_card_stylebox(PROFILE_BG, Color(PROFILE_BORDER.r, PROFILE_BORDER.g, PROFILE_BORDER.b, 0.52), 9, 10.0, 8.0))
	content.add_child(panel)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var setup_row := HBoxContainer.new()
	setup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_row.add_theme_constant_override("separation", 6)
	box.add_child(setup_row)
	_add_sample_set_selector(setup_row)
	if not edited_assumption_fields.is_empty() or not field_scenario.is_empty():
		var reset_button := _make_assumption_reset_button()
		setup_row.add_child(reset_button)

	var primary_row := HBoxContainer.new()
	primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_row.clip_contents = true
	primary_row.add_theme_constant_override("separation", 4)
	box.add_child(primary_row)

	primary_row.add_child(_make_assumption_summary_button(
		_t("battle.calc.item"),
		_get_assumption_control_value(assumptions, SELECTOR_ITEM),
		SELECTOR_ITEM,
		_get_assumption_chip_label(assumptions, "item", _t("battle.calc.item_none"))
	))
	primary_row.add_child(_make_assumption_summary_button(
		_t("battle.calc.ability"),
		_get_assumption_control_value(assumptions, SELECTOR_ABILITY),
		SELECTOR_ABILITY,
		_get_assumption_chip_label(assumptions, "ability", _t("battle.calc.ability_unknown"))
	))
	primary_row.add_child(_make_assumption_summary_button(
		_t("battle.calc.nature"),
		_get_assumption_control_value(assumptions, SELECTOR_NATURE),
		SELECTOR_NATURE,
		_get_nature_chip_label(assumptions)
	))
	primary_row.add_child(_make_assumption_summary_button(
		_t("battle.calc.evs"),
		_get_assumption_control_value(assumptions, SELECTOR_EVS),
		SELECTOR_EVS,
		_get_evs_summary_chip_label(_as_dictionary(assumptions.get("evs", {})))
	))
	if active_subtab == SUBTAB_THEIR_DAMAGE:
		_add_opponent_move_controls(box, assumptions)
	if _is_current_ability_assumed():
		var ability_warning := _make_label(_t("battle.calc.assumed_ability_warning", {
			"ability": current_default_ability,
		}), 10, TEXT_ACCENT)
		ability_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_warning.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		box.add_child(ability_warning)
	elif current_default_ability_loading and str(assumptions.get("ability", "")).strip_edges() == "":
		box.add_child(_make_label(_t("battle.calc.loading_default_ability"), 10, TEXT_MUTED))

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


func _add_opponent_move_controls(parent: VBoxContainer, assumptions: Dictionary) -> void:
	var header := _make_label(_t("battle.calc.opponent_moves").to_upper(), 8, TEXT_MUTED)
	header.custom_minimum_size = Vector2(0, 14)
	parent.add_child(header)

	var moves := _as_array(assumptions.get("assumedMoves", []))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for slot in range(4):
		var move_name := str(moves[slot]).strip_edges() if slot < moves.size() else ""
		row.add_child(_make_move_slot_button(slot, move_name))


func _make_move_slot_button(slot: int, move_name: String) -> Button:
	var button := Button.new()
	button.text = move_name if move_name != "" else _t("battle.calc.add_move")
	button.tooltip_text = button.text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 10)
	var is_active := active_selector == SELECTOR_MOVE and active_move_slot == slot
	var border := CHIP_EDITED_BORDER if move_name != "" else CHIP_BORDER
	button.add_theme_color_override("font_color", TEXT_ACCENT if move_name != "" else TEXT_MUTED)
	button.add_theme_stylebox_override("normal", _make_stylebox(TAB_ACTIVE_BG if is_active else CHIP_BG, border, 6, 7.0, 3.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), border.lightened(0.12), 6, 7.0, 3.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, border.lightened(0.18), 6, 7.0, 3.0))
	button.pressed.connect(_on_move_slot_pressed.bind(slot))
	return button


func _on_move_slot_pressed(slot: int) -> void:
	if active_selector == SELECTOR_MOVE and active_move_slot == slot:
		_close_assumption_suggestions()
		return
	active_selector = SELECTOR_MOVE
	active_move_slot = slot
	var moves := _as_array(defender_assumptions.get("assumedMoves", []))
	selector_query = str(moves[slot]).strip_edges() if slot < moves.size() else ""
	selector_results = []
	selector_loading = true
	selector_error = ""
	_render_current_state()
	_request_active_catalog()

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


func _on_advanced_scenario_pressed() -> void:
	advanced_scenario_expanded = not advanced_scenario_expanded
	_render_current_state()


func _make_disclosure_button(text: String, expanded: bool, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s  %s" % ["-" if expanded else "+", text]
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 11)
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
	_apply_calcdex_dropdown_style(selector, 32.0, 11)
	return selector


func _on_field_scenario_selected(index: int, selector: OptionButton, key: String) -> void:
	var value := str(selector.get_item_metadata(index))
	if value == "":
		field_scenario.erase(key)
	else:
		field_scenario[key] = value
	matchup_selection_changed.emit()


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


func _make_assumption_reset_button() -> Button:
	var button := Button.new()
	button.text = _t("common.reset").to_upper()
	button.tooltip_text = _t("battle.calc.reset_setup_tooltip")
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(68, 26)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_ACCENT)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(Color(0.018, 0.029, 0.047, 0.76), Color(0.18, 0.29, 0.43, 0.72), 6, 8.0, 2.0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(Color(0.055, 0.086, 0.13, 0.98), Color(0.30, 0.48, 0.66, 0.92), 6, 8.0, 2.0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(Color(0.075, 0.10, 0.14, 0.98), TEXT_ACCENT.darkened(0.12), 6, 8.0, 2.0)
	)
	button.pressed.connect(_reset_live_assumptions)
	return button


func _get_catalog_assumption_value(assumptions: Dictionary, kind: String) -> String:
	var value: String = str(assumptions.get(kind, "")).strip_edges()
	return "" if value == "<null>" else value


func _make_assumption_summary_button(caption: String, value: String, editor_kind: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.tooltip_text = _fallback_text(tooltip, "%s: %s" % [caption, value])
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_active: bool = active_selector == editor_kind
	var is_edited: bool = bool(edited_assumption_fields.get(editor_kind, false))
	var chip_border: Color = CHIP_BORDER
	if is_edited:
		chip_border = CHIP_EDITED_BORDER
	var value_color: Color = TEXT_SECONDARY
	if is_active:
		value_color = TEXT_PRIMARY
	elif is_edited:
		value_color = TEXT_ACCENT
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if is_active else CHIP_BG, chip_border, 7, 8.0, 5.0)
	)
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), chip_border.lightened(0.12), 7, 8.0, 5.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, chip_border.lightened(0.18), 7, 8.0, 5.0))

	var labels := VBoxContainer.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.offset_left = 9.0
	labels.offset_top = 5.0
	labels.offset_right = -9.0
	labels.offset_bottom = -5.0
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_constant_override("separation", 1)
	button.add_child(labels)
	var caption_label := _make_label(caption.to_upper(), 8, TEXT_MUTED if not is_active else Color(0.65, 0.82, 0.94, 1.0))
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(caption_label)
	var value_label := _make_label(value, 12, value_color)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.tooltip_text = button.tooltip_text
	labels.add_child(value_label)
	button.pressed.connect(_on_assumption_summary_pressed.bind(editor_kind))
	return button


func _get_assumption_control_value(assumptions: Dictionary, editor_kind: String, prior_provenance: String = "") -> String:
	match editor_kind:
		SELECTOR_ITEM:
			var item := str(assumptions.get("item", "")).strip_edges()
			return _t("common.none") if item == "" or item == "<null>" else item
		SELECTOR_ABILITY:
			var ability := str(assumptions.get("ability", "")).strip_edges()
			return _t("common.none") if ability == "" or ability == "<null>" else ability
		SELECTOR_NATURE:
			if prior_provenance != "" and not bool(edited_assumption_fields.get("nature", false)):
				return _t("battle.calc.set_range")
			var nature := str(assumptions.get("nature", "")).strip_edges()
			return _localized_nature_name("Hardy" if nature == "" else nature)
		SELECTOR_EVS:
			var ev_total := _get_evs_total(_as_dictionary(assumptions.get("evs", {})))
			return _t("common.none") if ev_total == 0 else "%d / %d" % [ev_total, EV_TOTAL_LIMIT]
		_:
			return _t("common.unknown")


func _get_assumption_fallback_label(editor_kind: String) -> String:
	match editor_kind:
		SELECTOR_ITEM:
			return _t("battle.calc.item_none")
		SELECTOR_ABILITY:
			return _t("common.none")
		SELECTOR_NATURE:
			return _localized_nature_name("Hardy")
		SELECTOR_EVS:
			return _t("common.none")
		_:
			return ""


func _on_assumption_summary_pressed(editor_kind: String) -> void:
	if active_selector == editor_kind:
		_close_assumption_suggestions()
		_render_current_state()
		return
	active_selector = editor_kind
	active_move_slot = -1
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
		SELECTOR_ITEM, SELECTOR_ABILITY, SELECTOR_MOVE:
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
	if kind == SELECTOR_MOVE:
		var moves := _as_array(assumptions.get("assumedMoves", []))
		input.text = str(moves[active_move_slot]).strip_edges() if active_move_slot >= 0 and active_move_slot < moves.size() else ""
	else:
		input.text = _get_catalog_assumption_value(assumptions, kind)
	input.placeholder_text = _get_catalog_search_placeholder(kind)
	input.custom_minimum_size = Vector2(0, 24)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 11)
	input.focus_entered.connect(_on_catalog_assumption_focus_entered.bind(kind))
	input.focus_exited.connect(_on_catalog_assumption_focus_exited.bind(kind))
	input.text_changed.connect(_on_catalog_assumption_text_changed.bind(kind))
	row.add_child(input)

	var clear_button := _make_small_button(_t("common.clear") if kind == SELECTOR_MOVE else _t("common.none"), _on_catalog_assumption_clear_pressed.bind(kind))
	clear_button.custom_minimum_size = Vector2(46, 22)
	row.add_child(clear_button)

	if kind == SELECTOR_ITEM:
		item_assumption_input = input
	elif kind == SELECTOR_ABILITY:
		ability_assumption_input = input
	else:
		move_assumption_input = input

	catalog_results_box = VBoxContainer.new()
	catalog_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_results_box.clip_contents = true
	catalog_results_box.add_theme_constant_override("separation", 2)
	catalog_suggestions_box.add_child(catalog_results_box)
	_refresh_catalog_results()
	input.call_deferred("grab_focus")
	input.caret_column = input.text.length()


func _get_catalog_search_placeholder(kind: String) -> String:
	if kind == SELECTOR_ITEM:
		return _t("battle.calc.search_item")
	if kind == SELECTOR_ABILITY:
		return _t("battle.calc.search_ability")
	return _t("battle.calc.search_move")


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
	_mark_sample_set_custom()
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
	_mark_sample_set_custom()
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
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	_reset_to_current()


func show_assumption_catalog_loading(kind: String, query: String) -> void:
	if kind != active_selector:
		return
	selector_query = query
	selector_loading = true
	selector_error = ""
	selector_results = []
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_MOVE:
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
	elif kind == SELECTOR_MOVE:
		selector_results = _as_array(response.get("moves", []))
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_MOVE:
		_refresh_catalog_results()
	elif kind == SELECTOR_NATURE:
		_render_current_state()


func show_assumption_catalog_error(kind: String, message: String) -> void:
	if kind != active_selector:
		return
	selector_loading = false
	selector_error = _fallback_text(message, _t("battle.calc.error.assumptions"))
	selector_results = []
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_MOVE:
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
	if focus_owner == item_assumption_input or focus_owner == ability_assumption_input or focus_owner == move_assumption_input:
		return
	if catalog_suggestions_box != null and focus_owner != null and catalog_suggestions_box.is_ancestor_of(focus_owner):
		return
	_close_assumption_suggestions()


func _close_assumption_suggestions() -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = SELECTOR_NONE
	active_move_slot = -1
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
	_mark_sample_set_custom()
	if kind == SELECTOR_MOVE:
		var moves := _as_array(defender_assumptions.get("assumedMoves", [])).duplicate()
		if active_move_slot >= 0 and active_move_slot < moves.size():
			moves.remove_at(active_move_slot)
		if moves.is_empty():
			defender_assumptions.erase("assumedMoves")
		else:
			defender_assumptions["assumedMoves"] = moves
		edited_assumption_fields["assumedMoves"] = true
		_close_assumption_suggestions()
		_emit_defender_assumptions_changed()
		return
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
	_mark_sample_set_custom()
	if active_selector == SELECTOR_MOVE:
		var moves := _as_array(defender_assumptions.get("assumedMoves", [])).duplicate()
		if active_move_slot >= 0 and active_move_slot < moves.size():
			moves.remove_at(active_move_slot)
		moves.erase(calc_name)
		var insert_at: int = clampi(active_move_slot, 0, moves.size())
		moves.insert(insert_at, calc_name)
		if moves.size() > 4:
			moves.resize(4)
		defender_assumptions["assumedMoves"] = moves
		edited_assumption_fields["assumedMoves"] = true
		_close_assumption_suggestions()
		_emit_defender_assumptions_changed()
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

	catalog_results_box.visible = active_selector == SELECTOR_ITEM or active_selector == SELECTOR_ABILITY or active_selector == SELECTOR_MOVE
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
		var subtitle := ""
		if active_selector == SELECTOR_MOVE:
			var move_type := str(result.get("type", "")).strip_edges()
			var category := str(result.get("category", "")).strip_edges()
			subtitle = "· %s / %s" % [move_type.capitalize(), category.capitalize()]
		catalog_results_box.add_child(_make_selector_result_button(
			_fallback_text(name, _t("common.unknown")),
			subtitle,
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
	if kind == SELECTOR_MOVE:
		return move_assumption_input
	return null


func _get_selector_species() -> String:
	if last_response.is_empty():
		return ""
	var attacker: Dictionary = _as_dictionary(last_response.get("attacker", {}))
	var defender: Dictionary = _as_dictionary(last_response.get("defender", {}))
	var opponent: Dictionary = attacker if str(attacker.get("relation", "")) == "opponent" else defender
	for key: String in ["speciesId", "species", "displayName", "name"]:
		var value: String = str(opponent.get(key, "")).strip_edges()
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


func _apply_calcdex_dropdown_style(selector: OptionButton, minimum_height: float, font_size: int) -> void:
	if selector == null:
		return
	selector.custom_minimum_size.y = maxf(selector.custom_minimum_size.y, minimum_height)
	selector.focus_mode = Control.FOCUS_ALL
	selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selector.alignment = HORIZONTAL_ALIGNMENT_LEFT
	selector.clip_text = true
	selector.add_theme_font_size_override("font_size", font_size)
	selector.add_theme_color_override("font_color", TEXT_PRIMARY)
	selector.add_theme_color_override("font_hover_color", Color.WHITE)
	selector.add_theme_color_override("font_pressed_color", Color.WHITE)
	selector.add_theme_color_override("font_focus_color", Color.WHITE)
	selector.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED, 0.48))
	selector.add_theme_constant_override("arrow_margin", 10)
	selector.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	selector.add_theme_stylebox_override(
		"normal",
		_make_dropdown_button_style(DROPDOWN_BG, DROPDOWN_BORDER)
	)
	selector.add_theme_stylebox_override(
		"hover",
		_make_dropdown_button_style(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER)
	)
	selector.add_theme_stylebox_override(
		"pressed",
		_make_dropdown_button_style(DROPDOWN_PRESSED_BG, DROPDOWN_FOCUS_BORDER)
	)
	selector.add_theme_stylebox_override(
		"focus",
		_make_dropdown_button_style(DROPDOWN_BG, DROPDOWN_FOCUS_BORDER, 2)
	)
	selector.add_theme_stylebox_override(
		"disabled",
		_make_dropdown_button_style(Color(0.014, 0.024, 0.039, 0.76), Color(0.12, 0.19, 0.27, 0.6))
	)

	var popup := selector.get_popup()
	if popup == null:
		return
	popup.transparent_bg = true
	popup.borderless = true
	popup.add_theme_font_size_override("font_size", maxi(font_size, 12))
	popup.add_theme_color_override("font_color", TEXT_PRIMARY)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED, 0.48))
	popup.add_theme_color_override("font_separator_color", DROPDOWN_HOVER_BORDER)
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", _make_dropdown_popup_style())
	popup.add_theme_stylebox_override(
		"hover",
		_make_dropdown_popup_item_style(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER)
	)
	popup.add_theme_stylebox_override(
		"separator",
		_make_dropdown_popup_item_style(Color.TRANSPARENT, Color(0.16, 0.31, 0.45, 0.58), 0)
	)
	popup.add_theme_icon_override("radio_checked", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", DROPDOWN_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", DROPDOWN_RADIO_UNCHECKED)


func _make_dropdown_button_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_stylebox(background, border, 7, 10.0, 5.0)
	style.set_border_width_all(border_width)
	style.content_margin_right = 30.0
	return style


func _make_dropdown_popup_style() -> StyleBoxFlat:
	var style := _make_dropdown_popup_item_style(DROPDOWN_POPUP_BG, DROPDOWN_HOVER_BORDER, 9)
	style.content_margin_left = 5.0
	style.content_margin_top = 6.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


func _make_dropdown_popup_item_style(background: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 5.0
	style.content_margin_top = 4.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 4.0
	return style


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


func _make_card_stylebox(
	bg_color: Color,
	border_color: Color,
	radius: int,
	horizontal_margin: float,
	vertical_margin: float
) -> StyleBoxFlat:
	var style := _make_stylebox(bg_color, border_color, radius, horizontal_margin, vertical_margin)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
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
	var level := _format_level_value(level_value)
	return _t("battle.calc.level", {"level": level}) if level != "" else _t("battle.calc.level_unknown")


func _format_level_value(level_value: Variant) -> String:
	if typeof(level_value) == TYPE_INT or typeof(level_value) == TYPE_FLOAT:
		return str(roundi(float(level_value)))
	var text := str(level_value).strip_edges()
	if text.is_valid_float():
		return str(roundi(float(text)))
	return text


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
	return _join_string_array([_get_move_type(result), _get_move_category(result)], " / ")


func _get_move_type(result: Dictionary) -> String:
	var move_value: Variant = result.get("move", {})
	var move: Dictionary = {}
	if move_value is Dictionary:
		move = move_value as Dictionary
	return _first_non_empty_string(result, move, ["moveType", "type"])


func _get_move_category(result: Dictionary) -> String:
	var move_value: Variant = result.get("move", {})
	var move: Dictionary = {}
	if move_value is Dictionary:
		move = move_value as Dictionary
	return _first_non_empty_string(result, move, ["moveCategory", "category"])


func _get_move_source(result: Dictionary) -> String:
	var move_value: Variant = result.get("move", {})
	if move_value is Dictionary:
		return str((move_value as Dictionary).get("source", "")).strip_edges()
	return str(result.get("moveSource", "")).strip_edges()


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
	if not assumptions.has("evs"):
		assumptions["evs"] = {}
	if not assumptions.has("ivs"):
		assumptions["ivs"] = {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}
	return assumptions


func _get_nature_chip_label(assumptions: Dictionary, prior_provenance: String = "") -> String:
	if prior_provenance != "" and not bool(edited_assumption_fields.get("nature", false)):
		return "%s · %s" % [_t("battle.calc.set_range"), _t("battle.calc.provenance.%s" % prior_provenance)]
	var canonical_nature := str(assumptions.get("nature", "")).strip_edges()
	if canonical_nature == "":
		return "%s · %s" % [_t("common.unknown"), _t("battle.calc.provenance.unknown")]
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
	if not bool(edited_assumption_fields.get(field_name, false)):
		return label
	return "%s* · %s" % [label, _t("battle.calc.provenance.user_scenario")]


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
		if _is_meaningful_text(text):
			return text
	for key: String in keys:
		var text := str(secondary.get(key, "")).strip_edges()
		if _is_meaningful_text(text):
			return text
	return ""


func _is_meaningful_text(value: String) -> bool:
	return value != "" and value.to_lower() not in ["<null>", "null", "<nil>", "nil"]


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
