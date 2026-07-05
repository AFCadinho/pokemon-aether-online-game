extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_pre_event_render_skips_final_team_hud_refresh()
	_check_non_pvp_switch_events_are_not_deduped_by_species()
	_check_initial_setup_switch_events_are_filtered_once()
	_check_initial_event_seq_cursor_tracks_start_event_boundary()
	_check_initial_setup_keeps_specific_form_species()
	quit(1 if failed else 0)


func _check_pre_event_render_skips_final_team_hud_refresh() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _update_battle_presentation_before_event_render(events: Array) -> void:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "pre-event presentation function exists")
	_check_equal(function_source.contains("_update_hud_panels("), false, "pre-event presentation does not push final active HUD HP")
	_check_equal(function_source.contains("_update_hud_panels()"), false, "pre-event presentation does not push final team HUD")
	_check_equal(function_source.contains("_update_party_slots()"), false, "pre-event presentation does not push final party slots")


func _check_non_pvp_switch_events_are_not_deduped_by_species() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _should_dedupe_rendered_non_pvp_event(event_data: Dictionary) -> bool:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "non-PvP dedupe function exists")
	_check_equal(function_source.contains("event_type == \"turn\""), true, "turn events are still deduped")
	_check_equal(function_source.contains("event_type == \"switch\""), false, "repeat switch events are not deduped by species")
	_check_equal(function_source.contains("event_type == \"drag\""), false, "repeat drag events are not deduped by species")


func _check_initial_setup_switch_events_are_filtered_once() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var remember_index := source.find("func _remember_initial_non_pvp_setup_events() -> void:")
	var remember_next_index := source.find("\nfunc ", remember_index + 1)
	var remember_source := source.substr(remember_index, remember_next_index - remember_index)
	var filter_index := source.find("func _filter_already_rendered_events(events_value: Variant, rendered_event_keys: Dictionary, response: Dictionary = {}) -> Array:")
	var filter_next_index := source.find("\nfunc ", filter_index + 1)
	var filter_source := source.substr(filter_index, filter_next_index - filter_index)
	var key_index := source.find("func _get_battle_event_key(event_data: Dictionary) -> String:")
	var key_next_index := source.find("\nfunc ", key_index + 1)
	var key_source := source.substr(key_index, key_next_index - key_index)

	_check_equal(remember_index >= 0, true, "initial non-PvP setup remember function exists")
	_check_equal(
		remember_source.contains("rendered_non_pvp_event_keys[event_key] = true"),
		true,
		"initial setup marks lead switch events as presented"
	)
	_check_equal(filter_index >= 0, true, "rendered event filter exists")
	_check_equal(
		filter_source.contains("rendered_non_pvp_event_keys.has(event_key)"),
		true,
		"rendered event filter skips setup events that were already presented"
	)
	_check_equal(key_index >= 0, true, "battle event key function exists")
	_check_equal(
		key_source.contains("_get_switch_event_source_species(event_data)"),
		true,
		"switch dedupe key includes source species so later real switches are distinct"
	)
	_check_equal(
		key_source.contains("_normalize_species_base_for_compare(_get_switch_event_dedupe_species(event_data))"),
		true,
		"switch dedupe key treats setup form aliases like Landorus and Landorus-Therian as the same lead"
	)


func _check_initial_event_seq_cursor_tracks_start_event_boundary() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_index := source.find("func _render_initial_battle_events(api_response: Dictionary) -> void:")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)
	var mark_index := source.find("func _mark_initial_non_pvp_response_events_consumed(response: Dictionary) -> void:")
	var mark_next_index := source.find("\nfunc ", mark_index + 1)
	var mark_source := source.substr(mark_index, mark_next_index - mark_index)
	var start_index := source.find("func _get_wild_battle_start_events(events: Array) -> Array:")
	var start_next_index := source.find("\nfunc ", start_index + 1)
	var start_source := source.substr(start_index, start_next_index - start_index)

	_check_equal(render_index >= 0, true, "initial event render function exists")
	_check_equal(
		render_source.contains("_mark_initial_non_pvp_response_events_consumed(api_response)"),
		true,
		"initial render marks only startup events consumed"
	)
	_check_equal(mark_index >= 0, true, "initial event seq marker exists")
	_check_equal(
		mark_source.contains("_get_battle_start_event_end_index(events)"),
		true,
		"initial event seq marker uses startup event boundary"
	)
	_check_equal(
		mark_source.contains("first_event_seq + last_start_event_index"),
		true,
		"initial event seq cursor advances to last startup event"
	)
	_check_equal(start_index >= 0, true, "battle start event filter exists")
	_check_equal(
		start_source.contains("\"turn\", \"switch\", \"drag\":"),
		true,
		"battle start filter skips setup switch-like events before abilities"
	)
	_check_equal(
		start_source.contains("break"),
		true,
		"battle start filter stops before first non-start action event"
	)


func _check_initial_setup_keeps_specific_form_species() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var original_species_index := source.find("func _get_original_active_player_species(fallback_species: String = \"\") -> String:")
	var original_species_next_index := source.find("\nfunc ", original_species_index + 1)
	var original_species_source := source.substr(original_species_index, original_species_next_index - original_species_index)
	var form_check_index := source.find("func _is_specific_battle_form_species(species: String) -> bool:")
	var form_check_next_index := source.find("\nfunc ", form_check_index + 1)
	var form_check_source := source.substr(form_check_index, form_check_next_index - form_check_index)

	_check_equal(original_species_index >= 0, true, "original active player species helper exists")
	_check_equal(
		original_species_source.contains("_is_specific_battle_form_species(fallback_species)"),
		true,
		"initial setup keeps explicit form species before falling back to Showdown ident"
	)
	_check_equal(
		original_species_source.find("_is_specific_battle_form_species(fallback_species)") < original_species_source.find("ident.contains(\": \")"),
		true,
		"initial setup checks explicit form species before ident species"
	)
	_check_equal(form_check_index >= 0, true, "specific battle form helper exists")
	_check_equal(
		form_check_source.contains("replace(\" \", \"-\")"),
		true,
		"specific battle form helper treats spaced form names as form species"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
