extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_pre_event_render_skips_final_team_hud_refresh()
	_check_non_pvp_switch_events_are_not_deduped_by_species()
	_check_initial_setup_switch_events_are_filtered_once()
	_check_initial_event_seq_cursor_tracks_start_event_boundary()
	_check_initial_start_events_include_booster_energy_item_events()
	_check_initial_setup_keeps_specific_form_species()
	_check_team_preview_lead_selection_unlocks_party_grid()
	_check_pvp_render_restores_canonical_party_state()
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


func _check_initial_start_events_include_booster_energy_item_events() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var start_index := source.find("func _get_wild_battle_start_events(events: Array) -> Array:")
	var start_next_index := source.find("\nfunc ", start_index + 1)
	var start_source := source.substr(start_index, start_next_index - start_index)
	var boundary_index := source.find("func _get_battle_start_event_end_index(events: Array) -> int:")
	var boundary_next_index := source.find("\nfunc ", boundary_index + 1)
	var boundary_source := source.substr(boundary_index, boundary_next_index - boundary_index)

	_check_equal(start_index >= 0, true, "battle start event filter exists")
	_check_equal(
		start_source.contains("\"fieldEffect\", \"pokemonEffect\", \"ability\", \"statChange\", \"item\", \"transform\", \"mega\", \"primal\":"),
		true,
		"battle start filter includes item events before ability boosts"
	)
	_check_equal(boundary_index >= 0, true, "battle start boundary helper exists")
	_check_equal(
		boundary_source.contains("\"turn\", \"switch\", \"drag\", \"fieldEffect\", \"pokemonEffect\", \"ability\", \"statChange\", \"item\", \"transform\", \"mega\", \"primal\":"),
		true,
		"battle start boundary consumes item events before ability boosts"
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


func _check_team_preview_lead_selection_unlocks_party_grid() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var trainer_index := source.find("func _run_trainer_team_preview_lead_selection() -> Dictionary:")
	var trainer_next_index := source.find("\nfunc ", trainer_index + 1)
	var trainer_source := source.substr(trainer_index, trainer_next_index - trainer_index)
	var pvp_index := source.find("func _run_pvp_team_preview_lead_selection(local_player_id: String) -> Dictionary:")
	var pvp_next_index := source.find("\nfunc ", pvp_index + 1)
	var pvp_source := source.substr(pvp_index, pvp_next_index - pvp_index)

	_check_equal(trainer_index >= 0, true, "trainer team preview lead selection exists")
	_check_equal(pvp_index >= 0, true, "PvP team preview lead selection exists")
	_check_equal(
		trainer_source.find("_set_battle_input_locked(false)") >= 0
			and trainer_source.find("_set_battle_input_locked(false)") < trainer_source.find("party_grid.set_party("),
		true,
		"trainer team preview unlocks input before waiting for party lead selection"
	)
	_check_equal(
		trainer_source.contains("party_grid.set_party(_get_trainer_lead_selection_party_data())"),
		true,
		"trainer team preview lead selection uses saved party data for clickable slots"
	)
	_check_equal(
		trainer_source.contains("_can_choose_trainer_lead_slot(selected_slot)"),
		true,
		"trainer team preview validates selected lead against saved party"
	)
	_check_equal(
		source.contains("if not pokemon.has_saved_hp_state and current_hp <= 0:"),
		true,
		"trainer lead selection treats missing saved HP as full HP"
	)
	_check_equal(
		source.contains("if pokemon.has_saved_hp_state and pokemon.current_hp <= 0:"),
		true,
		"trainer lead validation only rejects saved fainted Pokemon"
	)
	_check_equal(
		pvp_source.find("_set_battle_input_locked(false)") >= 0
			and pvp_source.find("_set_battle_input_locked(false)") < pvp_source.find("party_grid.set_party("),
		true,
		"PvP team preview unlocks input before waiting for party lead selection"
	)


func _check_pvp_render_restores_canonical_party_state() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_index := source.find("func _render_pvp_opponent_response(")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)
	var restore_index := source.find("func _restore_pvp_authoritative_presentation(response: Dictionary) -> void:")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)
	var temporary_index := source.find("func _set_temporary_switch_in_condition(")
	var temporary_next_index := source.find("\nfunc ", temporary_index + 1)
	var temporary_source := source.substr(temporary_index, temporary_next_index - temporary_index)

	_check_equal(render_index >= 0, true, "PvP opponent render function exists")
	_check_equal(
		render_source.find("await _render_pvp_event_batch") < render_source.find("_restore_pvp_authoritative_presentation(opponent_response)"),
		true,
		"PvP render restores the canonical response after presentation rewinds"
	)
	_check_equal(restore_index >= 0, true, "canonical PvP presentation restore exists")
	_check_equal(restore_source.contains("pvp_response_order.latest_projection_for(response)"), true, "restore selects the newest canonical PvP projection")
	_check_equal(restore_source.contains("battle_state.load_from_api_response(canonical_response, true)"), true, "canonical response replaces temporary BattleState changes")
	_check_equal(restore_source.contains("_update_party_slots()"), true, "party rails refresh after canonical restore")
	_check_equal(temporary_source.contains("target_is_fainted and not event_proves_alive"), true, "ambiguous switch presentation cannot revive a fainted target")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
