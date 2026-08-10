extends MarginContainer

class_name BattleDamageCalcPanel

const CALCDEX_SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/photo_mode_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_unchecked.svg")
signal defender_assumptions_changed(assumptions: Dictionary, edited_fields: Dictionary)
signal assumption_catalog_requested(kind: String, query: String, species: String)
signal sample_set_catalog_requested(species: String, format_id: String)
signal forme_catalog_requested(relation: String, species: String, format_id: String)
signal default_ability_requested(species: String)
signal viewer_ability_catalog_requested(species: String)
signal matchup_selection_changed()
signal move_scenarios_changed(move_scenarios: Array)
signal team_pokemon_hovered(relation: String, pokemon_data: Dictionary, slot_rect: Rect2)
signal team_pokemon_unhovered(relation: String)

const SURFACE_CANVAS := Color("#050a10")
const SURFACE_PANEL := Color("#0b1520")
const SURFACE_RAISED := Color("#101d2a")
const BORDER_NEUTRAL := Color("#26394d")
const INTERACTION_ACCENT := Color("#8ccbe8")
const LABEL_NEUTRAL := Color("#91a0b4")
const WARNING_ACCENT := Color("#f0b84b")
const DANGER_ACCENT := Color("#f06b5d")

const TEXT_PRIMARY := Color("#f2f0ea")
const TEXT_SECONDARY := Color("#a8b4c2")
const TEXT_MUTED := Color("#718096")
const TEXT_ACCENT := INTERACTION_ACCENT
const TEXT_ERROR := DANGER_ACCENT
const DAMAGE_TEXT := Color("#c7e0f7")
const STAGE_POSITIVE := Color("#55d68b")
const STAGE_NEGATIVE := DANGER_ACCENT
const ROW_BG := Color(0.043, 0.082, 0.125, 0.98)
const ROW_BG_ALT := Color(0.063, 0.114, 0.165, 0.98)
const ROW_BORDER := Color(0.15, 0.23, 0.31, 0.88)
const PROFILE_BG := Color(0.043, 0.082, 0.125, 0.96)
const PROFILE_BORDER := Color(0.19, 0.28, 0.37, 0.86)
const HERO_BG := Color(0.047, 0.102, 0.149, 0.98)
const HERO_BORDER := Color(0.27, 0.48, 0.62, 0.92)
const CHIP_BG := Color(0.063, 0.114, 0.165, 0.98)
const CHIP_BORDER := Color(0.22, 0.32, 0.41, 0.90)
const CHIP_EDITED_BORDER := Color(0.78, 0.58, 0.31, 0.92)
const KO_BORDER := Color(0.72, 0.43, 0.26, 0.90)
const TAB_BG := Color(0.043, 0.082, 0.125, 0.96)
const TAB_ACTIVE_BG := Color(0.086, 0.157, 0.227, 0.99)
const TAB_BORDER := Color(0.17, 0.25, 0.34, 0.92)
const DROPDOWN_BG := Color(0.055, 0.102, 0.149, 0.99)
const DROPDOWN_HOVER_BG := Color(0.078, 0.157, 0.216, 0.99)
const DROPDOWN_PRESSED_BG := Color(0.094, 0.184, 0.251, 1.0)
const DROPDOWN_POPUP_BG := Color(0.027, 0.063, 0.102, 0.995)
const DROPDOWN_BORDER := Color(0.18, 0.29, 0.38, 0.94)
const DROPDOWN_HOVER_BORDER := Color(0.42, 0.68, 0.80, 0.98)
const DROPDOWN_FOCUS_BORDER := INTERACTION_ACCENT
const CONDITION_GLOBAL_ACCENT := Color("#70b8d8")
const CONDITION_OWN_ACCENT := Color("#42beeb")
const CONDITION_OPPONENT_ACCENT := Color("#e7a93d")
const CONFIRMED_ACCENT := STAGE_POSITIVE
const MANUAL_ACCENT := Color("#c9a66b")
const ITEM_LABEL_ACCENT := LABEL_NEUTRAL
const ABILITY_LABEL_ACCENT := LABEL_NEUTRAL
const NATURE_LABEL_ACCENT := LABEL_NEUTRAL
const EV_LABEL_ACCENT := Color("#8bb9cf")
const OFFENSE_LABEL_ACCENT := Color("#d59a88")
const DEFENSE_LABEL_ACCENT := Color("#83aecf")
const SPEED_LABEL_ACCENT := Color("#8ebd9b")
# Extreme overkill is valid when a high-level attacker hits a low-level target
# (for example, a wild encounter). Keep malformed-value protection well above
# that range so legitimate OHKO projections are not rendered as "Calc issue".
const SUSPICIOUS_PERCENT_LIMIT := 100000.0
const DAMAGE_COLUMN_WIDTH := 132.0
const KO_COLUMN_WIDTH := 92.0
const CONFIRMED_INFORMATION_ENVELOPE_DESCRIPTION := "Confirmed-information envelope across unknown opponent stats."
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
const INSPECTOR_SET := "set"
const INSPECTOR_FIELD := "field"
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
const EV_INPUT_GROUPS := [
	{"label": "battle.calc.ev_group_bulk", "stats": ["hp", "def", "spd"]},
	{"label": "battle.calc.ev_group_offense", "stats": ["atk", "spa", "spe"]},
]
const BOOST_STAT_KEYS := ["atk", "def", "spa", "spd", "spe"]
const FIELD_SIDE_CONDITIONS := [
	{"suffix": "Reflect", "label_key": "battle.calc.condition.reflect"},
	{"suffix": "LightScreen", "label_key": "battle.calc.condition.light_screen"},
	{"suffix": "AuroraVeil", "label_key": "battle.calc.condition.aurora_veil"},
]
const FIELD_SIDE_HAZARDS := [
	{"suffix": "StealthRock", "label_key": "battle.field.effect.stealth_rock"},
]
const FIELD_WEATHER_VALUES := ["", "Rain", "Sun", "Sand", "Hail", "Snow"]
const FIELD_TERRAIN_VALUES := ["", "Electric", "Grassy", "Misty", "Psychic"]
const POKEMON_STATUS_VALUES := ["", "brn", "par", "psn", "tox", "slp", "frz"]

var content: VBoxContainer
var render_target: VBoxContainer

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
var live_ev_bars: Dictionary = {}
var live_ev_total_label: Label
var live_ev_total_bar: ProgressBar
var live_ev_focus_stat := ""
var live_ev_focus_caret := -1
var item_assumption_input: LineEdit
var ability_assumption_input: LineEdit
var nature_assumption_input: LineEdit
var move_assumption_input: LineEdit
var catalog_suggestions_box: VBoxContainer
var catalog_results_box: VBoxContainer
var inline_move_result_boxes: Dictionary = {}
var inline_move_result_panels: Dictionary = {}
var result_summary_panels: Dictionary = {}
var result_disclosure_buttons: Dictionary = {}
var result_row_panels: Dictionary = {}
var expanded_result_key := ""
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
var viewer_boost_scenarios: Dictionary = {}
var viewer_ability_scenarios: Dictionary = {}
var viewer_ability_catalogs: Dictionary = {}
var viewer_ability_catalog_loading := false
var battle_state_scenarios: Dictionary = {}
var viewer_stats_by_ref: Dictionary = {}
var advanced_scenario_expanded := true
var warning_details_expanded := false
var warning_details_panel: Control
var sample_set_options: Array[Dictionary] = []
var sample_set_species := ""
var sample_set_format_id := ""
var sample_set_loading := false
var sample_set_error := ""
var selected_sample_set_id := ""
var current_default_ability := ""
var current_default_ability_species := ""
var current_default_ability_loading := false
var species_scenarios: Dictionary = {}
var forme_catalogs: Dictionary = {}
var forme_menu_buttons: Dictionary = {}
var active_inspector_tab := INSPECTOR_SET
var selected_move_index := 0
var move_scenarios: Dictionary = {}
var pending_move_index := -1
var is_clearing_content := false


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
	content.add_theme_constant_override("separation", 6)
	_apply_calcdex_scroll_style()
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
	species_scenarios.clear()
	forme_catalogs.clear()
	forme_menu_buttons.clear()
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_response = {}
	last_error = ""
	active_subtab = SUBTAB_YOUR_DAMAGE
	active_inspector_tab = INSPECTOR_SET
	selected_move_index = 0
	move_scenarios.clear()
	viewer_boost_scenarios.clear()
	pending_move_index = -1
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
	pending_move_index = -1
	_render_current_state()


func show_response(response: Dictionary) -> void:
	is_loading = false
	loading_attacker_name = ""
	loading_defender_name = ""
	last_error = ""
	pending_move_index = -1

	if not bool(response.get("success", false)):
		last_response = {}
		last_error = str(response.get("error", _t("battle.calc.error.failed")))
	elif str(response.get("direction", "")) != str(get_matchup_selection().get("direction", "")):
		last_response = {}
		last_error = _t("battle.calc.error.direction_mismatch")
	else:
		last_response = response
		_reconcile_move_scenarios(_as_array(response.get("results", [])))

	if _is_catalog_search_active():
		return
	_render_current_state()


func set_defender_assumptions(assumptions: Dictionary, edited_fields: Dictionary = {}) -> void:
	defender_assumptions = _duplicate_dictionary(assumptions)
	edited_assumption_fields = _duplicate_dictionary(edited_fields)
	var legacy_status := str(defender_assumptions.get("status", "")).strip_edges().to_lower()
	if legacy_status in POKEMON_STATUS_VALUES and legacy_status != "":
		field_scenario["opponentStatus"] = legacy_status
	defender_assumptions.erase("status")
	edited_assumption_fields.erase("status")
	if _is_catalog_search_active():
		return
	if is_inside_tree():
		_render_current_state()


func set_knowledge_snapshot(snapshot: Dictionary) -> void:
	var previous_opponent_ref := selected_opponent_ref
	knowledge_snapshot = snapshot.duplicate(true)
	selected_viewer_ref = _resolve_selected_ref("viewer", selected_viewer_ref)
	selected_opponent_ref = _resolve_selected_ref("opponent", selected_opponent_ref)
	_prune_viewer_boost_scenarios()
	_prune_species_scenarios()
	_clear_confirmed_status_scenarios()
	if previous_opponent_ref != "" and selected_opponent_ref != previous_opponent_ref:
		_clear_sample_sets()
	_request_sample_sets_if_needed()
	_refresh_current_scenario()
	if _is_catalog_search_active():
		return
	if is_inside_tree():
		_render_current_state()


func set_viewer_stats_by_ref(stats_by_ref: Dictionary) -> void:
	viewer_stats_by_ref = stats_by_ref.duplicate(true)


func close_assumption_popover() -> void:
	_flush_pending_assumption_changes()
	if assumption_change_timer != null:
		assumption_change_timer.stop()
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	live_ev_inputs.clear()
	live_ev_bars.clear()
	live_ev_total_label = null
	live_ev_total_bar = null
	live_ev_focus_stat = ""
	live_ev_focus_caret = -1
	item_assumption_input = null
	ability_assumption_input = null
	nature_assumption_input = null
	move_assumption_input = null
	catalog_suggestions_box = null
	catalog_results_box = null
	inline_move_result_boxes.clear()
	inline_move_result_panels.clear()
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
	render_target = content
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
		and active_selector in [SELECTOR_ITEM, SELECTOR_ABILITY, SELECTOR_NATURE, SELECTOR_MOVE]
	)


func _render_your_damage_response(response: Dictionary) -> void:
	var attacker: Dictionary = _as_dictionary(response.get("attacker", {}))
	var defender: Dictionary = _as_dictionary(response.get("defender", {}))
	var viewer := attacker if str(attacker.get("relation", "")) == "viewer" else defender
	var opponent := attacker if str(attacker.get("relation", "")) == "opponent" else defender
	var workspace := _make_workspace_columns()
	var overview: VBoxContainer = workspace.get("overview") as VBoxContainer
	var inspector: VBoxContainer = workspace.get("inspector") as VBoxContainer
	render_target = overview
	_add_profile_summary(
		_get_pokemon_label(viewer, _t("battle.calc.your_pokemon")),
		_get_pokemon_label(opponent, _t("battle.calc.opponent")),
		_get_hp_percent_label(opponent),
		_get_level_label(opponent),
		_get_boosts_label(viewer),
		_get_hp_percent_label(viewer),
		_get_level_label(viewer),
		str(viewer.get("species", "")),
		str(opponent.get("species", "")),
		_get_defender_hp_percent(viewer),
		_get_defender_hp_percent(opponent),
		_get_boosts_label(opponent),
		_get_effective_pokemon_status("own"),
		_get_effective_pokemon_status("opponent")
	)
	var assumptions := _get_display_assumptions(opponent)
	var results: Array = _as_array(response.get("results", []))
	if str(response.get("direction", "")) == "opponent-to-own":
		_add_editable_opponent_move_results_table(results, defender)
	elif results.is_empty():
		_add_status(_fallback_text(str(response.get("emptyReason", "")), _t("battle.calc.no_results")), TEXT_SECONDARY)
	else:
		_add_move_results_table(results, defender)

	render_target = inspector
	_add_inspector_tabs()
	match active_inspector_tab:
		INSPECTOR_SET:
			_add_viewer_stat_grid()
			_add_opponent_setup_card(assumptions, _get_opponent_calculated_stats(results))
		INSPECTOR_FIELD:
			_add_showdex_condition_controls(assumptions)
		_:
			_add_viewer_stat_grid()
			_add_opponent_setup_card(assumptions, _get_opponent_calculated_stats(results))
	render_target = content


func _make_workspace_columns() -> Dictionary:
	var workspace := HBoxContainer.new()
	workspace.name = "CalcdexWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.clip_contents = true
	workspace.add_theme_constant_override("separation", 14)
	content.add_child(workspace)

	var overview := VBoxContainer.new()
	overview.name = "CalcdexOverview"
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview.size_flags_stretch_ratio = 1.38
	overview.clip_contents = true
	overview.add_theme_constant_override("separation", 9)
	workspace.add_child(overview)

	var inspector_panel := PanelContainer.new()
	inspector_panel.name = "CalcdexInspectorPanel"
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_stretch_ratio = 1.0
	inspector_panel.clip_contents = true
	inspector_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_CANVAS, 0.92), Color(BORDER_NEUTRAL, 0.92), 9, 12.0, 10.0)
	)
	workspace.add_child(inspector_panel)
	var inspector := VBoxContainer.new()
	inspector.name = "CalcdexInspector"
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.clip_contents = true
	inspector.add_theme_constant_override("separation", 9)
	inspector_panel.add_child(inspector)
	return {"overview": overview, "inspector": inspector}


func _add_inspector_tabs() -> void:
	var row := HBoxContainer.new()
	row.name = "CalcdexInspectorTabs"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	_add_render_child(row)
	row.add_child(_make_inspector_tab_button(_t("battle.calc.inspector.set"), INSPECTOR_SET))
	row.add_child(_make_inspector_tab_button(_t("battle.calc.inspector.field"), INSPECTOR_FIELD))


func _make_inspector_tab_button(label: String, tab_id: String) -> Button:
	var button := Button.new()
	button.name = "InspectorTab%s" % tab_id.capitalize()
	button.text = label.to_upper()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 30)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_PRIMARY if active_inspector_tab == tab_id else TEXT_MUTED)
	button.add_theme_stylebox_override("normal", _make_stylebox(TAB_ACTIVE_BG if active_inspector_tab == tab_id else TAB_BG, TEXT_ACCENT if active_inspector_tab == tab_id else TAB_BORDER, 6, 6.0, 2.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER, 6, 6.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, TEXT_ACCENT, 6, 6.0, 2.0))
	button.pressed.connect(_on_inspector_tab_pressed.bind(tab_id))
	return button


func _on_inspector_tab_pressed(tab_id: String) -> void:
	if tab_id not in [INSPECTOR_SET, INSPECTOR_FIELD] or active_inspector_tab == tab_id:
		return
	close_assumption_popover()
	active_inspector_tab = tab_id
	_render_current_state()


func _add_render_child(node: Control) -> void:
	(render_target if render_target != null else content).add_child(node)


func _clear_content() -> void:
	is_clearing_content = true
	render_target = content
	warning_details_panel = null
	result_summary_panels.clear()
	result_disclosure_buttons.clear()
	result_row_panels.clear()
	forme_menu_buttons.clear()
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	is_clearing_content = false


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
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 12)
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
	expanded_result_key = ""
	_clear_move_scenarios()
	active_subtab = SUBTAB_YOUR_DAMAGE
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _on_their_damage_tab_pressed() -> void:
	if active_subtab == SUBTAB_THEIR_DAMAGE:
		return
	close_assumption_popover()
	expanded_result_key = ""
	_clear_move_scenarios()
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


func get_species_scenario() -> Dictionary:
	var result := {}
	for relation: String in ["viewer", "opponent"]:
		var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
		var selected_species := str(species_scenarios.get(pokemon_ref, "")).strip_edges()
		var snapshot_species := _get_snapshot_species(pokemon_ref)
		if selected_species != "" and _normalize_move_name(selected_species) != _normalize_move_name(snapshot_species):
			result[relation] = selected_species
	return result


func get_viewer_scenario() -> Dictionary:
	var boosts := _as_dictionary(viewer_boost_scenarios.get(selected_viewer_ref, {}))
	var scenario: Dictionary = {}
	if not boosts.is_empty():
		scenario["boosts"] = boosts.duplicate(true)
	var ability := str(viewer_ability_scenarios.get(selected_viewer_ref, "")).strip_edges()
	if ability != "":
		scenario["ability"] = ability
	return scenario


func get_battle_state_scenario() -> Dictionary:
	var viewer_state := _as_dictionary(battle_state_scenarios.get(selected_viewer_ref, {}))
	var opponent_state := _as_dictionary(battle_state_scenarios.get(selected_opponent_ref, {}))
	return {
		"viewer": _get_public_battle_state(viewer_state),
		"opponent": _get_public_battle_state(opponent_state),
	}


func _get_public_battle_state(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in state.keys():
		var name := str(key)
		if name.begins_with("_"):
			continue
		result[name] = state[key]
	return result


func show_forme_catalog_response(relation: String, species: String, response: Dictionary) -> void:
	var key := _get_forme_catalog_key(relation)
	if key == "" or _normalize_move_name(species) != _normalize_move_name(_get_snapshot_species_for_relation(relation)):
		return
	var options: Array[Dictionary] = []
	for value: Variant in _as_array(response.get("forms", [])):
		var option := _as_dictionary(value)
		var name := str(option.get("name", "")).strip_edges()
		if name == "" or name.length() > 128:
			continue
		options.append({"id": str(option.get("id", "")), "name": name})
	forme_catalogs[key] = {"loading": false, "options": options, "error": ""}
	_refresh_forme_menu(relation)


func show_forme_catalog_error(relation: String, species: String, message: String) -> void:
	var key := _get_forme_catalog_key(relation)
	if key == "" or _normalize_move_name(species) != _normalize_move_name(_get_snapshot_species_for_relation(relation)):
		return
	forme_catalogs[key] = {"loading": false, "options": [], "error": message.strip_edges()}
	_refresh_forme_menu(relation)


func get_field_scenario() -> Dictionary:
	var payload: Dictionary = {}
	for key: String in ["weather", "terrain"]:
		var value := str(field_scenario.get(key, "")).strip_edges()
		if value != "":
			payload[key] = value
	var target_relation := _get_condition_target_relation()
	var target_status := str(field_scenario.get("%sStatus" % target_relation, "")).strip_edges().to_lower()
	if target_status in POKEMON_STATUS_VALUES and target_status != "":
		payload["defenderStatus"] = target_status
	for condition: Dictionary in FIELD_SIDE_CONDITIONS:
		var suffix := str(condition.get("suffix", ""))
		if bool(field_scenario.get("%s%s" % [target_relation, suffix], false)):
			payload["defender%s" % suffix] = true
	for condition: Dictionary in FIELD_SIDE_HAZARDS:
		var suffix := str(condition.get("suffix", ""))
		if bool(field_scenario.get("%s%s" % [target_relation, suffix], false)):
			payload["defender%s" % suffix] = true
	var spikes := clampi(int(field_scenario.get("%sSpikes" % target_relation, 0)), 0, 3)
	if spikes > 0:
		payload["defenderSpikes"] = spikes
	return payload


func get_move_scenarios() -> Array:
	var payload: Array = []
	var indexes: Array = move_scenarios.keys()
	indexes.sort()
	for index_value: Variant in indexes:
		var scenario := _as_dictionary(move_scenarios.get(index_value, {}))
		if scenario.is_empty():
			continue
		payload.append({
			"moveIndex": int(scenario.get("moveIndex", index_value)),
			"moveName": str(scenario.get("moveName", "")),
			"useZ": bool(scenario.get("useZ", false)),
			"isCrit": bool(scenario.get("isCrit", false)),
		})
	return payload


func _reconcile_move_scenarios(results: Array) -> void:
	var reconciled: Dictionary = {}
	for index: int in range(results.size()):
		var result := _as_dictionary(results[index])
		var move_name := _get_move_name(result)
		var existing := _as_dictionary(move_scenarios.get(index, {}))
		if _normalize_move_name(str(existing.get("moveName", ""))) != _normalize_move_name(move_name):
			var response_options := _as_dictionary(_as_dictionary(result.get("move", {})).get("options", {}))
			existing = {
				"moveIndex": index,
				"moveName": move_name,
				"useZ": bool(response_options.get("useZ", false)),
				"isCrit": bool(response_options.get("isCrit", false)),
			}
		if bool(existing.get("useZ", false)) or bool(existing.get("isCrit", false)):
			reconciled[index] = existing
	move_scenarios = reconciled
	selected_move_index = clampi(selected_move_index, 0, maxi(results.size() - 1, 0))


func _clear_move_scenarios() -> void:
	move_scenarios.clear()
	pending_move_index = -1
	selected_move_index = 0


func _get_condition_target_relation() -> String:
	return "own" if active_subtab == SUBTAB_THEIR_DAMAGE else "opponent"


func _clear_sample_sets() -> void:
	sample_set_options.clear()
	sample_set_species = ""
	sample_set_format_id = ""
	sample_set_loading = false
	sample_set_error = ""
	selected_sample_set_id = ""


func _request_sample_sets_if_needed() -> void:
	var species := _get_selected_opponent_species()
	var format_id := _get_sample_set_format_id()
	if (
		species == ""
		or (
			species.to_lower() == sample_set_species.to_lower()
			and format_id == sample_set_format_id
		)
	):
		return
	sample_set_options.clear()
	sample_set_species = species
	sample_set_format_id = format_id
	sample_set_loading = true
	sample_set_error = ""
	selected_sample_set_id = ""
	sample_set_catalog_requested.emit(species, format_id)


func _get_sample_set_format_id() -> String:
	var format := _as_dictionary(knowledge_snapshot.get("format", {}))
	var format_key := str(format.get("formatKey", "")).strip_edges().to_lower()
	if format_key in ["aether-ou", "ranked-aether-ou"]:
		return "aether-ou"
	return "gen9nationaldex"


func show_sample_set_catalog_response(species: String, response: Dictionary) -> void:
	if species.to_lower() != sample_set_species.to_lower():
		return
	sample_set_loading = false
	sample_set_error = ""
	var valid_envelope := (
		int(response.get("schemaVersion", 0)) == 1
		and str(response.get("formatId", "")) == sample_set_format_id
		and str(response.get("engineFormatId", "")) == "gen9nationaldex"
		and str(response.get("dataFormatId", "")) == "gen9nationaldex"
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
	if _get_known_opponent_value("status") != "":
		defender_assumptions.erase("status")
		edited_assumption_fields.erase("status")


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
	selector.name = "SampleSetSelector"
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
	_apply_calcdex_dropdown_style(selector, 36.0, 12)
	selector.add_theme_constant_override("arrow_margin", 12)
	if selected_sample_set_id != "" or not edited_assumption_fields.is_empty() or not field_scenario.is_empty():
		selector.add_theme_color_override("font_color", TEXT_ACCENT)
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
	advanced_scenario_expanded = true
	active_selector = SELECTOR_NONE
	active_move_slot = -1
	_clear_move_scenarios()
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
		defender_assumptions["replaceMoves"] = true
		edited_assumption_fields["assumedMoves"] = true
		edited_assumption_fields["replaceMoves"] = true
	selected_sample_set_id = str(option.get("id", ""))
	active_selector = SELECTOR_NONE
	active_move_slot = -1
	_clear_move_scenarios()
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
	selector.name = "ViewerPokemonSelector" if relation == "viewer" else "OpponentPokemonSelector"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = _t("battle.calc.attacker_selector" if is_attacker else "battle.calc.defender_selector")
	var collection: Array = _as_array(knowledge_snapshot.get("viewerPokemon" if relation == "viewer" else "opponentPokemon", []))
	var selected_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	for entry_value: Variant in collection:
		var entry := _as_dictionary(entry_value)
		if entry.is_empty():
			continue
		var identity := _as_dictionary(entry.get("identity", {}))
		if str(identity.get("state", "")) != "known" or str(identity.get("value", "")).strip_edges() == "":
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
	_on_team_icon_pressed(relation, pokemon_ref)


func _on_team_icon_pressed(relation: String, pokemon_ref: String) -> void:
	if relation not in ["viewer", "opponent"] or pokemon_ref == "":
		return
	if _resolve_selected_ref(relation, pokemon_ref) != pokemon_ref:
		return
	if relation == "viewer":
		if pokemon_ref == selected_viewer_ref:
			return
		selected_viewer_ref = pokemon_ref
	else:
		if pokemon_ref == selected_opponent_ref:
			return
		_clear_sample_sets()
		selected_opponent_ref = pokemon_ref
		_request_sample_sets_if_needed()
	expanded_result_key = ""
	_clear_move_scenarios()
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _add_team_selector_strips() -> void:
	var panel := PanelContainer.new()
	panel.name = "TeamSelectorPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_PANEL, 0.96), Color(BORDER_NEUTRAL, 0.86), 8, 6.0, 4.0)
	)
	_add_render_child(panel)
	var matchup_strip := HBoxContainer.new()
	matchup_strip.name = "MatchupTeamStrip"
	matchup_strip.custom_minimum_size = Vector2(0, 36)
	matchup_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup_strip.clip_contents = true
	matchup_strip.add_theme_constant_override("separation", 4)
	panel.add_child(matchup_strip)
	matchup_strip.add_child(_make_team_selector_row("viewer"))
	var separator := _make_label("VS", 8, TEXT_MUTED)
	separator.custom_minimum_size = Vector2(18, 0)
	separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	matchup_strip.add_child(separator)
	matchup_strip.add_child(_make_team_selector_row("opponent"))


func _make_team_selector_row(relation: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ViewerTeamStrip" if relation == "viewer" else "OpponentTeamStrip"
	row.custom_minimum_size = Vector2(0, 34)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 3)
	var accent := CONDITION_OWN_ACCENT if relation == "viewer" else CONDITION_OPPONENT_ACCENT
	var label_key := "battle.calc.your_team" if relation == "viewer" else "battle.calc.opponent_team"
	var label := _make_label(_t(label_key).to_upper(), 8, Color(accent, 0.94))
	label.custom_minimum_size = Vector2(48, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var icons := HBoxContainer.new()
	icons.name = "ViewerTeamIcons" if relation == "viewer" else "OpponentTeamIcons"
	icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icons.alignment = BoxContainer.ALIGNMENT_END
	icons.add_theme_constant_override("separation", 2)
	row.add_child(icons)
	var collection := _as_array(knowledge_snapshot.get("viewerPokemon" if relation == "viewer" else "opponentPokemon", []))
	for index in range(mini(collection.size(), 6)):
		icons.add_child(_make_team_icon_button(_as_dictionary(collection[index]), relation, index))
	return row


func _make_team_icon_button(entry: Dictionary, relation: String, slot_index: int) -> Button:
	var button := Button.new()
	button.name = "%sTeamIcon%d" % ["Viewer" if relation == "viewer" else "Opponent", slot_index + 1]
	button.custom_minimum_size = Vector2(34, 34)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pokemon_ref := str(entry.get("pokemonRef", ""))
	button.set_meta("pokemon_ref", pokemon_ref)
	button.set_meta("relation", relation)
	var identity := _as_dictionary(entry.get("identity", {}))
	var species := str(identity.get("value", "")).strip_edges()
	var identity_known := str(identity.get("state", "")) == "known" and species != ""
	var fainted := bool(entry.get("fainted", false))
	var selected_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var is_selected := pokemon_ref != "" and pokemon_ref == selected_ref
	var is_active := bool(entry.get("active", false))
	var accent := CONDITION_OWN_ACCENT if relation == "viewer" else CONDITION_OPPONENT_ACCENT
	_apply_team_icon_button_style(button, accent, is_selected, is_active)
	button.disabled = not identity_known or pokemon_ref == ""
	if button.disabled:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.modulate = Color(1, 1, 1, 0.38) if fainted else Color.WHITE
	var display_name := species if identity_known else _t("common.unknown")
	button.tooltip_text = "%s · %s" % [display_name, _get_hp_label(entry)]

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 2.0
	stack.offset_top = 1.0
	stack.offset_right = -2.0
	stack.offset_bottom = -2.0
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 1)
	button.add_child(stack)
	if identity_known:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(27, 26)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = PokemonAssets.load_party_icon(species)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
	else:
		var unknown := _make_label("?", 18, TEXT_MUTED)
		unknown.custom_minimum_size = Vector2(27, 26)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(unknown)
	var hp_percent: Variant = _get_defender_hp_percent(entry)
	var hp_bar := _make_team_icon_hp_bar(float(hp_percent) if hp_percent != null else 0.0)
	hp_bar.visible = hp_percent != null
	stack.add_child(hp_bar)
	if not button.disabled:
		button.pressed.connect(_on_team_icon_pressed.bind(relation, pokemon_ref))
		button.mouse_entered.connect(_on_team_icon_mouse_entered.bind(entry, relation, button))
		button.mouse_exited.connect(_on_team_icon_mouse_exited.bind(relation))
	return button


func _on_team_icon_mouse_entered(entry: Dictionary, relation: String, button: Button) -> void:
	team_pokemon_hovered.emit(relation, entry.duplicate(true), button.get_global_rect())


func _on_team_icon_mouse_exited(relation: String) -> void:
	team_pokemon_unhovered.emit(relation)


func _apply_team_icon_button_style(button: Button, accent: Color, is_selected: bool, is_active: bool) -> void:
	var background := Color(SURFACE_RAISED, 0.96)
	var border := Color(BORDER_NEUTRAL, 0.84)
	if is_active:
		background = Color(accent, 0.10)
		border = Color(accent, 0.52)
	if is_selected:
		background = Color(accent, 0.20)
		border = accent
	var normal := _make_stylebox(background, border, 7, 2.0, 2.0)
	if is_selected:
		normal.border_width_left = 2
		normal.border_width_top = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _make_stylebox(background.lightened(0.08), accent.lightened(0.10), 7, 2.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(accent, 0.26), accent.lightened(0.18), 7, 2.0, 2.0))
	button.add_theme_stylebox_override("focus", _make_stylebox(Color(accent, 0.18), DROPDOWN_FOCUS_BORDER, 7, 2.0, 2.0))
	button.add_theme_stylebox_override("disabled", _make_stylebox(Color(SURFACE_PANEL, 0.80), Color(BORDER_NEUTRAL, 0.58), 7, 2.0, 2.0))


func _make_team_icon_hp_bar(hp_percent: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 3)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(hp_percent, 0.0, 100.0)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_color := STAGE_POSITIVE
	if hp_percent <= 20.0:
		fill_color = DANGER_ACCENT
	elif hp_percent <= 50.0:
		fill_color = WARNING_ACCENT
	bar.add_theme_stylebox_override("background", _make_stylebox(Color(SURFACE_CANVAS, 0.98), Color.TRANSPARENT, 2, 0.0, 0.0))
	bar.add_theme_stylebox_override("fill", _make_stylebox(fill_color, fill_color, 2, 0.0, 0.0))
	return bar


func _resolve_selected_ref(relation: String, current_ref: String) -> String:
	var collection: Array = _as_array(knowledge_snapshot.get("viewerPokemon" if relation == "viewer" else "opponentPokemon", []))
	var fallback := ""
	for entry_value: Variant in collection:
		var entry := _as_dictionary(entry_value)
		if entry.is_empty():
			continue
		var identity := _as_dictionary(entry.get("identity", {}))
		if str(identity.get("state", "")) != "known" or str(identity.get("value", "")).strip_edges() == "":
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
	opponent_boosts_label: String = "",
	viewer_status: String = "",
	opponent_status: String = ""
) -> void:
	if not knowledge_snapshot.is_empty():
		_add_team_selector_strips()
	var matchup_row := HBoxContainer.new()
	matchup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matchup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	matchup_row.add_theme_constant_override("separation", 10)
	_add_render_child(matchup_row)
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
		viewer_hp_percent,
		viewer_status
	))
	var arrow := _make_label("VS", 10, TEXT_MUTED)
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
		opponent_hp_percent,
		opponent_status
	))


func _make_matchup_side(
	_caption: String,
	pokemon_name: String,
	relation: String,
	details: String,
	is_attacker: bool,
	sprite_species: String,
	hp_percent: Variant,
	status: String = ""
) -> PanelContainer:
	var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var scenario_species := str(species_scenarios.get(pokemon_ref, "")).strip_edges()
	if scenario_species != "":
		pokemon_name = scenario_species
		sprite_species = scenario_species
	var panel := PanelContainer.new()
	panel.name = "ViewerProfileCard" if relation == "viewer" else "OpponentProfileCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 82)
	var relation_accent := CONDITION_OWN_ACCENT if relation == "viewer" else CONDITION_OPPONENT_ACCENT
	var card_background := HERO_BG.lightened(0.018) if is_attacker else HERO_BG
	panel.add_theme_stylebox_override("panel", _make_stylebox(card_background, relation_accent, 9, 11.0, 8.0))
	var card_row := HBoxContainer.new()
	card_row.clip_contents = true
	card_row.add_theme_constant_override("separation", 7)
	panel.add_child(card_row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
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
	side.add_theme_constant_override("separation", 2)
	card_row.add_child(side)
	var name_row := HBoxContainer.new()
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_theme_constant_override("separation", 5)
	side.add_child(name_row)
	if knowledge_snapshot.is_empty():
		var name_label := _make_label(pokemon_name, 15, TEXT_PRIMARY)
		name_label.tooltip_text = pokemon_name
		name_row.add_child(name_label)
	else:
		name_row.add_child(_make_forme_menu_button(relation, pokemon_name))
	if relation == "opponent" and not knowledge_snapshot.is_empty():
		_add_sample_set_selector(name_row)
		var set_selector := name_row.get_child(name_row.get_child_count() - 1) as OptionButton
		if set_selector != null:
			set_selector.custom_minimum_size.x = 118
			set_selector.size_flags_horizontal = Control.SIZE_SHRINK_END
	var detail_row := HBoxContainer.new()
	detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_theme_constant_override("separation", 4)
	side.add_child(detail_row)
	var detail_label := _make_label(details, 10, TEXT_SECONDARY)
	detail_label.tooltip_text = details
	detail_row.add_child(detail_label)
	if status in POKEMON_STATUS_VALUES and status != "":
		detail_row.add_child(_make_pokemon_status_badge(status))
	if hp_percent != null:
		side.add_child(_make_hp_bar(float(hp_percent)))
	var state_card := _make_battle_state_side("", relation)
	var state_body := state_card.get_child(0) as VBoxContainer
	if state_body != null:
		state_card.remove_child(state_body)
		state_card.queue_free()
		side.add_child(state_body)
	return panel


func _add_battle_state_controls() -> void:
	var section := PanelContainer.new()
	section.name = "BattleStateControls"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_stylebox_override("panel", _make_stylebox(SURFACE_PANEL, INTERACTION_ACCENT, 8, 9.0, 8.0))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	section.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	row.add_child(_make_battle_state_side("YOUR POKÉMON", "viewer"))
	row.add_child(_make_battle_state_side("OPPONENT", "opponent"))
	_add_render_child(section)


func _make_battle_state_side(_caption: String, relation: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_make_stylebox(SURFACE_RAISED, CONDITION_OWN_ACCENT if relation == "viewer" else CONDITION_OPPONENT_ACCENT, 6, 7.0, 5.0)
	)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	card.add_child(side)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 2)
	side.add_child(controls)
	var current_label := _make_label("Current HP", 10, TEXT_SECONDARY)
	current_label.custom_minimum_size.x = 62
	current_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(current_label)
	var hp_input := LineEdit.new()
	hp_input.name = "ViewerCurrentHp" if relation == "viewer" else "OpponentCurrentHp"
	hp_input.custom_minimum_size.x = 40
	hp_input.placeholder_text = "HP" if relation == "viewer" else "HP %"
	hp_input.text = _get_battle_state_hp_text(relation)
	hp_input.tooltip_text = "Current HP" if relation == "viewer" else "Current HP percentage"
	hp_input.text_submitted.connect(_on_battle_state_hp_changed.bind(relation, hp_input, false))
	hp_input.focus_exited.connect(_on_battle_state_hp_focus_exited.bind(relation, hp_input, false))
	hp_input.add_theme_stylebox_override("normal", _make_stylebox(SURFACE_CANVAS, BORDER_NEUTRAL, 4, 4.0, 1.0))
	hp_input.add_theme_stylebox_override("focus", _make_stylebox(SURFACE_CANVAS, INTERACTION_ACCENT, 4, 4.0, 1.0))
	controls.add_child(hp_input)
	var hp_display := _get_battle_state_hp_display(relation)
	var slash := _make_label("/ %s HP" % str(hp_display.get("maximum", "--")), 10, TEXT_SECONDARY)
	slash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(slash)
	var scenario_row := HBoxContainer.new()
	scenario_row.add_theme_constant_override("separation", 2)
	side.add_child(scenario_row)
	var percent_label := _make_label("HP %", 10, TEXT_SECONDARY)
	percent_label.custom_minimum_size.x = 62
	percent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scenario_row.add_child(percent_label)
	var percent_input := LineEdit.new()
	percent_input.name = "ViewerCurrentHpPercent" if relation == "viewer" else "OpponentCurrentHpPercent"
	percent_input.custom_minimum_size.x = 42
	percent_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	percent_input.placeholder_text = "%"
	percent_input.text = _format_percent_value(hp_display.get("percent"))
	percent_input.tooltip_text = "Current HP percentage"
	percent_input.max_length = 5
	percent_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_input.add_theme_stylebox_override("normal", _make_stylebox(SURFACE_CANVAS, BORDER_NEUTRAL, 4, 4.0, 1.0))
	percent_input.add_theme_stylebox_override("focus", _make_stylebox(SURFACE_RAISED, INTERACTION_ACCENT, 4, 4.0, 1.0))
	percent_input.text_submitted.connect(_on_battle_state_hp_changed.bind(relation, percent_input, true))
	percent_input.focus_exited.connect(_on_battle_state_hp_focus_exited.bind(relation, percent_input, true))
	scenario_row.add_child(percent_input)
	var percent_suffix := _make_label("%", 10, TEXT_SECONDARY)
	percent_suffix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scenario_row.add_child(percent_suffix)
	var status_caption := _make_label("Status:", 10, TEXT_ACCENT)
	status_caption.custom_minimum_size.x = 38
	status_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scenario_row.add_child(status_caption)
	var status_selector := _make_battle_state_status_selector(relation)
	status_selector.custom_minimum_size.x = 86
	status_selector.size_flags_horizontal = Control.SIZE_SHRINK_END
	scenario_row.add_child(status_selector)
	return card


func _make_battle_state_status_selector(relation: String) -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "ViewerBattleStatus" if relation == "viewer" else "OpponentBattleStatus"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scenario := _as_dictionary(battle_state_scenarios.get(selected_viewer_ref if relation == "viewer" else selected_opponent_ref, {}))
	var selected_status := str(scenario.get("status", "")).to_lower()
	var current_status := _get_effective_pokemon_status("own" if relation == "viewer" else "opponent")
	for status: String in POKEMON_STATUS_VALUES:
		var option_label := _get_status_label(status)
		if status == "":
			option_label = "Healthy" if current_status == "" else "Current (%s)" % _get_status_label(current_status)
		selector.add_item(option_label)
		selector.set_item_metadata(selector.item_count - 1, status)
		if status == selected_status:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_battle_state_status_changed.bind(relation, selector))
	_apply_calcdex_dropdown_style(selector, 28.0, 10)
	return selector


func _get_battle_state_hp_text(relation: String) -> String:
	return str(_get_battle_state_hp_display(relation).get("current", ""))


func _get_battle_state_hp_display(relation: String) -> Dictionary:
	var ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var state := _as_dictionary(battle_state_scenarios.get(ref, {}))
	var pokemon := _get_snapshot_pokemon_by_ref(ref)
	var hp := _get_pokemon_hp(pokemon)
	var exact := _as_dictionary(hp.get("exact", {}))
	var maximum := int(state.get("_maximumHp", exact.get("maximum", 100)))
	var current := int(exact.get("current", maximum))
	var percent := float(current) * 100.0 / float(maximum) if maximum > 0 else 0.0
	if relation == "opponent":
		if not state.has("_maximumHp"):
			maximum = _get_expected_opponent_max_hp()
			var snapshot_maximum := int(exact.get("maximum", 0))
			if maximum <= 100 and snapshot_maximum > 100:
				maximum = snapshot_maximum
		current = int(roundf(float(_get_defender_hp_percent(pokemon) if _get_defender_hp_percent(pokemon) != null else 100.0)))
		percent = float(current)
		current = int(roundf(float(maximum) * percent / 100.0))
	if state.has("currentHp"):
		current = clampi(int(state.get("currentHp", 0)), 0, maximum)
		percent = float(current) * 100.0 / float(maximum) if maximum > 0 else 0.0
	elif state.has("currentHpPercent"):
		percent = clampf(float(state.get("currentHpPercent", 0.0)), 0.0, 100.0)
		current = roundi(float(maximum) * percent / 100.0)
	return {"current": current, "maximum": maximum, "percent": percent}


func _get_expected_opponent_max_hp() -> int:
	for result_value: Variant in _as_array(last_response.get("results", [])):
		var result := _as_dictionary(result_value)
		var min_damage: Variant = _get_percent_number(result.get("minDamage"))
		var min_percent: Variant = _get_percent_number(result.get("minPercent"))
		if min_damage != null and min_percent != null and min_damage > 0.0 and min_percent > 0.0:
			return maxi(1, roundi(float(min_damage) * 100.0 / float(min_percent)))
	return 100


func _on_battle_state_hp_focus_exited(relation: String, input: LineEdit, is_percent: bool) -> void:
	if is_clearing_content:
		return
	_on_battle_state_hp_changed(input.text, relation, input, is_percent)


func _on_battle_state_hp_changed(value: String, relation: String, input: LineEdit, is_percent: bool = false) -> void:
	var number := value.strip_edges().to_float()
	var ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	if ref == "" or number < 0.0:
		input.text = _get_battle_state_hp_text(relation)
		return
	var state := _as_dictionary(battle_state_scenarios.get(ref, {})).duplicate(true)
	var maximum := int(_get_battle_state_hp_display(relation).get("maximum", 100))
	if is_percent:
		var percent := clampf(number, 0.0, 100.0)
		var current := clampi(roundi(float(maximum) * percent / 100.0), 0, maximum)
		state["currentHp"] = current
		state.erase("currentHpPercent")
	else:
		var current := clampi(int(number), 0, maximum)
		state["currentHp"] = current
		state.erase("currentHpPercent")
	state["_maximumHp"] = maximum
	battle_state_scenarios[ref] = state
	_mark_sample_set_custom()
	_emit_defender_assumptions_changed()


func _on_battle_state_status_changed(index: int, relation: String, selector: OptionButton) -> void:
	var ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	if ref == "":
		return
	var status := str(selector.get_item_metadata(index)).to_lower()
	var state := _as_dictionary(battle_state_scenarios.get(ref, {})).duplicate(true)
	if status == "":
		state.erase("status")
	else:
		state["status"] = status
	if state.is_empty():
		battle_state_scenarios.erase(ref)
	else:
		battle_state_scenarios[ref] = state
	_mark_sample_set_custom()
	_emit_defender_assumptions_changed()
	_render_current_state()


func _make_forme_menu_button(relation: String, pokemon_name: String) -> MenuButton:
	var button := MenuButton.new()
	button.name = "ViewerFormeSelector" if relation == "viewer" else "OpponentFormeSelector"
	button.text = "%s  ▾" % pokemon_name
	button.tooltip_text = _t("battle.calc.forme_tooltip")
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 23)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 15)
	var snapshot_species := _get_snapshot_species_for_relation(relation)
	var is_scenario := snapshot_species != "" and _normalize_move_name(snapshot_species) != _normalize_move_name(pokemon_name)
	button.add_theme_color_override("font_color", MANUAL_ACCENT if is_scenario else TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_ACCENT)
	button.add_theme_color_override("font_pressed_color", TEXT_ACCENT)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var background := Color.TRANSPARENT if style_name == "normal" else Color(TAB_ACTIVE_BG, 0.45)
		var border := Color.TRANSPARENT if style_name != "focus" else Color(INTERACTION_ACCENT, 0.82)
		button.add_theme_stylebox_override(style_name, _make_stylebox(background, border, 5, 3.0, 1.0))
	forme_menu_buttons[relation] = button
	var popup := button.get_popup()
	_apply_calcdex_popup_style(popup)
	popup.about_to_popup.connect(_on_forme_menu_about_to_popup.bind(relation))
	popup.id_pressed.connect(_on_forme_menu_item_pressed.bind(relation))
	_refresh_forme_menu(relation)
	return button


func _on_forme_menu_about_to_popup(relation: String) -> void:
	var key := _get_forme_catalog_key(relation)
	if key == "":
		return
	var catalog := _as_dictionary(forme_catalogs.get(key, {}))
	if bool(catalog.get("loading", false)) or catalog.has("options"):
		return
	forme_catalogs[key] = {"loading": true, "options": [], "error": ""}
	_refresh_forme_menu(relation)
	var snapshot_species := _get_snapshot_species_for_relation(relation)
	var format_data := _as_dictionary(knowledge_snapshot.get("format", {}))
	var format_id := str(format_data.get("engineFormatId", "gen9nationaldex")).strip_edges()
	forme_catalog_requested.emit(relation, snapshot_species, format_id)


func _refresh_forme_menu(relation: String) -> void:
	var button: MenuButton = forme_menu_buttons.get(relation) as MenuButton
	if button == null:
		return
	var popup := button.get_popup()
	popup.clear()
	var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var snapshot_species := _get_snapshot_species(pokemon_ref)
	var selected_species := str(species_scenarios.get(pokemon_ref, snapshot_species)).strip_edges()
	popup.add_item(_t("battle.calc.forme_current", {"species": snapshot_species}), 0)
	popup.set_item_metadata(0, snapshot_species)
	popup.set_item_as_radio_checkable(0, true)
	popup.set_item_checked(0, _normalize_move_name(selected_species) == _normalize_move_name(snapshot_species))
	var catalog := _as_dictionary(forme_catalogs.get(_get_forme_catalog_key(relation), {}))
	var alternate_count := 0
	for option_value: Variant in _as_array(catalog.get("options", [])):
		var option := _as_dictionary(option_value)
		var forme_name := str(option.get("name", "")).strip_edges()
		if forme_name == "" or _normalize_move_name(forme_name) == _normalize_move_name(snapshot_species):
			continue
		var item_id := popup.item_count
		popup.add_item(forme_name, item_id)
		popup.set_item_metadata(popup.item_count - 1, forme_name)
		popup.set_item_as_radio_checkable(popup.item_count - 1, true)
		popup.set_item_checked(popup.item_count - 1, _normalize_move_name(selected_species) == _normalize_move_name(forme_name))
		alternate_count += 1
	if bool(catalog.get("loading", false)):
		popup.add_separator()
		popup.add_item(_t("battle.calc.formes_loading"), popup.item_count)
		popup.set_item_disabled(popup.item_count - 1, true)
	elif str(catalog.get("error", "")).strip_edges() != "":
		popup.add_separator()
		popup.add_item(_t("battle.calc.formes_unavailable"), popup.item_count)
		popup.set_item_disabled(popup.item_count - 1, true)
	elif catalog.has("options") and alternate_count == 0:
		popup.add_separator()
		popup.add_item(_t("battle.calc.formes_unavailable"), popup.item_count)
		popup.set_item_disabled(popup.item_count - 1, true)


func _on_forme_menu_item_pressed(item_id: int, relation: String) -> void:
	var button: MenuButton = forme_menu_buttons.get(relation) as MenuButton
	if button == null:
		return
	var popup := button.get_popup()
	var item_index := popup.get_item_index(item_id)
	if item_index < 0 or popup.is_item_disabled(item_index):
		return
	var selected_species := str(popup.get_item_metadata(item_index)).strip_edges()
	var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var snapshot_species := _get_snapshot_species(pokemon_ref)
	if selected_species == "" or snapshot_species == "":
		return
	if _normalize_move_name(selected_species) == _normalize_move_name(snapshot_species):
		species_scenarios.erase(pokemon_ref)
	else:
		species_scenarios[pokemon_ref] = selected_species
	expanded_result_key = ""
	_clear_move_scenarios()
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _make_pokemon_status_badge(status: String) -> Label:
	var colors := _get_pokemon_status_colors(status)
	var badge := _make_label(_get_status_compact_label(status), 9, colors["text"])
	badge.custom_minimum_size = Vector2(32, 17)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.tooltip_text = _get_status_label(status)
	badge.add_theme_stylebox_override("normal", _make_stylebox(colors["background"], colors["border"], 4, 4.0, 1.0))
	return badge


func _get_pokemon_status_colors(status: String) -> Dictionary:
	match status:
		"brn":
			return {"text": Color(1.0, 0.78, 0.56), "background": Color(0.24, 0.075, 0.025, 0.96), "border": Color(0.90, 0.35, 0.12, 0.92)}
		"par":
			return {"text": Color(1.0, 0.91, 0.48), "background": Color(0.22, 0.17, 0.025, 0.96), "border": Color(0.90, 0.69, 0.12, 0.92)}
		"psn", "tox":
			return {"text": Color(0.92, 0.72, 1.0), "background": Color(0.16, 0.055, 0.22, 0.96), "border": Color(0.62, 0.28, 0.80, 0.92)}
		"slp":
			return {"text": Color(0.80, 0.84, 0.91), "background": Color(0.09, 0.11, 0.16, 0.96), "border": Color(0.39, 0.45, 0.56, 0.92)}
		"frz":
			return {"text": Color(0.74, 0.94, 1.0), "background": Color(0.025, 0.15, 0.21, 0.96), "border": Color(0.20, 0.68, 0.82, 0.92)}
	return {"text": TEXT_SECONDARY, "background": CHIP_BG, "border": CHIP_BORDER}


func _make_hp_bar(hp_percent: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
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
	_add_render_child(label)


func _get_snapshot_pokemon_by_ref(pokemon_ref: String) -> Dictionary:
	for collection_key: String in ["viewerPokemon", "opponentPokemon"]:
		for entry_value: Variant in _as_array(knowledge_snapshot.get(collection_key, [])):
			var entry := _as_dictionary(entry_value)
			if str(entry.get("pokemonRef", "")) == pokemon_ref:
				return entry
	return {}


func _get_snapshot_species(pokemon_ref: String) -> String:
	var pokemon := _get_snapshot_pokemon_by_ref(pokemon_ref)
	if pokemon.is_empty():
		return ""
	return _snapshot_pokemon_name(pokemon)


func _get_snapshot_species_for_relation(relation: String) -> String:
	var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	return _get_snapshot_species(pokemon_ref)


func _get_forme_catalog_key(relation: String) -> String:
	if relation not in ["viewer", "opponent"]:
		return ""
	var pokemon_ref := selected_viewer_ref if relation == "viewer" else selected_opponent_ref
	var species := _get_snapshot_species(pokemon_ref)
	if pokemon_ref == "" or species == "":
		return ""
	return "%s:%s" % [pokemon_ref, _normalize_move_name(species)]


func _prune_species_scenarios() -> void:
	var available_refs: Dictionary = {}
	for collection_key: String in ["viewerPokemon", "opponentPokemon"]:
		for entry_value: Variant in _as_array(knowledge_snapshot.get(collection_key, [])):
			var entry := _as_dictionary(entry_value)
			var pokemon_ref := str(entry.get("pokemonRef", ""))
			if pokemon_ref != "":
				available_refs[pokemon_ref] = true
	for ref_value: Variant in species_scenarios.keys():
		var pokemon_ref := str(ref_value)
		if not available_refs.has(pokemon_ref):
			species_scenarios.erase(pokemon_ref)


func _prune_viewer_boost_scenarios() -> void:
	var available_refs: Dictionary = {}
	for entry_value: Variant in _as_array(knowledge_snapshot.get("viewerPokemon", [])):
		var pokemon_ref := str(_as_dictionary(entry_value).get("pokemonRef", ""))
		if pokemon_ref != "":
			available_refs[pokemon_ref] = true
	for ref_value: Variant in viewer_boost_scenarios.keys():
		if not available_refs.has(str(ref_value)):
			viewer_boost_scenarios.erase(ref_value)


func _add_move_results_table(results: Array, defender: Dictionary) -> void:
	var table_box := _add_move_results_table_shell()
	var top_damage_percent := _get_top_damage_percent(results)
	for result_index: int in range(results.size()):
		var result_value: Variant = results[result_index]
		if result_value is Dictionary:
			var result := result_value as Dictionary
			_add_move_result_row(result, defender, table_box, result_index, -1, _is_top_damage_result(result, top_damage_percent))


func _add_move_results_table_shell() -> VBoxContainer:
	var table := PanelContainer.new()
	table.name = "MoveResultsTable"
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.clip_contents = true
	table.add_theme_stylebox_override(
		"panel",
		_make_stylebox(PROFILE_BG, Color(BORDER_NEUTRAL, 0.82), 8, 9.0, 7.0)
	)
	_add_render_child(table)
	var table_box := VBoxContainer.new()
	table_box.clip_contents = true
	table_box.add_theme_constant_override("separation", 5)
	table.add_child(table_box)
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_RAISED, 0.90), Color(BORDER_NEUTRAL, 0.72), 5, 10.0, 3.0)
	)
	table_box.add_child(header_panel)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	header_panel.add_child(header)
	var move_header := _make_table_header(_t("battle.calc.move_header"), EV_LABEL_ACCENT)
	move_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(move_header)
	var modifier_header := _make_table_header(_t("battle.calc.modifiers_header"), INTERACTION_ACCENT)
	modifier_header.custom_minimum_size = Vector2(86, 0)
	modifier_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	modifier_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(modifier_header)
	var damage_header := _make_table_header(_t("battle.calc.damage_header"), MANUAL_ACCENT)
	damage_header.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	damage_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	damage_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(damage_header)
	var ko_header := _make_table_header(_t("battle.calc.ko_header"), DANGER_ACCENT)
	ko_header.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 0)
	ko_header.size_flags_horizontal = Control.SIZE_SHRINK_END
	ko_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(ko_header)
	return table_box


func _add_editable_opponent_move_results_table(results: Array, defender: Dictionary) -> void:
	var table_box := _add_move_results_table_shell()
	inline_move_result_boxes.clear()
	inline_move_result_panels.clear()
	var move_names := _get_visible_opponent_move_names(results)
	var top_damage_percent := _get_top_damage_percent(results)
	for slot in range(4):
		var move_name := str(move_names[slot]).strip_edges() if slot < move_names.size() else ""
		var matching_result := _find_move_result(results, move_name)
		if matching_result.is_empty():
			_add_empty_editable_move_row(table_box, slot, move_name)
		else:
			_add_move_result_row(
				matching_result,
				defender,
				table_box,
				slot,
				slot,
				_is_top_damage_result(matching_result, top_damage_percent)
			)
		_add_inline_move_results_box(table_box, slot)


func _add_inline_move_results_box(parent: VBoxContainer, slot: int) -> void:
	var suggestions_panel := _make_selector_suggestions_panel()
	suggestions_panel.visible = false
	parent.add_child(suggestions_panel)
	var results_box := VBoxContainer.new()
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.clip_contents = true
	results_box.add_theme_constant_override("separation", 3)
	suggestions_panel.add_child(results_box)
	inline_move_result_boxes[slot] = results_box
	inline_move_result_panels[slot] = suggestions_panel


func _find_move_result(results: Array, move_name: String) -> Dictionary:
	var normalized_name := _normalize_move_name(move_name)
	if normalized_name == "":
		return {}
	for result_value: Variant in results:
		var result := _as_dictionary(result_value)
		if _normalize_move_name(_get_move_name(result)) == normalized_name:
			return result
	return {}


func _normalize_move_name(move_name: String) -> String:
	return move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "").replace("’", "").replace(".", "")


func _add_empty_editable_move_row(parent: VBoxContainer, slot: int, move_name: String = "") -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 52)
	panel.add_theme_stylebox_override("panel", _make_result_row_style("", slot))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	row.add_child(_make_result_move_selector_button(slot, move_name))
	var damage := _make_label("--", 15, TEXT_MUTED)
	damage.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	damage.size_flags_horizontal = Control.SIZE_SHRINK_END
	damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(damage)
	var ko := _make_label("--", 11, TEXT_MUTED)
	ko.custom_minimum_size = Vector2(KO_COLUMN_WIDTH, 28)
	ko.size_flags_horizontal = Control.SIZE_SHRINK_END
	ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 7, 7.0, 3.0))
	row.add_child(ko)
	parent.add_child(panel)


func _make_table_header(text: String, accent: Color = Color(0.68, 0.76, 0.86, 1.0)) -> Label:
	var label := _make_label(text.to_upper(), 9, accent)
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _add_move_result_row(
	result: Dictionary,
	defender: Dictionary,
	parent: VBoxContainer,
	row_index: int,
	editable_slot: int = -1,
	is_top_damage: bool = false
) -> void:
	var primary_result_label := _get_primary_result_label(result, defender)
	var move_type := _get_move_type(result)
	var move_name := _get_move_name(result)
	var summary_text := _get_result_summary_text(result)
	var result_key := _get_result_row_key(move_name, row_index, editable_slot)
	var panel := PanelContainer.new()
	panel.name = "MoveResultRow_%d" % row_index
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, 46)
	panel.add_theme_stylebox_override(
		"panel",
		_make_result_row_style(primary_result_label, row_index, move_type, selected_move_index == row_index or expanded_result_key == result_key, is_top_damage)
	)
	result_row_panels[result_key] = {
		"panel": panel,
		"primaryResultLabel": primary_result_label,
		"rowIndex": row_index,
		"moveType": move_type,
		"isTopDamage": is_top_damage,
	}
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_result_row_gui_input.bind(result_key))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 4)
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
	if editable_slot >= 0:
		var editable_row := HBoxContainer.new()
		editable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		editable_row.add_theme_constant_override("separation", 3)
		move_box.add_child(editable_row)
		editable_row.add_child(_make_result_move_selector_button(editable_slot, move_name))
		if summary_text != "":
			editable_row.add_child(_make_result_disclosure_button(result_key, move_name, true))
	else:
		if summary_text != "":
			move_box.add_child(_make_result_disclosure_button(result_key, _fallback_text(move_name, _t("battle.move.unknown")), false))
		else:
			var move_label := _make_label(_fallback_text(move_name, _t("battle.move.unknown")), 14, TEXT_PRIMARY)
			move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			move_box.add_child(move_label)
	result_row.add_child(_make_move_modifier_controls(row_index, move_name))

	var is_status_move: bool = _is_status_result(result)
	var percent_label: String = "" if is_status_move else _get_percent_label(result)
	var move_category := _get_move_category(result)
	var move_source := _get_move_source(result)
	var move_metadata: Array[String] = []
	if move_type != "":
		move_metadata.append(move_type.capitalize())
	if move_category != "":
		move_metadata.append(move_category.capitalize())
	if move_source != "" and move_source != "owned_exact":
		var provenance_key := "aggregate_prior" if move_source == "public_usage_prior" else move_source
		move_metadata.append(_t("battle.calc.provenance.%s" % provenance_key))
	if not move_metadata.is_empty():
		panel.tooltip_text = _join_string_array(move_metadata, " · ")
	if move_category != "":
		result_row.add_child(_make_move_category_label(move_category))
	var percent_color := TEXT_MUTED if is_status_move else DAMAGE_TEXT
	if not is_status_move and percent_label != "":
		percent_color = _get_result_badge_colors(primary_result_label)["text"]
	if is_top_damage:
		percent_color = WARNING_ACCENT
	var percent := _make_label(percent_label if percent_label != "" else "--", 13, percent_color)
	percent.custom_minimum_size = Vector2(DAMAGE_COLUMN_WIDTH, 0)
	percent.size_flags_horizontal = Control.SIZE_SHRINK_END
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_row.add_child(percent)
	var ko_label := _make_result_badge(primary_result_label)
	ko_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	ko_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_row.add_child(ko_label)
	if pending_move_index == row_index:
		var recalculating := _make_label("…", 15, INTERACTION_ACCENT)
		recalculating.name = "MoveRowRecalculating_%d" % row_index
		recalculating.custom_minimum_size = Vector2(18, 0)
		recalculating.size_flags_horizontal = Control.SIZE_SHRINK_END
		recalculating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_row.add_child(recalculating)

	if summary_text != "":
		var summary_panel := _make_result_summary_panel(summary_text)
		summary_panel.visible = expanded_result_key == result_key
		box.add_child(summary_panel)
		result_summary_panels[result_key] = summary_panel

	var result_state := str(result.get("resultState", "supported"))
	if result_state == "unsupported":
		_add_row_notice(box, _t("battle.calc.unsupported_mechanic"), TEXT_ERROR)
	elif result_state == "partial":
		_add_row_notice(box, _t("battle.calc.partial_result"), WARNING_ACCENT)

	for warning_value: Variant in _as_array(result.get("warnings", [])) + _as_array(result.get("koWarnings", [])):
		var warning := str(warning_value).strip_edges()
		if warning != "":
			_add_row_notice(box, _warning_label(warning), TEXT_ERROR if result_state in ["unsupported", "error"] else TEXT_MUTED)

	parent.add_child(panel)


func _make_move_modifier_controls(row_index: int, move_name: String, roomy: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "MoveModifiers_%d" % row_index
	row.custom_minimum_size = Vector2(104 if roomy else 86, 28)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 3)
	var scenario := _as_dictionary(move_scenarios.get(row_index, {}))
	row.add_child(_make_move_modifier_button("Z", "useZ", bool(scenario.get("useZ", false)), row_index, move_name, roomy))
	row.add_child(_make_move_modifier_button("CRIT", "isCrit", bool(scenario.get("isCrit", false)), row_index, move_name, roomy))
	return row


func _make_move_modifier_button(
	label: String,
	option_key: String,
	enabled: bool,
	row_index: int,
	move_name: String,
	roomy: bool
) -> Button:
	var button := Button.new()
	button.name = "%sToggle_%d" % [label.capitalize(), row_index]
	button.text = label
	button.toggle_mode = true
	button.button_pressed = enabled
	button.custom_minimum_size = Vector2(48 if roomy or label == "CRIT" else 34, 27)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _t("battle.calc.modifier.%s_tooltip" % ("z" if option_key == "useZ" else "crit"))
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", TEXT_MUTED)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(SURFACE_CANVAS, 0.82), Color(BORDER_NEUTRAL, 0.9), 5, 5.0, 2.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER, 5, 5.0, 2.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(TAB_ACTIVE_BG, 0.99), WARNING_ACCENT if option_key == "useZ" else INTERACTION_ACCENT, 5, 5.0, 2.0))
	button.add_theme_stylebox_override("focus", _make_stylebox(Color(TAB_ACTIVE_BG, 0.99), TEXT_ACCENT, 5, 5.0, 2.0))
	button.toggled.connect(_on_move_modifier_toggled.bind(row_index, move_name, option_key))
	return button


func _on_move_modifier_toggled(enabled: bool, row_index: int, move_name: String, option_key: String) -> void:
	var scenario := _as_dictionary(move_scenarios.get(row_index, {
		"moveIndex": row_index,
		"moveName": move_name,
		"useZ": false,
		"isCrit": false,
	}))
	if bool(scenario.get(option_key, false)) == enabled:
		return
	scenario["moveIndex"] = row_index
	scenario["moveName"] = move_name
	scenario[option_key] = enabled
	if bool(scenario.get("useZ", false)) or bool(scenario.get("isCrit", false)):
		move_scenarios[row_index] = scenario
	else:
		move_scenarios.erase(row_index)
	selected_move_index = row_index
	pending_move_index = row_index
	_render_current_state()
	move_scenarios_changed.emit(get_move_scenarios())


func _get_result_row_key(move_name: String, row_index: int, editable_slot: int) -> String:
	var direction := str(last_response.get("direction", get_matchup_selection().get("direction", "")))
	var slot := editable_slot if editable_slot >= 0 else row_index
	return "%s:%s:%d:%s" % [direction, "editable" if editable_slot >= 0 else "fixed", slot, _normalize_move_name(move_name)]


func _get_result_summary_text(result: Dictionary) -> String:
	var description := str(result.get("description", "")).strip_edges()
	if description == "":
		return ""
	if description == CONFIRMED_INFORMATION_ENVELOPE_DESCRIPTION:
		return _t("battle.calc.result_envelope_summary")
	var ko_projection := _as_dictionary(result.get("koProjection", {}))
	var projection_text := str(ko_projection.get("text", "")).strip_edges()
	if str(ko_projection.get("state", "")) == "available" and projection_text != "":
		var separator_index := description.find(" -- ")
		var direct_description := description.left(separator_index) if separator_index >= 0 else description
		return ("%s -- %s" % [direct_description, projection_text]).left(600)
	return description.left(600)


func _make_result_disclosure_button(result_key: String, move_name: String, compact: bool) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(28 if compact else 0, 30 if compact else 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END if compact else Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _t("battle.calc.result_details_tooltip")
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_ACCENT)
	button.add_theme_color_override("font_focus_color", TEXT_ACCENT)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var background := Color(0, 0, 0, 0)
		var border := Color(0, 0, 0, 0)
		if style_name in ["hover", "focus"]:
			background = Color(TAB_ACTIVE_BG.r, TAB_ACTIVE_BG.g, TAB_ACTIVE_BG.b, 0.48)
		if style_name == "focus":
			border = Color(TEXT_ACCENT.r, TEXT_ACCENT.g, TEXT_ACCENT.b, 0.72)
		button.add_theme_stylebox_override(style_name, _make_stylebox(background, border, 5, 4.0, 1.0))
	result_disclosure_buttons[result_key] = {
		"button": button,
		"moveName": move_name,
		"compact": compact,
	}
	_update_result_disclosure_button(result_key)
	button.pressed.connect(_on_result_disclosure_pressed.bind(result_key))
	return button


func _make_result_summary_panel(summary_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_RAISED, 0.96), Color(BORDER_NEUTRAL, 0.86), 6, 9.0, 6.0)
	)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var label := _make_label(summary_text, 11, TEXT_SECONDARY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var copy_button := Button.new()
	copy_button.name = "CopyResultSummaryButton"
	copy_button.text = _t("battle.calc.copy_summary")
	copy_button.tooltip_text = _t("battle.calc.copy_summary_tooltip")
	copy_button.custom_minimum_size = Vector2(68, 27)
	copy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	copy_button.focus_mode = Control.FOCUS_ALL
	copy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	copy_button.add_theme_font_size_override("font_size", 10)
	copy_button.add_theme_color_override("font_color", DAMAGE_TEXT)
	copy_button.add_theme_color_override("font_hover_color", Color.WHITE)
	copy_button.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 5, 6.0, 2.0))
	copy_button.add_theme_stylebox_override("hover", _make_stylebox(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER, 5, 6.0, 2.0))
	copy_button.add_theme_stylebox_override("pressed", _make_stylebox(DROPDOWN_PRESSED_BG, DROPDOWN_FOCUS_BORDER, 5, 6.0, 2.0))
	copy_button.add_theme_stylebox_override("focus", _make_stylebox(CHIP_BG, DROPDOWN_FOCUS_BORDER, 5, 6.0, 2.0))
	copy_button.pressed.connect(_on_copy_result_summary_pressed.bind(summary_text, copy_button))
	row.add_child(copy_button)
	return panel


func _on_copy_result_summary_pressed(summary_text: String, button: Button) -> void:
	DisplayServer.clipboard_set(summary_text)
	if button != null:
		button.text = _t("battle.calc.summary_copied")
		button.tooltip_text = _t("battle.calc.summary_copied")


func _on_result_disclosure_pressed(result_key: String) -> void:
	var selected_metadata := _as_dictionary(result_row_panels.get(result_key, {}))
	if not selected_metadata.is_empty():
		selected_move_index = int(selected_metadata.get("rowIndex", selected_move_index))
	expanded_result_key = "" if expanded_result_key == result_key else result_key
	_render_current_state()


func _on_result_row_gui_input(event: InputEvent, result_key: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_result_disclosure_pressed(result_key)
		accept_event()


func _update_result_disclosure_button(result_key: String) -> void:
	var metadata := _as_dictionary(result_disclosure_buttons.get(result_key, {}))
	var button: Button = metadata.get("button") as Button
	if button == null:
		return
	var symbol := "▾" if result_key == expanded_result_key else "▸"
	button.text = symbol if bool(metadata.get("compact", false)) else "%s  %s" % [symbol, str(metadata.get("moveName", ""))]


func _update_result_row_highlight(result_key: String) -> void:
	var metadata := _as_dictionary(result_row_panels.get(result_key, {}))
	var panel: PanelContainer = metadata.get("panel") as PanelContainer
	if panel == null:
		return
	panel.add_theme_stylebox_override(
		"panel",
		_make_result_row_style(
			str(metadata.get("primaryResultLabel", "")),
			int(metadata.get("rowIndex", 0)),
			str(metadata.get("moveType", "")),
			result_key == expanded_result_key,
			bool(metadata.get("isTopDamage", false))
		)
	)


func _make_result_move_selector_button(slot: int, move_name: String) -> LineEdit:
	var input := LineEdit.new()
	input.text = move_name
	input.placeholder_text = _t("battle.calc.add_move")
	input.tooltip_text = "Click to edit the opponent move"
	input.custom_minimum_size = Vector2(0, 30)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 100
	input.add_theme_font_size_override("font_size", 14 if move_name != "" else 12)
	input.add_theme_color_override("font_color", TEXT_ACCENT if move_name != "" else TEXT_MUTED)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	input.right_icon = DROPDOWN_ARROW
	input.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	input.add_theme_stylebox_override("normal", _make_stylebox(Color(SURFACE_CANVAS, 0.72), Color(INTERACTION_ACCENT, 0.52), 5, 5.0, 1.0))
	input.add_theme_stylebox_override("hover", _make_stylebox(Color(TAB_ACTIVE_BG, 0.82), Color(INTERACTION_ACCENT, 0.84), 5, 5.0, 1.0))
	input.add_theme_stylebox_override("focus", _make_stylebox(Color(TAB_ACTIVE_BG.r, TAB_ACTIVE_BG.g, TAB_ACTIVE_BG.b, 0.72), TEXT_ACCENT, 5, 4.0, 1.0))
	input.focus_entered.connect(_on_inline_move_focus_entered.bind(slot, input))
	input.focus_exited.connect(_on_catalog_assumption_focus_exited.bind(SELECTOR_MOVE))
	input.gui_input.connect(_on_inline_move_input_gui.bind(slot, input))
	input.text_changed.connect(_on_inline_move_text_changed.bind(slot, input))
	input.text_submitted.connect(_on_inline_move_text_submitted.bind(slot))
	return input


func _on_inline_move_input_gui(event: InputEvent, _slot: int, input: LineEdit) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.position.x < input.size.x - 28.0:
		return
	if active_selector == SELECTOR_MOVE:
		call_deferred("_close_assumption_suggestions")
		input.accept_event()


func _make_result_row_style(
	_primary_result_label: String,
	row_index: int,
	move_type: String = "",
	is_selected: bool = false,
	is_top_damage: bool = false
) -> StyleBoxFlat:
	var background := ROW_BG_ALT if row_index % 2 == 0 else ROW_BG
	if is_top_damage:
		background = Color(0.075, 0.127, 0.176, 0.98)
	if is_selected:
		background = Color(0.086, 0.157, 0.227, 0.99)
	var style := _make_stylebox(background, Color(0, 0, 0, 0), 7, 8.0, 5.0)
	style.border_width_left = 3
	style.border_width_top = 1 if is_selected else 0
	style.border_width_right = 1 if is_selected else 0
	style.border_width_bottom = 1 if is_selected else 0
	if is_selected:
		style.border_color = Color(INTERACTION_ACCENT, 0.96)
	else:
		style.border_color = TYPE_COLORS.get(move_type.to_lower(), ROW_BORDER)
	return style


func _make_move_type_badge(move_type: String) -> Label:
	var type_color: Color = TYPE_COLORS.get(move_type.to_lower(), PROFILE_BORDER)
	var label := _make_label(move_type.to_upper(), 8, Color(1.0, 1.0, 1.0, 0.96))
	label.custom_minimum_size = Vector2(44, 18)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_stylebox_override("normal", _make_stylebox(type_color.darkened(0.12), type_color.lightened(0.12), 8, 4.0, 1.0))
	return label


func _make_move_category_label(category: String) -> Label:
	var label := _make_label(category.to_upper(), 8, LABEL_NEUTRAL)
	label.custom_minimum_size = Vector2(54, 18)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_move_source_label(source: String) -> Label:
	if source == "owned_exact":
		return null
	var provenance_key := source
	if source == "public_usage_prior":
		provenance_key = "aggregate_prior"
	var label := _make_label(_t("battle.calc.provenance.%s" % provenance_key).to_upper(), 8, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(56, 17)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 8, 5.0, 1.0))
	return label


func _add_result_footnotes(response: Dictionary, _results: Array) -> void:
	var details: Array[String] = []
	for warning_value: Variant in _as_array(response.get("warnings", [])):
		var warning := str(warning_value).strip_edges()
		if warning in [
			"CALC_SCENARIO_ABILITY",
			"CALC_SCENARIO_ITEM",
			"CALC_SCENARIO_NATURE",
			"CALC_SCENARIO_EVS",
			"CALC_SCENARIO_IVS",
			"CALC_SCENARIO_BOOSTS",
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
	_add_render_child(notes_panel)
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
			"text": Color("#ffd2cc"),
			"background": Color(0.25, 0.075, 0.065, 0.98),
			"border": Color(DANGER_ACCENT, 0.96),
		}
	if normalized.contains("2HKO") and not normalized.begins_with("0%"):
		return {
			"text": DAMAGE_TEXT,
			"background": Color(0.055, 0.125, 0.18, 0.98),
			"border": Color(INTERACTION_ACCENT, 0.78),
		}
	var chance_label := _t("battle.calc.chance").to_upper()
	if normalized == "CHANCE" or (chance_label != "" and normalized == chance_label):
		return {
			"text": Color("#ffe4a3"),
			"background": Color(0.22, 0.15, 0.045, 0.98),
			"border": Color(WARNING_ACCENT, 0.96),
		}
	return {
		"text": TEXT_SECONDARY,
		"background": CHIP_BG,
		"border": CHIP_BORDER,
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


func _apply_calcdex_scroll_style() -> void:
	var scroll := get_node_or_null("CalcScroll") as ScrollContainer
	if scroll == null:
		return
	scroll.add_theme_constant_override("scrollbar_width", 9)
	var vertical_bar := scroll.get_v_scroll_bar()
	if vertical_bar == null:
		return
	vertical_bar.custom_minimum_size.x = 9
	vertical_bar.add_theme_constant_override("minimum_grabber_size", 28)
	vertical_bar.add_theme_stylebox_override(
		"scroll",
		_make_stylebox(Color(SURFACE_CANVAS, 0.78), Color(BORDER_NEUTRAL, 0.72), 5, 0.0, 0.0)
	)
	vertical_bar.add_theme_stylebox_override(
		"grabber",
		_make_stylebox(Color(INTERACTION_ACCENT, 0.46), Color(INTERACTION_ACCENT, 0.74), 5, 0.0, 0.0)
	)
	vertical_bar.add_theme_stylebox_override(
		"grabber_highlight",
		_make_stylebox(Color(INTERACTION_ACCENT, 0.66), INTERACTION_ACCENT, 5, 0.0, 0.0)
	)
	vertical_bar.add_theme_stylebox_override(
		"grabber_pressed",
		_make_stylebox(Color(INTERACTION_ACCENT, 0.82), INTERACTION_ACCENT.lightened(0.12), 5, 0.0, 0.0)
	)


func _add_live_assumption_controls(
	assumptions: Dictionary,
	_prior_provenance: String = "",
	shared_box: VBoxContainer = null
) -> void:
	is_syncing_assumption_controls = true
	live_ev_inputs.clear()
	live_ev_bars.clear()
	live_ev_total_label = null
	live_ev_total_bar = null
	item_assumption_input = null
	ability_assumption_input = null
	move_assumption_input = null
	catalog_results_box = null
	var box := shared_box
	if box == null:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
		panel.add_theme_stylebox_override(
			"panel",
			_make_stylebox(PROFILE_BG, Color(CONDITION_OPPONENT_ACCENT, 0.34), 8, 8.0, 6.0)
		)
		_add_render_child(panel)
		box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.clip_contents = true
		box.add_theme_constant_override("separation", 3)
		panel.add_child(box)
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	var identity_row := HBoxContainer.new()
	identity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_theme_constant_override("separation", 6)
	box.add_child(identity_row)
	var opponent_name := _snapshot_pokemon_name(opponent) if not opponent.is_empty() else _t("battle.calc.opponent")
	var identity_title := _make_label("%s %s · %s" % [
		_t("battle.calc.opponent").to_upper(),
		_t("battle.calc.set_label").to_upper(),
		opponent_name.to_upper(),
	], 9, CONDITION_OPPONENT_ACCENT)
	identity_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_row.add_child(identity_title)
	var opponent_role_text := _t("battle.calc.attacker") if active_subtab == SUBTAB_THEIR_DAMAGE else _t("battle.calc.target")
	var opponent_role := _make_label(opponent_role_text.to_upper(), 8, TEXT_MUTED)
	opponent_role.size_flags_horizontal = Control.SIZE_SHRINK_END
	opponent_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opponent_role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_row.add_child(opponent_role)
	if not edited_assumption_fields.is_empty() or not field_scenario.is_empty():
		var setup_row := HBoxContainer.new()
		setup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setup_row.add_theme_constant_override("separation", 4)
		box.add_child(setup_row)
		var reset_button := _make_assumption_reset_button()
		reset_button.size_flags_vertical = Control.SIZE_SHRINK_END
		setup_row.add_child(reset_button)

	var primary_row := HBoxContainer.new()
	primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_row.clip_contents = true
	primary_row.add_theme_constant_override("separation", 3)
	box.add_child(primary_row)

	primary_row.add_child(_make_inline_assumption_field(
		_t("battle.calc.ability"),
		_get_catalog_assumption_value(assumptions, SELECTOR_ABILITY),
		SELECTOR_ABILITY,
		_get_assumption_chip_label(assumptions, "ability", _t("battle.calc.ability_unknown"))
	))
	primary_row.add_child(_make_inline_assumption_field(
		_t("battle.calc.nature"),
		_localized_nature_name(_fallback_text(_get_catalog_assumption_value(assumptions, SELECTOR_NATURE), "Hardy")),
		SELECTOR_NATURE,
		_get_nature_chip_label(assumptions)
	))
	primary_row.add_child(_make_inline_assumption_field(
		_t("battle.calc.item"),
		_get_catalog_assumption_value(assumptions, SELECTOR_ITEM),
		SELECTOR_ITEM,
		_get_assumption_chip_label(assumptions, "item", _t("battle.calc.item_none"))
	))
	catalog_suggestions_box = VBoxContainer.new()
	catalog_suggestions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_suggestions_box.clip_contents = true
	catalog_suggestions_box.add_theme_constant_override("separation", 5)
	box.add_child(catalog_suggestions_box)
	if _is_current_ability_assumed():
		var ability_warning := _make_label(_t("battle.calc.assumed_ability_warning", {
			"ability": current_default_ability,
		}), 10, WARNING_ACCENT)
		ability_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_warning.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		box.add_child(ability_warning)
	elif current_default_ability_loading and str(assumptions.get("ability", "")).strip_edges() == "":
		box.add_child(_make_label(_t("battle.calc.loading_default_ability"), 10, TEXT_MUTED))

	_render_active_assumption_editor(assumptions)

	is_syncing_assumption_controls = false
	if live_ev_focus_stat != "":
		call_deferred("_restore_live_ev_input_focus")


func _add_boost_stage_controls(parent: VBoxContainer, assumptions: Dictionary) -> void:
	var header := _make_label(_t("battle.calc.stat_modifiers").to_upper(), 8, Color(CONDITION_OPPONENT_ACCENT, 0.94))
	header.custom_minimum_size = Vector2(0, 14)
	parent.add_child(header)
	var values := _get_effective_opponent_boosts(assumptions)
	var public_values := _get_public_opponent_boosts()
	var boosts_are_edited := bool(edited_assumption_fields.get("boosts", false))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for stat_key: String in BOOST_STAT_KEYS:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.clip_contents = true
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var label := _make_label(_get_ev_display_name(stat_key), 9, _get_stat_label_accent(stat_key))
		label.custom_minimum_size = Vector2(25, 28)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(label)
		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var current_stage := clampi(int(values.get(stat_key, 0)), -6, 6)
		for stage in range(-6, 7):
			selector.add_item("+%d" % stage if stage > 0 else str(stage))
			selector.set_item_metadata(selector.item_count - 1, stage)
			if stage == current_stage:
				selector.select(selector.item_count - 1)
		selector.item_selected.connect(_on_boost_stage_selected.bind(selector, stat_key))
		_apply_calcdex_dropdown_style(selector, 28.0, 10)
		_apply_boost_stage_style(selector, current_stage, public_values.has(stat_key), boosts_are_edited)
		cell.add_child(selector)


func _add_showdex_detail_controls(assumptions: Dictionary) -> void:
	_add_showdex_stat_grid(assumptions)
	_add_showdex_condition_controls(assumptions)


func _add_viewer_ability_controls(parent: VBoxContainer, viewer: Dictionary) -> void:
	var ability_row := HBoxContainer.new()
	ability_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(ability_row)
	var ability_label := _make_label(_t("battle.calc.ability").to_upper(), 8, TEXT_MUTED)
	ability_label.custom_minimum_size.x = 58
	ability_row.add_child(ability_label)
	var selector := OptionButton.new()
	selector.name = "ViewerAbilitySelector"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = "Choose the ability used for this calculation"
	var selected_ability := _get_viewer_ability_value(viewer)
	var options := _get_viewer_ability_options(viewer)
	for ability: String in options:
		selector.add_item(ability)
		selector.set_item_metadata(selector.item_count - 1, ability)
		if ability.to_lower() == selected_ability.to_lower():
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_viewer_ability_option_selected.bind(selector))
	_apply_calcdex_dropdown_style(selector, 27.0, 10)
	ability_row.add_child(selector)


func _get_viewer_ability_options(viewer: Dictionary) -> Array[String]:
	var options: Array[String] = []
	for value: Variant in _as_array(viewer.get("possibleAbilities", viewer.get("possible_abilities", []))):
		var ability := str(value).strip_edges()
		if ability != "" and not options.has(ability):
			options.append(ability)
	var known := _get_known_viewer_ability(viewer)
	if known != "" and not options.has(known):
		options.push_front(known)
	var selected := str(viewer_ability_scenarios.get(selected_viewer_ref, "")).strip_edges()
	if selected != "" and not options.has(selected):
		options.push_front(selected)
	var species := _snapshot_pokemon_name(viewer)
	for ability_value: Variant in _as_array(viewer_ability_catalogs.get(species, [])):
		var ability := str(ability_value).strip_edges()
		if ability != "" and not options.has(ability):
			options.append(ability)
	if options.size() <= 1 and not viewer_ability_catalog_loading:
		viewer_ability_catalog_loading = true
		viewer_ability_catalog_requested.emit(species)
	return options


func show_viewer_ability_catalog_response(species: String, response: Dictionary) -> void:
	viewer_ability_catalog_loading = false
	var abilities: Array[String] = []
	for value: Variant in _as_array(response.get("abilities", [])):
		var ability := str(_as_dictionary(value).get("calcName", _as_dictionary(value).get("name", value))).strip_edges()
		if ability != "" and not abilities.has(ability):
			abilities.append(ability)
	viewer_ability_catalogs[species] = abilities
	if is_inside_tree():
		_render_current_state()
func _get_viewer_ability_value(viewer: Dictionary) -> String:
	var scenario := str(viewer_ability_scenarios.get(selected_viewer_ref, "")).strip_edges()
	if scenario != "":
		return scenario
	return _get_known_viewer_ability(viewer)


func _get_known_viewer_ability(viewer: Dictionary) -> String:
	var knowledge := CALCDEX_SNAPSHOT.get_knowledge_value(viewer, "ability")
	return str(knowledge.get("value", "")).strip_edges() if str(knowledge.get("state", "")) == "known" else ""


func _on_viewer_ability_focus_exited(input: LineEdit) -> void:
	if is_clearing_content:
		return
	_on_viewer_ability_submitted(input.text, input)


func _on_viewer_ability_option_selected(index: int, selector: OptionButton) -> void:
	if selected_viewer_ref == "":
		return
	var ability := str(selector.get_item_metadata(index)).strip_edges()
	var known := _get_known_viewer_ability(_get_snapshot_pokemon_by_ref(selected_viewer_ref))
	if ability == "" or ability == known:
		viewer_ability_scenarios.erase(selected_viewer_ref)
	else:
		viewer_ability_scenarios[selected_viewer_ref] = ability
	_mark_sample_set_custom()
	_emit_defender_assumptions_changed()


func _on_viewer_ability_submitted(value: String, _input: LineEdit) -> void:
	if selected_viewer_ref == "":
		return
	var ability := value.strip_edges()
	var known := _get_known_viewer_ability(_get_snapshot_pokemon_by_ref(selected_viewer_ref))
	if ability == known:
		viewer_ability_scenarios.erase(selected_viewer_ref)
	elif ability == "":
		viewer_ability_scenarios.erase(selected_viewer_ref)
	else:
		viewer_ability_scenarios[selected_viewer_ref] = ability
	_mark_sample_set_custom()
	_emit_defender_assumptions_changed()


func _add_viewer_stat_grid() -> void:
	var viewer := _get_snapshot_pokemon_by_ref(selected_viewer_ref)
	if viewer.is_empty():
		return
	var panel := PanelContainer.new()
	panel.name = "ViewerStatCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_PANEL, 0.96), Color(CONDITION_OWN_ACCENT, 0.72), 8, 8.0, 7.0)
	)
	_add_render_child(panel)
	var viewer_box := VBoxContainer.new()
	viewer_box.name = "ViewerStatGrid"
	viewer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer_box.add_theme_constant_override("separation", 4)
	panel.add_child(viewer_box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	viewer_box.add_child(header)
	var title := _make_label("%s · %s" % [
		_t("battle.calc.your_pokemon").to_upper(),
		_snapshot_pokemon_name(viewer).to_upper(),
	], 9, CONDITION_OWN_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var role_text := _t("battle.calc.target") if active_subtab == SUBTAB_THEIR_DAMAGE else _t("battle.calc.attacker")
	var role := _make_label(role_text.to_upper(), 8, TEXT_MUTED)
	role.size_flags_horizontal = Control.SIZE_SHRINK_END
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(role)
	if not _as_dictionary(viewer_boost_scenarios.get(selected_viewer_ref, {})).is_empty():
		var reset := Button.new()
		reset.name = "ViewerStagesReset"
		reset.text = _t("battle.calc.reset_stages").to_upper()
		reset.custom_minimum_size = Vector2(54, 23)
		reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		reset.add_theme_font_size_override("font_size", 8)
		reset.add_theme_color_override("font_color", TEXT_MUTED)
		reset.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
		reset.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 5, 5.0, 2.0))
		reset.add_theme_stylebox_override("hover", _make_stylebox(DROPDOWN_HOVER_BG, CONDITION_OWN_ACCENT, 5, 5.0, 2.0))
		reset.pressed.connect(_on_viewer_stages_reset)
		header.add_child(reset)
	_add_viewer_ability_controls(viewer_box, viewer)

	var stat_keys: Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	viewer_box.add_child(grid)
	var corner := _make_label("", 8, TEXT_MUTED)
	corner.custom_minimum_size = Vector2(42, 0)
	grid.add_child(corner)
	for stat_key: String in stat_keys:
		var stat_header := _make_label(_get_ev_display_name(stat_key).to_upper(), 8, _get_stat_label_accent(stat_key))
		stat_header.custom_minimum_size = Vector2(46, 18)
		stat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(stat_header)

	var public_boosts := _get_known_stat_table(viewer, "boosts")
	var scenario_boosts := _as_dictionary(viewer_boost_scenarios.get(selected_viewer_ref, {}))
	var effective_stats := _get_viewer_effective_stats(stat_keys, public_boosts, scenario_boosts)
	_add_viewer_readonly_stat_row(
		grid,
		_t("battle.calc.stats"),
		stat_keys,
		effective_stats
	)
	var stage_label := _make_label(_t("battle.calc.stage"), 8, Color(CONDITION_OWN_ACCENT, 0.94))
	stage_label.custom_minimum_size = Vector2(42, 26)
	stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(stage_label)
	for stat_key: String in stat_keys:
		if stat_key == "hp":
			var unavailable := _make_label("—", 10, TEXT_MUTED)
			unavailable.custom_minimum_size = Vector2(46, 26)
			unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			unavailable.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(unavailable)
			continue
		var current_stage := int(scenario_boosts.get(stat_key, public_boosts.get(stat_key, 0)))
		grid.add_child(_make_viewer_stage_selector(stat_key, clampi(current_stage, -6, 6), public_boosts.has(stat_key), scenario_boosts.has(stat_key)))


func _get_viewer_effective_stats(stat_keys: Array[String], public_boosts: Dictionary, scenario_boosts: Dictionary) -> Dictionary:
	var base_stats := _as_dictionary(viewer_stats_by_ref.get(selected_viewer_ref, {}))
	var result: Dictionary = {}
	for stat_key: String in stat_keys:
		if not base_stats.has(stat_key):
			continue
		var stage := clampi(int(scenario_boosts.get(stat_key, public_boosts.get(stat_key, 0))), -6, 6)
		result[stat_key] = _apply_viewer_stage_to_stat(int(base_stats.get(stat_key, 0)), stage) if stat_key != "hp" else int(base_stats.get(stat_key, 0))
	return result


func _apply_viewer_stage_to_stat(base_stat: int, stage: int) -> int:
	if stage == 0:
		return base_stat
	if stage > 0:
		return int(floor(float(base_stat * (2 + stage)) / 2.0))
	return int(floor(float(base_stat * 2) / float(2 - stage)))


func _get_opponent_calculated_stats(results: Array) -> Dictionary:
	for value: Variant in results:
		var result := _as_dictionary(value)
		if result.get("defenderStats") is Dictionary:
			return _as_dictionary(result.get("defenderStats"))
	return {}


func _add_opponent_setup_card(assumptions: Dictionary, calculated_stats: Dictionary = {}) -> void:
	var panel := PanelContainer.new()
	panel.name = "OpponentSetupCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(PROFILE_BG, Color(CONDITION_OPPONENT_ACCENT, 0.62), 8, 8.0, 7.0)
	)
	_add_render_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.clip_contents = true
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_add_live_assumption_controls(assumptions, "", box)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color(CONDITION_OPPONENT_ACCENT, 0.34)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	_add_showdex_stat_grid(assumptions, box, false, calculated_stats)


func _add_viewer_readonly_stat_row(grid: GridContainer, row_name: String, stat_keys: Array[String], values: Dictionary) -> void:
	var row_label := _make_label(row_name, 8, CONDITION_OWN_ACCENT)
	row_label.custom_minimum_size = Vector2(42, 24)
	row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(row_label)
	for stat_key: String in stat_keys:
		var has_value := values.has(stat_key)
		var text := str(int(values.get(stat_key, 0))) if has_value else "—"
		var value_label := _make_label(text, 10, TEXT_PRIMARY if has_value else TEXT_MUTED)
		value_label.custom_minimum_size = Vector2(46, 24)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(value_label)


func _get_known_stat_table(pokemon: Dictionary, field_name: String) -> Dictionary:
	var knowledge := CALCDEX_SNAPSHOT.get_knowledge_value(pokemon, field_name)
	return _as_dictionary(knowledge.get("value", {})) if str(knowledge.get("state", "")) == "known" else {}


func _make_viewer_stage_selector(stat_key: String, current_stage: int, is_public: bool, is_edited: bool) -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "ViewerStage%s" % stat_key.capitalize()
	selector.custom_minimum_size = Vector2(46, 26)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = _t("battle.calc.stat_modifiers")
	for stage in range(-6, 7):
		selector.add_item("+%d" % stage if stage > 0 else str(stage))
		selector.set_item_metadata(selector.item_count - 1, stage)
		if stage == current_stage:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_viewer_stage_selected.bind(selector, stat_key))
	_apply_calcdex_dropdown_style(selector, 26.0, 9)
	_apply_boost_stage_style(selector, current_stage, is_public, is_edited)
	return selector


func _on_viewer_stage_selected(index: int, selector: OptionButton, stat_key: String) -> void:
	if stat_key not in BOOST_STAT_KEYS or selected_viewer_ref == "":
		return
	var viewer := _get_snapshot_pokemon_by_ref(selected_viewer_ref)
	var public_boosts := _get_known_stat_table(viewer, "boosts")
	var selected_stage := clampi(int(selector.get_item_metadata(index)), -6, 6)
	var scenario := _as_dictionary(viewer_boost_scenarios.get(selected_viewer_ref, {})).duplicate(true)
	if selected_stage == int(public_boosts.get(stat_key, 0)):
		scenario.erase(stat_key)
	else:
		scenario[stat_key] = selected_stage
	if scenario.is_empty():
		viewer_boost_scenarios.erase(selected_viewer_ref)
	else:
		viewer_boost_scenarios[selected_viewer_ref] = scenario
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _on_viewer_stages_reset() -> void:
	if selected_viewer_ref == "" or not viewer_boost_scenarios.has(selected_viewer_ref):
		return
	viewer_boost_scenarios.erase(selected_viewer_ref)
	last_response = {}
	_render_current_state()
	matchup_selection_changed.emit()


func _add_showdex_stat_grid(
	assumptions: Dictionary,
	shared_box: VBoxContainer = null,
	show_opponent_identity: bool = true,
	calculated_stats: Dictionary = {}
) -> void:
	var box := VBoxContainer.new()
	box.name = "ShowdexStatGrid"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	if shared_box != null:
		shared_box.add_child(box)
	else:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
		panel.add_theme_stylebox_override(
			"panel",
			_make_stylebox(Color(SURFACE_PANEL, 0.96), Color(BORDER_NEUTRAL, 0.86), 8, 7.0, 5.0)
		)
		_add_render_child(panel)
		panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 6)
	box.add_child(title_row)
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	var opponent_name := _snapshot_pokemon_name(opponent) if not opponent.is_empty() else _t("battle.calc.opponent")
	var title_text := "%s · %s" % [
		_t("battle.calc.opponent").to_upper(),
		opponent_name.to_upper(),
	] if show_opponent_identity else _t("battle.calc.ev_spread").to_upper()
	var title := _make_label(title_text, 9 if show_opponent_identity else 8, CONDITION_OPPONENT_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	if show_opponent_identity:
		var role_text := _t("battle.calc.attacker") if active_subtab == SUBTAB_THEIR_DAMAGE else _t("battle.calc.target")
		var role := _make_label(role_text.to_upper(), 8, TEXT_MUTED)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_row.add_child(role)
	live_ev_total_label = null
	live_ev_total_bar = null

	var stat_keys: Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var corner := _make_label("", 8, TEXT_MUTED)
	corner.custom_minimum_size = Vector2(42, 0)
	grid.add_child(corner)
	for stat_key: String in stat_keys:
		var stat_header := _make_label(_get_ev_display_name(stat_key).to_upper(), 8, _get_stat_label_accent(stat_key))
		stat_header.custom_minimum_size = Vector2(46, 18)
		stat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(stat_header)

	var ivs := _as_dictionary(assumptions.get("ivs", {}))
	var iv_row_label := _make_label("IVs", 8, TEXT_MUTED)
	iv_row_label.custom_minimum_size = Vector2(42, 24)
	iv_row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(iv_row_label)
	for stat_key: String in stat_keys:
		var iv_value := clampi(int(ivs.get(stat_key, 31)), 0, 31)
		var iv_label := _make_label(str(iv_value), 10, TEXT_PRIMARY if iv_value == 31 else MANUAL_ACCENT)
		iv_label.custom_minimum_size = Vector2(46, 24)
		iv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(iv_label)
	if not calculated_stats.is_empty():
		var stats_label := _make_label(_t("battle.calc.stats"), 8, CONDITION_OPPONENT_ACCENT)
		stats_label.custom_minimum_size = Vector2(42, 24)
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(stats_label)
		for stat_key: String in stat_keys:
			var stat_value := _make_label(str(int(calculated_stats.get(stat_key, 0))), 10, TEXT_PRIMARY)
			stat_value.custom_minimum_size = Vector2(46, 24)
			stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(stat_value)

	var evs := _as_dictionary(assumptions.get("evs", {}))
	var ev_row_label := _make_label("EVs", 8, EV_LABEL_ACCENT)
	ev_row_label.custom_minimum_size = Vector2(42, 26)
	ev_row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(ev_row_label)
	for stat_key: String in stat_keys:
		grid.add_child(_make_showdex_ev_input(stat_key, int(evs.get(stat_key, 0))))

	var values := _get_effective_opponent_boosts(assumptions)
	var public_values := _get_public_opponent_boosts()
	var boosts_are_edited := bool(edited_assumption_fields.get("boosts", false))
	var stage_row_label := _make_label(_t("battle.calc.stage"), 8, Color(CONDITION_OPPONENT_ACCENT, 0.94))
	stage_row_label.custom_minimum_size = Vector2(42, 26)
	stage_row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(stage_row_label)
	for stat_key: String in stat_keys:
		if stat_key == "hp":
			var unavailable := _make_label("—", 10, TEXT_MUTED)
			unavailable.custom_minimum_size = Vector2(46, 26)
			unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			unavailable.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(unavailable)
			continue
		grid.add_child(_make_showdex_stage_selector(
			stat_key,
			clampi(int(values.get(stat_key, 0)), -6, 6),
			public_values.has(stat_key),
			boosts_are_edited
		))
	_update_live_ev_total()


func _make_showdex_ev_input(stat_key: String, value: int) -> LineEdit:
	var input := LineEdit.new()
	input.name = "ShowdexEv%s" % stat_key.capitalize()
	input.text = str(clampi(value, 0, 252))
	input.placeholder_text = "0"
	input.custom_minimum_size = Vector2(46, 26)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.max_length = 3
	input.tooltip_text = _get_ev_full_display_name(stat_key)
	input.add_theme_font_size_override("font_size", 10)
	input.add_theme_color_override("font_color", EV_LABEL_ACCENT if value > 0 else TEXT_SECONDARY)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	input.add_theme_stylebox_override("normal", _make_stylebox(Color(SURFACE_CANVAS, 0.98), Color(BORDER_NEUTRAL, 0.86), 4, 3.0, 1.0))
	input.add_theme_stylebox_override("focus", _make_stylebox(Color(SURFACE_RAISED, 0.98), DROPDOWN_FOCUS_BORDER, 4, 3.0, 1.0))
	input.focus_entered.connect(_remember_live_ev_input_focus.bind(stat_key))
	input.text_changed.connect(_on_live_ev_text_changed.bind(stat_key))
	live_ev_inputs[stat_key] = input
	return input


func _make_showdex_stage_selector(stat_key: String, current_stage: int, is_public: bool, is_edited: bool) -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "ShowdexStage%s" % stat_key.capitalize()
	selector.custom_minimum_size = Vector2(46, 26)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.tooltip_text = _t("battle.calc.stat_modifiers")
	for stage in range(-6, 7):
		selector.add_item("+%d" % stage if stage > 0 else str(stage))
		selector.set_item_metadata(selector.item_count - 1, stage)
		if stage == current_stage:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_boost_stage_selected.bind(selector, stat_key))
	_apply_calcdex_dropdown_style(selector, 26.0, 9)
	_apply_boost_stage_style(selector, current_stage, is_public, is_edited)
	return selector


func _add_showdex_condition_controls(assumptions: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "ShowdexFieldControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_PANEL, 0.92), Color(BORDER_NEUTRAL, 0.72), 7, 6.0, 4.0)
	)
	_add_render_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	_add_advanced_scenario_controls(box, assumptions)


func _get_public_opponent_boosts() -> Dictionary:
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	if opponent.is_empty():
		return {}
	var knowledge := CALCDEX_SNAPSHOT.get_knowledge_value(opponent, "boosts")
	if str(knowledge.get("state", "")) != "known":
		return {}
	return _as_dictionary(knowledge.get("value", {})).duplicate(true)


func _apply_boost_stage_style(selector: OptionButton, stage: int, is_public: bool, is_edited: bool) -> void:
	var font_color := TEXT_SECONDARY
	var background := Color(SURFACE_RAISED, 0.84)
	if stage > 0:
		font_color = STAGE_POSITIVE
		background = Color(0.035, 0.12, 0.075, 0.88)
	elif stage < 0:
		font_color = STAGE_NEGATIVE
		background = Color(0.14, 0.035, 0.045, 0.88)
	var border := Color(BORDER_NEUTRAL, 0.86)
	if is_public and not is_edited and stage != 0:
		border = Color(CONFIRMED_ACCENT, 0.88)
	elif is_edited:
		border = CHIP_EDITED_BORDER
	selector.add_theme_color_override("font_color", font_color)
	selector.add_theme_color_override("font_hover_color", font_color.lightened(0.08))
	selector.add_theme_color_override("font_pressed_color", font_color)
	selector.add_theme_stylebox_override("normal", _make_stylebox(background, border, 6, 7.0, 2.0))
	selector.add_theme_stylebox_override("hover", _make_stylebox(background.lightened(0.05), border.lightened(0.10), 6, 7.0, 2.0))
	selector.add_theme_stylebox_override("pressed", _make_stylebox(background.lightened(0.02), border.lightened(0.16), 6, 7.0, 2.0))
	selector.add_theme_stylebox_override("focus", _make_stylebox(background, TEXT_ACCENT, 6, 7.0, 2.0))


func _get_effective_opponent_boosts(assumptions: Dictionary = {}) -> Dictionary:
	var values: Dictionary = {}
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	if not opponent.is_empty():
		var knowledge := CALCDEX_SNAPSHOT.get_knowledge_value(opponent, "boosts")
		if str(knowledge.get("state", "")) == "known":
			values = _as_dictionary(knowledge.get("value", {})).duplicate(true)
	var scenario_boosts := _as_dictionary(assumptions.get("boosts", defender_assumptions.get("boosts", {})))
	for stat_key: String in BOOST_STAT_KEYS:
		if scenario_boosts.has(stat_key):
			values[stat_key] = clampi(int(scenario_boosts.get(stat_key, 0)), -6, 6)
	return values


func _on_boost_stage_selected(index: int, selector: OptionButton, stat_key: String) -> void:
	_set_opponent_boost_stage(stat_key, int(selector.get_item_metadata(index)))


func _set_opponent_boost_stage(stat_key: String, stage: int) -> void:
	if stat_key not in BOOST_STAT_KEYS:
		return
	_mark_sample_set_custom()
	var effective := _get_effective_opponent_boosts(defender_assumptions)
	var boosts: Dictionary = {}
	for key: String in BOOST_STAT_KEYS:
		boosts[key] = clampi(stage if key == stat_key else int(effective.get(key, 0)), -6, 6)
	defender_assumptions["boosts"] = boosts
	edited_assumption_fields["boosts"] = true
	_emit_defender_assumptions_changed()
	_render_current_state()


func _on_inline_move_focus_entered(slot: int, input: LineEdit) -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = SELECTOR_MOVE
	active_move_slot = slot
	move_assumption_input = input
	selector_query = input.text.strip_edges()
	selector_results = []
	selector_loading = true
	selector_error = ""
	for box_value: Variant in inline_move_result_boxes.values():
		var box := box_value as VBoxContainer
		if box != null:
			box.visible = false
	for panel_value: Variant in inline_move_result_panels.values():
		var suggestions_panel := panel_value as PanelContainer
		if suggestions_panel != null:
			suggestions_panel.visible = false
	catalog_results_box = inline_move_result_boxes.get(slot) as VBoxContainer
	if catalog_results_box != null:
		catalog_results_box.visible = true
		var active_panel := inline_move_result_panels.get(slot) as PanelContainer
		if active_panel != null:
			active_panel.visible = true
	_refresh_catalog_results()
	_request_active_catalog()


func _on_inline_move_text_changed(text: String, slot: int, input: LineEdit) -> void:
	if is_syncing_assumption_controls:
		return
	active_selector = SELECTOR_MOVE
	active_move_slot = slot
	move_assumption_input = input
	selector_query = text
	if catalog_search_timer == null:
		_request_active_catalog()
	else:
		catalog_search_timer.start()


func _on_inline_move_text_submitted(text: String, slot: int) -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = SELECTOR_MOVE
	active_move_slot = slot
	var move_name := text.strip_edges()
	if move_name == "":
		_on_catalog_assumption_clear_pressed(SELECTOR_MOVE)
		return
	var first_suggestion := _get_first_selector_result()
	if not first_suggestion.is_empty():
		_on_selector_result_pressed(first_suggestion)
		return
	_on_selector_result_pressed({"name": move_name, "calcName": move_name})


func _get_visible_opponent_move_names(results: Array = []) -> Array[String]:
	var names: Array[String] = []
	if bool(defender_assumptions.get("replaceMoves", false)):
		for value: Variant in _as_array(defender_assumptions.get("assumedMoves", [])):
			_append_unique_move_name(names, str(value))
		return names

	for result_value: Variant in results:
		_append_unique_move_name(names, _get_move_name(_as_dictionary(result_value)))
	if names.is_empty():
		var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
		for move_value: Variant in _as_array(opponent.get("moves", [])):
			_append_unique_move_name(names, str(_as_dictionary(move_value).get("name", "")))
	for value: Variant in _as_array(defender_assumptions.get("assumedMoves", [])):
		_append_unique_move_name(names, str(value))
	return names


func _append_unique_move_name(names: Array[String], raw_name: String) -> void:
	var move_name := raw_name.strip_edges()
	if move_name == "" or move_name.length() > 100 or names.size() >= 4:
		return
	var normalized := _normalize_move_name(move_name)
	for existing: String in names:
		if _normalize_move_name(existing) == normalized:
			return
	names.append(move_name)


func _set_explicit_opponent_move_names(move_values: Array) -> void:
	var moves: Array[String] = []
	for value: Variant in move_values:
		_append_unique_move_name(moves, str(value))
	defender_assumptions["assumedMoves"] = moves
	defender_assumptions["replaceMoves"] = true
	edited_assumption_fields["assumedMoves"] = true
	edited_assumption_fields["replaceMoves"] = true
	_clear_move_scenarios()

func _add_advanced_scenario_controls(parent: VBoxContainer, assumptions: Dictionary) -> void:
	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 7)
	var condition_surface := PanelContainer.new()
	condition_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	condition_surface.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_RAISED, 0.86), Color(BORDER_NEUTRAL, 0.78), 7, 9.0, 7.0)
	)
	condition_surface.add_child(editor)
	parent.add_child(condition_surface)

	editor.add_child(_make_condition_section_header(
		_t("battle.calc.conditions_global"),
		CONDITION_GLOBAL_ACCENT
	))
	var field_row := HBoxContainer.new()
	field_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_row.add_theme_constant_override("separation", 7)
	field_row.add_child(_make_field_scenario_selector_card("weather", FIELD_WEATHER_VALUES, _t("battle.calc.condition.weather")))
	field_row.add_child(_make_field_scenario_selector_card("terrain", FIELD_TERRAIN_VALUES, _t("battle.calc.condition.terrain")))
	editor.add_child(field_row)
	editor.add_child(_make_condition_separator())

	var target_relation := _get_condition_target_relation()
	var target_accent := CONDITION_OWN_ACCENT if target_relation == "own" else CONDITION_OPPONENT_ACCENT
	editor.add_child(_make_condition_section_header(_get_condition_target_title(target_relation), target_accent))
	editor.add_child(_make_field_side_condition_content(target_relation, target_accent))

	var scope_note := _make_label(_t("battle.calc.conditions_direct_only"), 10, TEXT_SECONDARY)
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope_note.clip_text = false
	editor.add_child(scope_note)


func _on_advanced_scenario_pressed() -> void:
	advanced_scenario_expanded = not advanced_scenario_expanded
	_render_current_state()


func _make_disclosure_button(text: String, expanded: bool, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s  %s" % ["-" if expanded else "+", text]
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 28)
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


func _make_condition_section_header(title_text: String, accent_color: Color) -> HBoxContainer:
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 6)
	var accent := ColorRect.new()
	accent.color = accent_color
	accent.custom_minimum_size = Vector2(3, 15)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(accent)
	var title := _make_label(title_text.to_upper(), 10, TEXT_PRIMARY)
	title.clip_text = false
	title_row.add_child(title)
	return title_row


func _make_condition_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 3)
	separator.add_theme_stylebox_override(
		"separator",
		_make_stylebox(Color.TRANSPARENT, Color(CHIP_BORDER, 0.42), 0, 0.0, 0.0)
	)
	return separator


func _get_condition_target_title(relation: String) -> String:
	var pokemon_ref := selected_viewer_ref if relation == "own" else selected_opponent_ref
	var pokemon := _get_snapshot_pokemon_by_ref(pokemon_ref)
	var fallback := _t("battle.calc.your_pokemon") if relation == "own" else _t("battle.calc.opponent")
	var pokemon_name := fallback if pokemon.is_empty() else _snapshot_pokemon_name(pokemon)
	return "%s · %s" % [_t("battle.calc.target"), pokemon_name]


func _make_field_scenario_selector_card(key: String, values: Array, label_text: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 3)
	var label := _make_label(label_text.to_upper(), 10, TEXT_SECONDARY)
	label.clip_text = false
	card.add_child(label)
	card.add_child(_make_field_scenario_selector(key, values))
	return card


func _make_field_scenario_selector(key: String, values: Array) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value: Variant in values:
		var normalized := str(value)
		selector.add_item(_get_field_scenario_option_label(key, normalized))
		selector.set_item_metadata(selector.item_count - 1, normalized)
		if normalized == str(field_scenario.get(key, "")):
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(_on_field_scenario_selected.bind(selector, key))
	_apply_calcdex_dropdown_style(selector, 34.0, 11)
	return selector


func _make_field_side_condition_content(relation: String, accent_color: Color) -> HBoxContainer:
	var section_row := HBoxContainer.new()
	section_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_row.add_theme_constant_override("separation", 10)

	var defense_column := VBoxContainer.new()
	defense_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defense_column.add_theme_constant_override("separation", 5)
	section_row.add_child(defense_column)
	var defense_label := _make_label(
		_t("battle.calc.condition.defensive_effects").to_upper(),
		9,
		Color(accent_color, 0.94)
	)
	defense_label.clip_text = false
	defense_column.add_child(defense_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	defense_column.add_child(grid)
	for condition: Dictionary in FIELD_SIDE_CONDITIONS:
		grid.add_child(_make_field_side_condition_button(relation, condition))

	var state_column := VBoxContainer.new()
	state_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_column.add_theme_constant_override("separation", 5)
	section_row.add_child(state_column)
	var hazard_label := _make_label(
		_t("battle.calc.condition.entry_hazards").to_upper(),
		9,
		Color(accent_color, 0.94)
	)
	hazard_label.clip_text = false
	state_column.add_child(hazard_label)
	var hazard_grid := GridContainer.new()
	hazard_grid.columns = 2
	hazard_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hazard_grid.add_theme_constant_override("h_separation", 6)
	hazard_grid.add_theme_constant_override("v_separation", 6)
	state_column.add_child(hazard_grid)
	for condition: Dictionary in FIELD_SIDE_HAZARDS:
		hazard_grid.add_child(_make_field_side_condition_button(relation, condition))
	hazard_grid.add_child(_make_field_side_spikes_selector(relation))
	return section_row


func _make_pokemon_status_selector(relation: String, compact: bool = false) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirmed_status := _get_public_pokemon_status(relation)
	var scenario_key := "%sStatus" % relation
	var scenario_status := str(field_scenario.get(scenario_key, "")).strip_edges().to_lower()
	for status: String in POKEMON_STATUS_VALUES:
		var option_label := _get_status_label(status)
		if status == "":
			var current_label := _get_status_label(confirmed_status)
			option_label = _t("battle.calc.condition.current", {"value": current_label})
		if compact:
			var compact_value := _get_status_label(confirmed_status) if status == "" else _get_status_label(status)
			option_label = compact_value
		selector.add_item(option_label)
		selector.set_item_metadata(selector.item_count - 1, status)
		if confirmed_status == "" and status == scenario_status:
			selector.select(selector.item_count - 1)
	selector.disabled = confirmed_status != ""
	if selector.disabled:
		selector.select(0)
		selector.tooltip_text = _t("battle.calc.condition_confirmed_tooltip")
	else:
		selector.tooltip_text = _t("battle.calc.status_scenario_tooltip")
		selector.item_selected.connect(_on_pokemon_status_selected.bind(selector, relation))
	_apply_calcdex_dropdown_style(selector, 28.0 if compact else 32.0, 10 if compact else 11)
	if selector.disabled:
		selector.add_theme_color_override("font_disabled_color", TEXT_SECONDARY)
	return selector


func _on_pokemon_status_selected(index: int, selector: OptionButton, relation: String = "opponent") -> void:
	if relation not in ["own", "opponent"] or _get_public_pokemon_status(relation) != "":
		return
	var status := str(selector.get_item_metadata(index)).to_lower()
	var scenario_key := "%sStatus" % relation
	_mark_sample_set_custom()
	if status == "":
		field_scenario.erase(scenario_key)
	else:
		field_scenario[scenario_key] = status
	_emit_defender_assumptions_changed()
	_render_current_state()


func _make_field_side_condition_button(relation: String, condition: Dictionary) -> Button:
	var suffix := str(condition.get("suffix", ""))
	var scenario_key := "%s%s" % [relation, suffix]
	var public_active := _is_public_side_condition_active(relation, suffix)
	var button := Button.new()
	button.text = _t(str(condition.get("label_key", "")))
	button.toggle_mode = true
	button.button_pressed = public_active or bool(field_scenario.get(scenario_key, false))
	button.disabled = public_active
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", STAGE_POSITIVE)
	button.add_theme_stylebox_override("normal", _make_stylebox(CHIP_BG, CHIP_BORDER, 5, 6.0, 3.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(DROPDOWN_HOVER_BG, DROPDOWN_HOVER_BORDER, 5, 6.0, 3.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, TEXT_ACCENT, 5, 6.0, 3.0))
	button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.025, 0.10, 0.065, 0.92), STAGE_POSITIVE.darkened(0.2), 5, 6.0, 3.0))
	if public_active:
		button.tooltip_text = _t("battle.calc.condition_confirmed_tooltip")
	else:
		button.toggled.connect(_on_field_side_condition_toggled.bind(scenario_key))
	return button


func _on_field_side_condition_toggled(enabled: bool, scenario_key: String) -> void:
	if enabled:
		field_scenario[scenario_key] = true
	else:
		field_scenario.erase(scenario_key)
	matchup_selection_changed.emit()
	_render_current_state()


func _make_field_side_spikes_selector(relation: String) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var public_layers := _get_public_side_spikes_layers(relation)
	var scenario_key := "%sSpikes" % relation
	var selected_layers := public_layers if public_layers > 0 else clampi(int(field_scenario.get(scenario_key, 0)), 0, 3)
	for layers in range(0, 4):
		var label := _get_spikes_option_label(layers)
		if public_layers > 0 and layers == public_layers:
			label = _t("battle.calc.condition.current", {"value": label})
		selector.add_item(label)
		selector.set_item_metadata(selector.item_count - 1, layers)
		if layers == selected_layers:
			selector.select(selector.item_count - 1)
	selector.disabled = public_layers > 0
	selector.tooltip_text = _t("battle.calc.condition_confirmed_tooltip") if selector.disabled else _t("battle.calc.hazard_scenario_tooltip")
	if not selector.disabled:
		selector.item_selected.connect(_on_field_side_spikes_selected.bind(selector, scenario_key))
	_apply_calcdex_dropdown_style(selector, 30.0, 10)
	if selector.disabled:
		selector.add_theme_color_override("font_disabled_color", TEXT_SECONDARY)
	return selector


func _get_spikes_option_label(layers: int) -> String:
	if layers <= 0:
		return _t("battle.calc.condition.spikes_none")
	return _t("battle.calc.condition.spikes_layers", {"layers": layers})


func _on_field_side_spikes_selected(index: int, selector: OptionButton, scenario_key: String) -> void:
	var layers := clampi(int(selector.get_item_metadata(index)), 0, 3)
	if layers > 0:
		field_scenario[scenario_key] = layers
	else:
		field_scenario.erase(scenario_key)
	matchup_selection_changed.emit()
	_render_current_state()


func _on_field_scenario_selected(index: int, selector: OptionButton, key: String) -> void:
	var value := str(selector.get_item_metadata(index))
	if value == "":
		field_scenario.erase(key)
	else:
		field_scenario[key] = value
	matchup_selection_changed.emit()
	_render_current_state()


func _get_field_scenario_option_label(key: String, value: String) -> String:
	if value != "":
		return _get_field_condition_value_label(key, value)
	var current_value := _get_public_global_field_value(key)
	if current_value == "":
		return _t("common.none")
	return _t("battle.calc.condition.current", {"value": _get_field_condition_value_label(key, current_value)})


func _get_field_condition_value_label(key: String, value: String) -> String:
	var localization_key := "battle.calc.condition.%s.%s" % [key, value.to_lower()]
	var translated := _t(localization_key)
	return value if translated == localization_key else translated


func _get_effective_field_condition_labels() -> Array[String]:
	var labels: Array[String] = []
	for key: String in ["weather", "terrain"]:
		var value := str(field_scenario.get(key, "")).strip_edges()
		if value == "":
			value = _get_public_global_field_value(key)
		if value != "":
			labels.append(_get_field_condition_value_label(key, value))
	var relation := _get_condition_target_relation()
	var relation_label := _t("battle.calc.conditions_your_side") if relation == "own" else _t("battle.calc.conditions_opponent_side")
	for condition: Dictionary in FIELD_SIDE_CONDITIONS:
		var suffix := str(condition.get("suffix", ""))
		if bool(field_scenario.get("%s%s" % [relation, suffix], false)) or _is_public_side_condition_active(relation, suffix):
			labels.append("%s: %s" % [relation_label, _t(str(condition.get("label_key", "")))])
	for condition: Dictionary in FIELD_SIDE_HAZARDS:
		var suffix := str(condition.get("suffix", ""))
		if bool(field_scenario.get("%s%s" % [relation, suffix], false)) or _is_public_side_condition_active(relation, suffix):
			labels.append("%s: %s" % [relation_label, _t(str(condition.get("label_key", "")))])
	var spikes := _get_public_side_spikes_layers(relation)
	if spikes <= 0:
		spikes = clampi(int(field_scenario.get("%sSpikes" % relation, 0)), 0, 3)
	if spikes > 0:
		labels.append("%s: %s" % [relation_label, _get_spikes_option_label(spikes)])
	return labels


func _get_effective_pokemon_status(relation: String) -> String:
	var confirmed_status := _get_public_pokemon_status(relation)
	if confirmed_status != "":
		return confirmed_status
	var scenario_status := str(field_scenario.get("%sStatus" % relation, "")).strip_edges().to_lower()
	if scenario_status in POKEMON_STATUS_VALUES:
		return scenario_status
	return ""


func _clear_confirmed_status_scenarios() -> void:
	for relation: String in ["own", "opponent"]:
		if _get_public_pokemon_status(relation) != "":
			field_scenario.erase("%sStatus" % relation)


func _get_public_pokemon_status(relation: String) -> String:
	var pokemon_ref := selected_viewer_ref if relation == "own" else selected_opponent_ref
	var pokemon := _get_snapshot_pokemon_by_ref(pokemon_ref)
	var knowledge := _as_dictionary(pokemon.get("status", {}))
	if str(knowledge.get("state", "")) != "known":
		return ""
	var status := str(knowledge.get("value", "")).strip_edges().to_lower()
	return status if status in POKEMON_STATUS_VALUES else ""


func _get_status_label(status: String) -> String:
	if status == "":
		return _t("battle.calc.condition.status.healthy")
	var key := "battle.calc.condition.status.%s" % status
	var translated := _t(key)
	return status.to_upper() if translated == key else translated


func _get_status_compact_label(status: String) -> String:
	var key := str({
		"brn": "battle.status.compact.burn",
		"par": "battle.status.compact.paralysis",
		"slp": "battle.status.compact.sleep",
		"frz": "battle.status.compact.freeze",
		"psn": "battle.status.compact.poison",
		"tox": "battle.status.compact.toxic",
	}.get(status, ""))
	return _t(key) if key != "" else status.to_upper()


func _get_public_global_field_value(key: String) -> String:
	for effect_value: Variant in _get_public_field_effects():
		var effect := _as_dictionary(effect_value)
		var effect_id := _normalize_field_effect_id(str(effect.get("effectId", "")))
		if key == "weather":
			match effect_id:
				"rain", "raindance":
					return "Rain"
				"sun", "sunnyday":
					return "Sun"
				"sandstorm":
					return "Sand"
				"hail":
					return "Hail"
				"snow":
					return "Snow"
		elif key == "terrain":
			match effect_id:
				"electricterrain":
					return "Electric"
				"grassyterrain":
					return "Grassy"
				"mistyterrain":
					return "Misty"
				"psychicterrain":
					return "Psychic"
	return ""


func _is_public_side_condition_active(relation: String, suffix: String) -> bool:
	var viewer_side := str(knowledge_snapshot.get("viewerSide", ""))
	if viewer_side not in ["p1", "p2"]:
		return false
	var expected_side := viewer_side if relation == "own" else ("p2" if viewer_side == "p1" else "p1")
	var expected_effect_id: String = str({
		"Reflect": "reflect",
		"LightScreen": "lightscreen",
		"AuroraVeil": "auroraveil",
		"StealthRock": "stealthrock",
	}.get(suffix, ""))
	for effect_value: Variant in _get_public_field_effects():
		var effect := _as_dictionary(effect_value)
		if str(effect.get("side", "")) == expected_side \
				and _normalize_field_effect_id(str(effect.get("effectId", ""))) == expected_effect_id:
			return true
	return false


func _get_public_side_spikes_layers(relation: String) -> int:
	var viewer_side := str(knowledge_snapshot.get("viewerSide", ""))
	if viewer_side not in ["p1", "p2"]:
		return 0
	var expected_side := viewer_side if relation == "own" else ("p2" if viewer_side == "p1" else "p1")
	for effect_value: Variant in _get_public_field_effects():
		var effect := _as_dictionary(effect_value)
		if str(effect.get("side", "")) == expected_side \
				and _normalize_field_effect_id(str(effect.get("effectId", ""))) == "spikes":
			return clampi(int(effect.get("layers", 1)), 1, 3)
	return 0


func _get_public_field_effects() -> Array:
	var field := _as_dictionary(knowledge_snapshot.get("field", {}))
	return _as_array(field.get("effects", []))


func _normalize_field_effect_id(value: String) -> String:
	var normalized := ""
	for character: String in value.to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			normalized += character
	return normalized


func _make_live_ev_input(stat_key: String, value: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 40)
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_PANEL, 0.96), Color(BORDER_NEUTRAL, 0.82), 5, 5.0, 4.0)
	)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)

	var label := _make_label(_get_ev_full_display_name(stat_key), 10, TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(82, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.tooltip_text = "%s (%s)" % [_get_ev_full_display_name(stat_key), _get_ev_display_name(stat_key)]
	row.add_child(label)

	var input := LineEdit.new()
	input.text = str(clampi(value, 0, 252))
	input.placeholder_text = "0"
	input.custom_minimum_size = Vector2(54, 25)
	input.size_flags_horizontal = Control.SIZE_SHRINK_END
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.max_length = 3
	input.add_theme_font_size_override("font_size", 11)
	input.add_theme_color_override("font_color", TEXT_PRIMARY)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	input.add_theme_stylebox_override("normal", _make_stylebox(Color(SURFACE_CANVAS, 0.98), Color(BORDER_NEUTRAL, 0.90), 4, 5.0, 2.0))
	input.add_theme_stylebox_override("focus", _make_stylebox(Color(SURFACE_RAISED, 0.98), DROPDOWN_FOCUS_BORDER, 4, 5.0, 2.0))
	input.focus_entered.connect(_remember_live_ev_input_focus.bind(stat_key))
	input.text_changed.connect(_on_live_ev_text_changed.bind(stat_key))
	live_ev_inputs[stat_key] = input
	row.add_child(input)

	row.add_child(_make_ev_quick_button(_t("battle.calc.ev_min_short"), _t("battle.calc.ev_set_zero"), false, _on_live_ev_quick_value_pressed.bind(stat_key, 0)))
	row.add_child(_make_ev_quick_button(_t("battle.calc.ev_max_short"), _t("battle.calc.ev_set_max"), true, _on_live_ev_quick_value_pressed.bind(stat_key, 252)))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 4)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 252.0
	bar.value = clampi(value, 0, 252)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _make_stylebox(Color(SURFACE_CANVAS, 0.98), Color(BORDER_NEUTRAL, 0.72), 3, 0.0, 0.0))
	bar.add_theme_stylebox_override("fill", _make_stylebox(Color(INTERACTION_ACCENT, 0.76), INTERACTION_ACCENT, 3, 0.0, 0.0))
	live_ev_bars[stat_key] = bar
	box.add_child(bar)
	return panel


func _make_ev_quick_button(text: String, tooltip: String, is_maximum: bool, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(40, 23)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 9)
	var font_color := LABEL_NEUTRAL
	var background := Color(SURFACE_RAISED, 0.98)
	var border := Color(BORDER_NEUTRAL, 0.92)
	if is_maximum:
		font_color = Color(0.66, 0.95, 0.74, 1.0)
		background = Color(0.035, 0.12, 0.075, 0.96)
		border = Color(0.27, 0.68, 0.42, 0.92)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", font_color.lightened(0.12))
	button.add_theme_stylebox_override("normal", _make_stylebox(background, border, 4, 4.0, 1.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(background.lightened(0.07), border.lightened(0.12), 4, 4.0, 1.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(background.lightened(0.03), TEXT_ACCENT if is_maximum else DROPDOWN_HOVER_BORDER, 4, 4.0, 1.0))
	button.add_theme_stylebox_override("focus", _make_stylebox(background, DROPDOWN_FOCUS_BORDER, 4, 4.0, 1.0))
	button.pressed.connect(pressed_callback)
	return button


func _make_assumption_reset_button() -> Button:
	var button := Button.new()
	button.text = _t("common.reset").to_upper()
	button.tooltip_text = _t("battle.calc.reset_setup_tooltip")
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(58, 24)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_ACCENT)
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(Color(SURFACE_PANEL, 0.72), Color(BORDER_NEUTRAL, 0.58), 5, 6.0, 1.0)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(Color(SURFACE_RAISED, 0.98), Color(INTERACTION_ACCENT, 0.72), 6, 8.0, 2.0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(TAB_ACTIVE_BG, INTERACTION_ACCENT, 6, 8.0, 2.0)
	)
	button.pressed.connect(_reset_live_assumptions)
	return button


func _get_catalog_assumption_value(assumptions: Dictionary, kind: String) -> String:
	var value: String = str(assumptions.get(kind, "")).strip_edges()
	return "" if value == "<null>" else value


func _make_inline_assumption_field(caption: String, value: String, editor_kind: String, tooltip: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%sAssumptionField" % editor_kind.capitalize()
	panel.tooltip_text = _fallback_text(tooltip, "%s: %s" % [caption, value])
	panel.custom_minimum_size = Vector2(0, 46)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var is_active: bool = active_selector == editor_kind
	var visual_palette := _get_assumption_visual_palette(_get_assumption_visual_state(editor_kind), editor_kind)
	var border: Color = visual_palette["border"]
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(TAB_ACTIVE_BG if is_active else visual_palette["background"], border, 6, 7.0, 3.0)
	)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.clip_contents = true
	labels.add_theme_constant_override("separation", 0)
	panel.add_child(labels)
	var caption_label := _make_label(caption.to_upper(), 8, Color(0.65, 0.82, 0.94, 1.0) if is_active else visual_palette["caption"])
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(caption_label)

	var input := LineEdit.new()
	input.text = value
	input.placeholder_text = _localized_nature_name("Hardy") if editor_kind == SELECTOR_NATURE else _t("common.none")
	input.tooltip_text = panel.tooltip_text
	input.custom_minimum_size = Vector2(0, 25)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 100
	input.right_icon = DROPDOWN_ARROW
	input.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	input.add_theme_font_size_override("font_size", 11)
	input.add_theme_color_override("font_color", TEXT_PRIMARY if is_active else visual_palette["value"])
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	input.add_theme_stylebox_override("normal", _make_stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0.0, 0.0))
	input.add_theme_stylebox_override("focus", _make_stylebox(Color(TAB_ACTIVE_BG.r, TAB_ACTIVE_BG.g, TAB_ACTIVE_BG.b, 0.54), TEXT_ACCENT, 4, 3.0, 0.0))
	input.focus_entered.connect(_on_catalog_assumption_focus_entered.bind(editor_kind))
	input.focus_exited.connect(_on_catalog_assumption_focus_exited.bind(editor_kind))
	input.text_changed.connect(_on_catalog_assumption_text_changed.bind(editor_kind))
	input.text_submitted.connect(_on_inline_assumption_text_submitted.bind(editor_kind))
	labels.add_child(input)

	if editor_kind == SELECTOR_ITEM:
		item_assumption_input = input
	elif editor_kind == SELECTOR_ABILITY:
		ability_assumption_input = input
	elif editor_kind == SELECTOR_NATURE:
		nature_assumption_input = input
	return panel


func _make_assumption_summary_button(caption: String, value: String, editor_kind: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.tooltip_text = _fallback_text(tooltip, "%s: %s" % [caption, value])
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_active: bool = active_selector == editor_kind
	var visual_palette := _get_assumption_visual_palette(_get_assumption_visual_state(editor_kind), editor_kind)
	var chip_border: Color = visual_palette["border"]
	var value_color: Color = TEXT_PRIMARY if is_active else visual_palette["value"]
	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(TAB_ACTIVE_BG if is_active else visual_palette["background"], chip_border, 6, 7.0, 4.0)
	)
	button.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE_BG.lightened(0.08), chip_border.lightened(0.12), 7, 8.0, 5.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE_BG, chip_border.lightened(0.18), 7, 8.0, 5.0))

	var labels := VBoxContainer.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.offset_left = 8.0
	labels.offset_top = 4.0
	labels.offset_right = -8.0
	labels.offset_bottom = -4.0
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_constant_override("separation", 1)
	button.add_child(labels)
	var caption_label := _make_label(caption.to_upper(), 8, Color(0.65, 0.82, 0.94, 1.0) if is_active else visual_palette["caption"])
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(caption_label)
	var value_label := _make_label(value, 11, value_color)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.tooltip_text = button.tooltip_text
	labels.add_child(value_label)
	button.pressed.connect(_on_assumption_summary_pressed.bind(editor_kind))
	return button


func _get_assumption_visual_state(editor_kind: String) -> String:
	if bool(edited_assumption_fields.get(editor_kind, false)):
		return "manual"
	var opponent := _get_snapshot_pokemon_by_ref(selected_opponent_ref)
	var knowledge := _as_dictionary(opponent.get("evs" if editor_kind == SELECTOR_EVS else editor_kind, {}))
	if str(knowledge.get("state", "")) == "known":
		return "confirmed"
	return "default"


func _get_assumption_visual_palette(visual_state: String, editor_kind: String = "") -> Dictionary:
	match visual_state:
		"confirmed":
			return {
				"background": Color(0.018, 0.075, 0.052, 0.86),
				"border": Color(CONFIRMED_ACCENT, 0.80),
				"caption": Color(CONFIRMED_ACCENT, 0.88),
				"value": Color(0.73, 0.96, 0.80, 1.0),
			}
		"manual":
			return {
				"background": Color(0.095, 0.066, 0.022, 0.86),
				"border": Color(MANUAL_ACCENT, 0.88),
				"caption": Color(MANUAL_ACCENT, 0.90),
				"value": Color(1.0, 0.86, 0.57, 1.0),
			}
	return {
		"background": Color(CHIP_BG.r, CHIP_BG.g, CHIP_BG.b, 0.72),
		"border": Color(CHIP_BORDER.r, CHIP_BORDER.g, CHIP_BORDER.b, 0.58),
		"caption": _get_assumption_label_accent(editor_kind),
		"value": TEXT_SECONDARY,
	}


func _get_assumption_label_accent(editor_kind: String) -> Color:
	match editor_kind:
		SELECTOR_ITEM:
			return ITEM_LABEL_ACCENT
		SELECTOR_ABILITY:
			return ABILITY_LABEL_ACCENT
		SELECTOR_NATURE:
			return NATURE_LABEL_ACCENT
		SELECTOR_EVS:
			return EV_LABEL_ACCENT
	return TEXT_MUTED


func _get_stat_label_accent(stat_key: String) -> Color:
	if stat_key in ["atk", "spa"]:
		return OFFENSE_LABEL_ACCENT
	if stat_key in ["def", "spd"]:
		return DEFENSE_LABEL_ACCENT
	if stat_key == "spe":
		return SPEED_LABEL_ACCENT
	return TEXT_MUTED


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
			return _t("battle.calc.ev_spread")
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

	catalog_suggestions_box.visible = active_selector != SELECTOR_NONE and active_selector != SELECTOR_MOVE
	if active_selector == SELECTOR_NONE or active_selector == SELECTOR_MOVE:
		return

	match active_selector:
		SELECTOR_ITEM, SELECTOR_ABILITY, SELECTOR_NATURE:
			_render_inline_assumption_results()
		SELECTOR_EVS:
			_render_evs_assumption_editor(_as_dictionary(assumptions.get("evs", {})))


func _render_inline_assumption_results() -> void:
	var suggestions_panel := _make_selector_suggestions_panel()
	catalog_suggestions_box.add_child(suggestions_panel)
	catalog_results_box = VBoxContainer.new()
	catalog_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_results_box.clip_contents = true
	catalog_results_box.add_theme_constant_override("separation", 3)
	suggestions_panel.add_child(catalog_results_box)
	_refresh_catalog_results()


func _make_selector_suggestions_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_RAISED, 0.98), Color(INTERACTION_ACCENT, 0.82), 7, 8.0, 8.0)
	)
	return panel


func _ensure_inline_assumption_results() -> void:
	if catalog_suggestions_box == null:
		return
	catalog_suggestions_box.visible = true
	if catalog_results_box != null and is_instance_valid(catalog_results_box):
		catalog_results_box.visible = true
		return
	_render_inline_assumption_results()


func _render_evs_assumption_editor(evs: Dictionary) -> void:
	var editor_panel := PanelContainer.new()
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(SURFACE_PANEL, 0.98), Color(BORDER_NEUTRAL, 0.88), 7, 7.0, 6.0)
	)
	catalog_suggestions_box.add_child(editor_panel)
	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 5)
	editor_panel.add_child(editor)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	editor.add_child(header)
	var title := _make_label(_t("battle.calc.ev_spread").to_upper(), 9, Color(0.62, 0.78, 0.90, 1.0))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	# Opponent EVs are calculation inputs; the total and progress bar do not
	# represent battle state and only add visual noise here.
	live_ev_total_label = null
	live_ev_total_bar = null
	var groups_row := HBoxContainer.new()
	groups_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups_row.add_theme_constant_override("separation", 6)
	editor.add_child(groups_row)
	for group_value: Variant in EV_INPUT_GROUPS:
		var group := group_value as Dictionary
		var group_box := VBoxContainer.new()
		group_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_box.add_theme_constant_override("separation", 3)
		groups_row.add_child(group_box)
		var group_label := _make_label(_t(str(group.get("label", ""))).to_upper(), 8, TEXT_MUTED)
		group_label.custom_minimum_size = Vector2(0, 15)
		group_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		group_box.add_child(group_label)
		for stat_key_value: Variant in group.get("stats", []):
			var stat_key := str(stat_key_value)
			group_box.add_child(_make_live_ev_input(stat_key, int(evs.get(stat_key, 0))))
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
	var stat_bar: ProgressBar = live_ev_bars.get(stat_key) as ProgressBar
	if stat_bar != null:
		stat_bar.value = clamped_value
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

	var is_over_limit := total > EV_TOTAL_LIMIT
	var is_complete := total == EV_TOTAL_LIMIT
	live_ev_total_label.text = _t("battle.calc.evs_allocated", {"total": total, "limit": EV_TOTAL_LIMIT})
	live_ev_total_label.add_theme_color_override("font_color", TEXT_ERROR if is_over_limit else (STAGE_POSITIVE if is_complete else TEXT_ACCENT))
	if live_ev_total_bar != null:
		live_ev_total_bar.value = mini(total, EV_TOTAL_LIMIT)
		var fill_color := TEXT_ERROR if is_over_limit else (STAGE_POSITIVE if is_complete else Color(INTERACTION_ACCENT, 0.78))
		live_ev_total_bar.add_theme_stylebox_override("background", _make_stylebox(Color(SURFACE_CANVAS, 0.98), Color(BORDER_NEUTRAL, 0.72), 3, 0.0, 0.0))
		live_ev_total_bar.add_theme_stylebox_override("fill", _make_stylebox(fill_color, fill_color.lightened(0.10), 3, 0.0, 0.0))


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
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_NATURE or kind == SELECTOR_MOVE:
		_refresh_catalog_results()


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
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_NATURE or kind == SELECTOR_MOVE:
		_refresh_catalog_results()


func show_assumption_catalog_error(kind: String, message: String) -> void:
	if kind != active_selector:
		return
	selector_loading = false
	selector_error = _fallback_text(message, _t("battle.calc.error.assumptions"))
	selector_results = []
	if kind == SELECTOR_ITEM or kind == SELECTOR_ABILITY or kind == SELECTOR_NATURE or kind == SELECTOR_MOVE:
		_refresh_catalog_results()


func is_assumption_catalog_request_current(kind: String, query: String) -> bool:
	return kind == active_selector and query == selector_query


func _make_selector_result_button(title: String, subtitle: String, pressed_callback: Callable, selected: bool = false, is_clear_action: bool = false) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = title if subtitle == "" else "%s · %s" % [title, subtitle]
	var normal_bg := Color(SURFACE_PANEL, 0.98)
	var normal_border := Color(BORDER_NEUTRAL, 0.92)
	if selected:
		normal_bg = Color(INTERACTION_ACCENT, 0.18)
		normal_border = Color(INTERACTION_ACCENT, 0.98)
	elif is_clear_action:
		normal_bg = Color(CHIP_BG, 0.96)
		normal_border = Color(BORDER_NEUTRAL, 0.78)
	button.add_theme_stylebox_override("normal", _make_stylebox(normal_bg, normal_border, 5, 7.0, 3.0))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(INTERACTION_ACCENT, 0.12), Color(INTERACTION_ACCENT, 0.72), 5, 7.0, 3.0))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(INTERACTION_ACCENT, 0.28), INTERACTION_ACCENT, 5, 7.0, 3.0))
	button.add_theme_stylebox_override("focus", _make_stylebox(normal_bg, DROPDOWN_FOCUS_BORDER, 5, 7.0, 3.0))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_top = 3.0
	row.offset_right = -8.0
	row.offset_bottom = -3.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)
	var indicator := _make_label("×" if is_clear_action else ("✓" if selected else ""), 11, TEXT_MUTED if is_clear_action else TEXT_ACCENT)
	indicator.custom_minimum_size = Vector2(14, 0)
	indicator.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(indicator)
	var title_label := _make_label(title, 11, TEXT_SECONDARY if is_clear_action else TEXT_PRIMARY)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_label)
	if subtitle != "":
		var subtitle_label := _make_label(subtitle, 9, TEXT_MUTED)
		subtitle_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(subtitle_label)
	button.pressed.connect(pressed_callback)
	return button


func _add_selector_status(parent: VBoxContainer, text: String, color: Color) -> void:
	var label := _make_label(text, 11, color)
	label.custom_minimum_size = Vector2(0, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _on_catalog_assumption_focus_entered(kind: String) -> void:
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	var input := _get_catalog_input(kind)
	if (
		kind == SELECTOR_NATURE
		and input != null
		and not bool(edited_assumption_fields.get("nature", false))
		and input.text.strip_edges().to_lower() == _localized_nature_name("Hardy").to_lower()
	):
		# Hardy is the neutral display default. Clear the display value on focus;
		# the Hardy placeholder remains visible while the user types a replacement.
		input.clear()
		input.caret_column = 0
	var input_text: String = _get_catalog_input_text(kind)
	if active_selector == kind and selector_query == input_text and selector_loading:
		return
	active_selector = kind
	selector_query = input_text
	selector_results = []
	selector_error = ""
	selector_loading = true
	if kind != SELECTOR_MOVE:
		_ensure_inline_assumption_results()
	_refresh_catalog_results()
	if kind == SELECTOR_NATURE:
		selector_loading = false
		_refresh_catalog_results()
		return
	_request_active_catalog()


func _on_catalog_assumption_focus_exited(kind: String) -> void:
	call_deferred("_close_assumption_suggestions_if_focus_left", kind)


func _close_assumption_suggestions_if_focus_left(kind: String) -> void:
	if is_clearing_content:
		return
	if active_selector != kind:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == item_assumption_input or focus_owner == ability_assumption_input or focus_owner == nature_assumption_input or focus_owner == move_assumption_input:
		return
	if catalog_suggestions_box != null and focus_owner != null and catalog_suggestions_box.is_ancestor_of(focus_owner):
		return
	if catalog_results_box != null and focus_owner != null and catalog_results_box.is_ancestor_of(focus_owner):
		return
	if kind == SELECTOR_MOVE and move_assumption_input != null and is_instance_valid(move_assumption_input):
		_on_inline_move_text_submitted(move_assumption_input.text, active_move_slot)
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
	if kind == SELECTOR_NATURE:
		selector_loading = false
		_ensure_inline_assumption_results()
		_refresh_catalog_results()
		return
	if catalog_search_timer == null:
		_request_active_catalog()
		return
	catalog_search_timer.start()


func _on_inline_assumption_text_submitted(text: String, kind: String) -> void:
	_commit_inline_assumption(text, kind)


func _commit_inline_assumption(text: String, kind: String) -> void:
	if kind not in [SELECTOR_ITEM, SELECTOR_ABILITY, SELECTOR_NATURE]:
		return
	if catalog_search_timer != null:
		catalog_search_timer.stop()
	active_selector = kind
	var cleaned := text.strip_edges()
	if kind == SELECTOR_NATURE:
		var nature := _get_first_nature_suggestion(cleaned) if cleaned != "" else _resolve_nature_calc_name(cleaned)
		if nature == "":
			selector_error = _t("battle.calc.no_results_short")
			_refresh_catalog_results()
			return
		_on_nature_option_pressed(nature)
		return
	if cleaned == "" or cleaned.to_lower() == "none" or cleaned.to_lower() == _t("common.none").to_lower():
		_on_catalog_assumption_clear_pressed(kind)
		return
	var first_suggestion := _get_first_selector_result()
	if not first_suggestion.is_empty():
		_on_selector_result_pressed(first_suggestion)
		return
	_on_selector_result_pressed({"name": cleaned, "calcName": cleaned})


func _get_first_selector_result() -> Dictionary:
	for result_value: Variant in selector_results:
		var result := _as_dictionary(result_value)
		var name := str(result.get("name", result.get("calcName", ""))).strip_edges()
		var calc_name := str(result.get("calcName", name)).strip_edges()
		if calc_name != "":
			return result
	return {}


func _get_first_nature_suggestion(value: String) -> String:
	var query := value.strip_edges().to_lower()
	for nature: String in _get_nature_option_names():
		if query == "" or nature.to_lower().contains(query) or _localized_nature_name(nature).to_lower().contains(query):
			return nature
	return _resolve_nature_calc_name(value)


func _resolve_nature_calc_name(value: String) -> String:
	if value == "":
		return "Hardy"
	for nature: String in _get_nature_option_names():
		if value.to_lower() == nature.to_lower() or value.to_lower() == _localized_nature_name(nature).to_lower():
			return nature
	return ""


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
		var moves: Array = _get_visible_opponent_move_names(_as_array(last_response.get("results", []))).duplicate()
		if active_move_slot >= 0 and active_move_slot < moves.size():
			moves.remove_at(active_move_slot)
		_set_explicit_opponent_move_names(moves)
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
		var moves: Array = _get_visible_opponent_move_names(_as_array(last_response.get("results", []))).duplicate()
		if active_move_slot >= 0 and active_move_slot < moves.size():
			moves.remove_at(active_move_slot)
		moves.erase(calc_name)
		var insert_at: int = clampi(active_move_slot, 0, moves.size())
		moves.insert(insert_at, calc_name)
		if moves.size() > 4:
			moves.resize(4)
		_set_explicit_opponent_move_names(moves)
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

	catalog_results_box.visible = active_selector in [SELECTOR_ITEM, SELECTOR_ABILITY, SELECTOR_NATURE, SELECTOR_MOVE]
	if not catalog_results_box.visible:
		return
	_add_selector_suggestions_header(catalog_results_box)
	if active_selector == SELECTOR_NATURE:
		_refresh_nature_catalog_results()
		return

	var clear_title := _t("battle.calc.clear_move_slot") if active_selector == SELECTOR_MOVE else _t("battle.calc.use_default_value")
	var clear_subtitle := "" if active_selector == SELECTOR_MOVE else _get_selector_default_label(active_selector)
	var clear_selected := active_selector != SELECTOR_MOVE and _get_catalog_input_text(active_selector) == ""
	var clear_button := _make_selector_result_button(
		clear_title,
		clear_subtitle,
		Callable(self, "_on_catalog_assumption_clear_pressed").bind(active_selector),
		clear_selected,
		true
	)
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
			subtitle = _join_string_array([move_type.capitalize(), category.capitalize()], " · ")
		var calc_name := str(result.get("calcName", name)).strip_edges()
		catalog_results_box.add_child(_make_selector_result_button(
			_fallback_text(name, _t("common.unknown")),
			subtitle,
			Callable(self, "_on_selector_result_pressed").bind(result),
			calc_name.to_lower() == _get_catalog_input_text(active_selector).to_lower()
		))


func _add_selector_suggestions_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 20)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(header)
	var title := _make_label(_t("battle.calc.suggestions_for", {
		"field": _get_selector_field_label(active_selector),
	}).to_upper(), 8, Color(0.62, 0.78, 0.90, 1.0))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)


func _get_selector_field_label(kind: String) -> String:
	match kind:
		SELECTOR_ITEM:
			return _t("battle.calc.item")
		SELECTOR_ABILITY:
			return _t("battle.calc.ability")
		SELECTOR_NATURE:
			return _t("battle.calc.nature")
		SELECTOR_MOVE:
			return _t("battle.calc.move_header")
		_:
			return _t("battle.calc.sample_set")


func _get_selector_default_label(kind: String) -> String:
	match kind:
		SELECTOR_ITEM:
			return _t("battle.calc.item_none")
		SELECTOR_ABILITY:
			return _t("battle.calc.automatic_value")
		SELECTOR_NATURE:
			return _localized_nature_name("Hardy")
		_:
			return _t("common.none")


func _refresh_nature_catalog_results() -> void:
	if catalog_results_box == null:
		return
	if selector_loading and selector_results.is_empty() and nature_catalog_options.is_empty():
		_add_selector_status(catalog_results_box, _t("battle.calc.loading_natures"), TEXT_SECONDARY)
		return
	if selector_error != "" and nature_catalog_options.is_empty():
		_add_selector_status(catalog_results_box, selector_error, TEXT_MUTED)

	var query := selector_query.strip_edges().to_lower()
	var matches: Array[String] = []
	for nature: String in _get_nature_option_names():
		var localized_name := _localized_nature_name(nature)
		if query == "" or nature.to_lower().contains(query) or localized_name.to_lower().contains(query):
			matches.append(nature)
	if matches.is_empty():
		_add_selector_status(catalog_results_box, _t("battle.calc.no_results_short"), TEXT_SECONDARY)
		return
	var selected_nature := _fallback_text(str(defender_assumptions.get("nature", "")).strip_edges(), "Hardy")
	for index in range(mini(matches.size(), 6)):
		var nature := matches[index]
		catalog_results_box.add_child(_make_selector_result_button(
			_localized_nature_name(nature),
			_t("battle.calc.neutral_nature") if nature == "Hardy" else "",
			_on_nature_option_pressed.bind(nature),
			nature == selected_nature
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
	if kind == SELECTOR_NATURE:
		return nature_assumption_input
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


func _get_ev_full_display_name(stat_key: String) -> String:
	return _t("battle.calc.ev_stat.%s" % stat_key)


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
		_make_dropdown_button_style(Color(SURFACE_PANEL, 0.76), Color(BORDER_NEUTRAL, 0.60))
	)

	var popup := selector.get_popup()
	if popup == null:
		return
	_apply_calcdex_popup_style(popup, font_size)


func _apply_calcdex_popup_style(popup: PopupMenu, font_size: int = 12) -> void:
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


func _get_hp_percent_label(pokemon: Dictionary) -> String:
	var percent: Variant = _get_defender_hp_percent(pokemon)
	if percent == null:
		return _t("battle.calc.hp_unknown")
	return _t("battle.calc.hp_percent", {"percent": _format_percent_value(percent)})


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


func _get_top_damage_percent(results: Array) -> float:
	var highest := -1.0
	for result_value: Variant in results:
		var result := _as_dictionary(result_value)
		if result.is_empty() or str(result.get("resultState", "supported")) != "supported" \
				or _is_status_result(result) or _has_suspicious_percent_values(result):
			continue
		var maximum: Variant = _get_percent_number(result.get("maxPercent"))
		if maximum != null and float(maximum) > highest:
			highest = float(maximum)
	return highest if highest > 0.0 else -1.0


func _is_top_damage_result(result: Dictionary, top_damage_percent: float) -> bool:
	if top_damage_percent < 0.0 or str(result.get("resultState", "supported")) != "supported" \
			or _is_status_result(result) or _has_suspicious_percent_values(result):
		return false
	var maximum: Variant = _get_percent_number(result.get("maxPercent"))
	return maximum != null and is_equal_approx(float(maximum), top_damage_percent)


func _get_percent_label(result: Dictionary) -> String:
	var min_percent_value: Variant = _get_percent_number(result.get("minPercent"))
	var max_percent_value: Variant = _get_percent_number(result.get("maxPercent"))
	if min_percent_value != null and max_percent_value != null \
			and is_zero_approx(float(min_percent_value)) and is_zero_approx(float(max_percent_value)):
		return "0.0%"

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
	if min_percent_value != null and max_percent_value != null \
			and is_zero_approx(float(min_percent_value)) and is_zero_approx(float(max_percent_value)):
		return _t("battle.calc.no_effect")
	var ko_projection := _as_dictionary(result.get("koProjection", {}))
	if str(ko_projection.get("state", "")) == "available":
		var projected_hits: Variant = ko_projection.get("hits")
		if typeof(projected_hits) == TYPE_INT and int(projected_hits) >= 1:
			if int(projected_hits) == 1:
				var projected_chance: Variant = ko_projection.get("chance")
				if typeof(projected_chance) in [TYPE_INT, TYPE_FLOAT] and float(projected_chance) < 0.999999:
					return _t("battle.calc.possible_ohko")
				return "OHKO"
			return "%dHKO" % int(projected_hits)
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
