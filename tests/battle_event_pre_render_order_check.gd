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
	_check_initial_shiny_lead_uses_entrance_identity()
	_check_stat_stage_events_normalize_drops()
	_check_pvp_render_restores_canonical_party_state()
	_check_local_force_switch_render_restores_canonical_party_state()
	_check_pvp_state_and_field_wait_for_render_cursor()
	_check_pvp_restore_keeps_rendered_hp_and_field_events()
	_check_authoritative_render_batch_survives_transport_reordering()
	_check_ended_snapshot_waits_for_final_render()
	_check_authoritative_terminal_waits_for_render()
	_check_local_forfeit_terminal_unblocks_action_wait()
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
	var setup_index := source.find("func setup_pvp_battle_from_response(")
	var setup_next_index := source.find("\nfunc ", setup_index + 1)
	var setup_source := source.substr(setup_index, setup_next_index - setup_index)
	var hide_index := source.find("func _hide_team_preview_layers() -> void:")
	var hide_next_index := source.find("\nfunc ", hide_index + 1)
	var hide_source := source.substr(hide_index, hide_next_index - hide_index)
	var transition_index := source.find("func _prepare_team_preview_lead_summon_transition() -> void:")
	var transition_next_index := source.find("\nfunc ", transition_index + 1)
	var transition_source := source.substr(transition_index, transition_next_index - transition_index)
	var show_index := source.find("func _show_team_preview_layers() -> void:")
	var show_next_index := source.find("\nfunc ", show_index + 1)
	var show_source := source.substr(show_index, show_next_index - show_index)
	var queue_process_index := source.find("func _should_process_pvp_choice_queue_entry(")
	var queue_process_next_index := source.find("\nfunc ", queue_process_index + 1)
	var queue_process_source := source.substr(queue_process_index, queue_process_next_index - queue_process_index)
	var preview_layer_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/team_preview_layer.gd")

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
	_check_equal(
		setup_source.find("await _prepare_team_preview_lead_summon_transition()") >= 0
			and setup_source.find("await _prepare_team_preview_lead_summon_transition()") < setup_source.find("await _play_lead_summon("),
		true,
		"PvP lead intro completes the Team Preview render barrier before Pokeball summons"
	)
	_check_equal(
		setup_source.find("await _prepare_team_preview_lead_summon_transition()") < setup_source.find("_show_original_player_lead_before_initial_events"),
		true,
		"PvP lead waits for the Team Preview render barrier before populating its sprite"
	)
	_check_equal(
		hide_source.contains("player_sprite_box.visible = true") or hide_source.contains("enemy_sprite_box.visible = true"),
		false,
		"Team Preview exit cannot reveal active sprites before Pokeball release"
	)
	_check_equal(preview_layer_source.contains("func clear() -> void:\n\t# Hide the owner"), true, "Team Preview layer hides its root when cleared")
	_check_equal(preview_layer_source.contains("sprite.sprite_frames = null"), true, "cleared Team Preview sprites cannot survive in a cached viewport frame")
	_check_equal(transition_source.contains("await RenderingServer.frame_post_draw"), true, "lead summon waits until a preview-free frame was actually drawn")
	_check_equal(transition_source.count("_clear_team_preview_visuals()") == 2, true, "lead transition clears delayed preview redraws on both sides of the render barrier")
	_check_equal(show_source.contains("if not team_preview_lead_selection_active:"), true, "late Team Preview redraws are ignored after lead selection")
	_check_equal(queue_process_source.contains("if team_preview_lead_selection_active and source in ["), true, "lead completion cannot render while Team Preview is active")
	for lead_source in ["pvp_choose_lead", "pvp_team_preview_complete", "pvp_team_preview_recovery", "pvp_room_polling_team_preview"]:
		_check_equal(queue_process_source.contains('"%s"' % lead_source), true, "%s waits for the post-preview intro" % lead_source)


func _check_stat_stage_events_normalize_drops() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := source.find("func _apply_stat_stage_event(event: Dictionary) -> void:")
	var apply_next_index := source.find("\nfunc ", apply_index + 1)
	var apply_source := source.substr(apply_index, apply_next_index - apply_index)
	var normalize_index := source.find("func _normalize_stat_stage_key(stat: String) -> String:")
	var normalize_next_index := source.find("\nfunc ", normalize_index + 1)
	var normalize_source := source.substr(normalize_index, normalize_next_index - normalize_index)

	_check_equal(apply_source.contains("event_text_formatter.get_stat_change_amount(event)"), true, "persistent stat badges use normalized signed stage changes")
	_check_equal(normalize_source.contains('"acc", "accuracy":'), true, "accuracy stages have a persistent badge key")
	_check_equal(normalize_source.contains('"eva", "evasion":'), true, "evasion stages have a persistent badge key")


func _check_initial_shiny_lead_uses_entrance_identity() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var lead_index := source.find("func _show_original_player_lead_before_initial_events(")
	var lead_next_index := source.find("\nfunc ", lead_index + 1)
	var lead_source := source.substr(lead_index, lead_next_index - lead_index)

	_check_equal(lead_index >= 0, true, "initial player lead setup exists")
	_check_equal(
		lead_source.contains('var is_shiny := _get_active_pokemon_is_shiny_for_entrance("p1")'),
		true,
		"initial lead sprite and shiny entrance resolve the same shiny identity"
	)
	_check_equal(
		lead_source.contains("_get_saved_pokemon_shiny_for_active_data(active_pokemon)"),
		false,
		"initial lead does not depend on Team Preview retaining instanceId"
	)


func _check_pvp_render_restores_canonical_party_state() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_index := source.find("func _render_pvp_opponent_response(")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)
	var restore_index := source.find("func _restore_pvp_authoritative_presentation(response: Dictionary, rendered_events: Array = []) -> void:")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)
	var temporary_index := source.find("func _set_temporary_switch_in_condition(")
	var temporary_next_index := source.find("\nfunc ", temporary_index + 1)
	var temporary_source := source.substr(temporary_index, temporary_next_index - temporary_index)

	_check_equal(render_index >= 0, true, "PvP opponent render function exists")
	_check_equal(
		render_source.find("await _render_pvp_event_batch") < render_source.find("_restore_pvp_authoritative_presentation(batch_response, opponent_events)"),
		true,
		"PvP render restores the canonical response after presentation rewinds"
	)
	_check_equal(restore_index >= 0, true, "canonical PvP presentation restore exists")
	_check_equal(restore_source.contains("pvp_response_order.canonical_snapshot_for_render_cursor("), true, "restore cannot select a canonical PvP projection ahead of the rendered cursor")
	_check_equal(restore_source.contains("battle_state.load_from_api_response(canonical_response, false)"), true, "canonical snapshot replaces temporary BattleState changes without replaying history")
	_check_equal(restore_source.contains("_sync_player_save_party_status_from_battle_state()"), true, "canonical restore synchronizes local party HP and faint state")
	_check_equal(restore_source.contains("_sync_presentation_field_from_battle_state()"), true, "canonical restore synchronizes weather and field state")
	_check_equal(restore_source.contains("_update_battle_status_panels()"), true, "canonical restore refreshes weather visuals and field timers")
	_check_equal(restore_source.contains("_update_party_slots()"), true, "party rails refresh after canonical restore")
	_check_equal(temporary_source.contains("target_is_fainted and not event_proves_alive"), true, "ambiguous switch presentation cannot revive a fainted target")


func _check_local_force_switch_render_restores_canonical_party_state() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var process_index := source.find("func _process_pvp_choice_queue_entry(")
	var process_next_index := source.find("\nfunc ", process_index + 1)
	var process_source := source.substr(process_index, process_next_index - process_index)
	var force_switch_index := process_source.find("if is_local_choice and was_force_switch:")
	var regular_switch_index := process_source.find("\n\t\tif not skip_render", force_switch_index + 1)
	var force_switch_source := process_source.substr(
		force_switch_index,
		regular_switch_index - force_switch_index
	)

	_check_equal(process_index >= 0, true, "PvP choice queue processor exists")
	_check_equal(force_switch_index >= 0, true, "local forced-switch render path exists")
	_check_equal(
		force_switch_source.find("await _render_pvp_event_batch")
			< force_switch_source.find("_restore_pvp_authoritative_presentation(batch_display_response, player_events)"),
		true,
		"local forced-switch render restores canonical faint and HP state after historical rewinds"
	)


func _check_pvp_state_and_field_wait_for_render_cursor() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := source.find("func _apply_api_response(")
	var apply_next_index := source.find("\nfunc ", apply_index + 1)
	var apply_source := source.substr(apply_index, apply_next_index - apply_index)
	var barrier_index := source.find("func _should_defer_pvp_canonical_state_until_render(")
	var barrier_next_index := source.find("\nfunc ", barrier_index + 1)
	var barrier_source := source.substr(barrier_index, barrier_next_index - barrier_index)
	var render_index := source.find("func _render_battle_events(")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)

	_check_equal(apply_source.contains("_should_defer_pvp_canonical_state_until_render(display_response)"), true, "PvP state mutation is deferred while its events are unrendered")
	_check_equal(apply_source.contains("action_flow.apply_response(response, apply_event_conditions, not defer_state_load)"), true, "action flow can retain the current presentation state until render")
	_check_equal(barrier_source.contains("pvp_event_queue.last_rendered_seq < 0"), true, "Team Preview can establish its lead state before the first render cursor")
	_check_equal(render_source.contains("if not _is_pvp_battle():\n\t\t_sync_presentation_field_from_battle_state()"), true, "PvP field effects are not overwritten before the render cursor advances")


func _check_pvp_restore_keeps_rendered_hp_and_field_events() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var restore_index := source.find("func _restore_pvp_authoritative_presentation(response: Dictionary, rendered_events: Array = []) -> void:")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)
	var condition_index := source.find("func _reapply_rendered_condition_events(events: Array) -> void:")
	var condition_next_index := source.find("\nfunc ", condition_index + 1)
	var condition_source := source.substr(condition_index, condition_next_index - condition_index)
	var field_index := source.find("func _reapply_rendered_field_effect_events(events: Array) -> void:")
	var field_next_index := source.find("\nfunc ", field_index + 1)
	var field_source := source.substr(field_index, field_next_index - field_index)
	var sync_index := source.find("func _sync_presentation_field_from_battle_state() -> void:")
	var sync_next_index := source.find("\nfunc ", sync_index + 1)
	var sync_source := source.substr(sync_index, sync_next_index - sync_index)

	_check_equal(restore_source.contains("_reapply_rendered_condition_events(rendered_events)"), true, "canonical restore retains rendered hazard HP")
	_check_equal(restore_source.contains("_reapply_rendered_field_effect_events(rendered_events)"), true, "canonical restore retains rendered weather changes")
	_check_equal(condition_source.contains('"damage", "heal", "faint", "status":'), true, "restore replays only condition-changing events")
	_check_equal(condition_source.contains('"switch"'), false, "restore never replays switch events over Pursuit canonical state")
	_check_equal(field_source.contains('!= "fieldEffect"'), true, "field replay accepts only ordered field events")
	_check_equal(sync_source.contains('if not battle_state.field.has("effects"):'), true, "omitted realtime field snapshot cannot erase active weather")


func _check_authoritative_render_batch_survives_transport_reordering() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var stale_index := source.find("func _is_stale_pvp_realtime_message(message: Dictionary) -> bool:")
	var stale_next_index := source.find("\nfunc ", stale_index + 1)
	var stale_source := source.substr(stale_index, stale_next_index - stale_index)
	var process_index := source.find("func _should_process_pvp_choice_queue_entry(")
	var process_next_index := source.find("\nfunc ", process_index + 1)
	var process_source := source.substr(process_index, process_next_index - process_index)

	_check_equal(stale_source.contains("_is_unrendered_authoritative_pvp_render_batch_response(render_response)"), true, "required render batches bypass transport-sequence stale rejection")
	_check_equal(process_source.contains("_is_authoritative_pvp_render_batch_response(response)"), true, "idle authoritative batches enter the animation processor")


func _check_ended_snapshot_waits_for_final_render() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var snapshot_index := source.find("func _apply_pvp_realtime_snapshot_when_safe(")
	var snapshot_next_index := source.find("\nfunc ", snapshot_index + 1)
	var snapshot_source := source.substr(snapshot_index, snapshot_next_index - snapshot_index)

	_check_equal(snapshot_source.contains("_is_pvp_snapshot_recovery_bypass"), false, "ended snapshots cannot bypass the final render cursor")
	_check_equal(snapshot_source.contains("snapshot_event_seq > last_rendered_seq"), true, "ended snapshots buffer while final events are still ahead")


func _check_authoritative_terminal_waits_for_render() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var finish_index := source.find("func _finish_pvp_authoritative_terminal(message: Dictionary) -> void:")
	var finish_next_index := source.find("\nfunc ", finish_index + 1)
	var finish_source := source.substr(finish_index, finish_next_index - finish_index)
	var callback_index := source.find("func _on_pvp_render_batch_completed(completion: Dictionary) -> void:")
	var callback_next_index := source.find("\nfunc ", callback_index + 1)
	var callback_source := source.substr(callback_index, callback_next_index - callback_index)

	_check_equal(finish_index >= 0, true, "authoritative terminal handler exists")
	_check_equal(finish_source.contains("should_defer_authoritative_terminal_until_render"), true, "normal terminal waits while canonical render work is unfinished")
	_check_equal(finish_source.contains('var is_forfeit_terminal := end_reason == "forfeit"'), true, "durable manual forfeit is recognized as animation-free terminal work")
	_check_equal(finish_source.contains("if not is_forfeit_terminal and PvpBattleRealtimeService.should_defer_authoritative_terminal_until_render("), true, "manual forfeit does not wait forever for a separate ended projection")
	_check_equal(finish_source.contains("pvp_pending_authoritative_terminal = message.duplicate(true)"), true, "early terminal is retained for post-render completion")
	_check_equal(callback_source.contains("_retry_pending_pvp_authoritative_terminal.call_deferred()"), true, "render completion retries the retained terminal")


func _check_local_forfeit_terminal_unblocks_action_wait() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var confirm_index := source.find("func _on_forfeit_confirmed() -> void:")
	var confirm_next_index := source.find("\nfunc ", confirm_index + 1)
	var confirm_source := source.substr(confirm_index, confirm_next_index - confirm_index)
	var wait_index := source.find("func _send_pvp_realtime_action_and_wait(")
	var wait_next_index := source.find("\nfunc ", wait_index + 1)
	var wait_source := source.substr(wait_index, wait_next_index - wait_index)

	_check_equal(confirm_source.find("if battle_finished:") < confirm_source.find("_set_battle_input_locked(false)", confirm_source.find("var response: Dictionary = await _submit_pvp_realtime_forfeit()")), true, "finished forfeit cannot unlock or overwrite its result UI")
	_check_equal(confirm_source.contains("_finish_confirmed_pvp_forfeit(response, _get_local_state_player_id(), \"pvp_forfeit_submit\")"), true, "confirmed local forfeit bypasses the normal animation queue")
	_check_equal(wait_source.contains('if action == "forfeit" and battle_finished:'), true, "forfeit action waiter exits when durable terminal wins the race")
	_check_equal(wait_source.contains('"terminalConfirmed": true'), true, "forfeit waiter returns a successful terminal confirmation")
	_check_equal(wait_source.contains('await _reconcile_pvp_battle_from_room("pvp_forfeit_timeout_recovery")'), true, "lost local forfeit response is confirmed from the canonical room")
	_check_equal(wait_source.contains("reconciled_forfeit and battle_state.is_battle_ended()"), true, "forfeit timeout recovery only succeeds for a terminal mechanical state")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
