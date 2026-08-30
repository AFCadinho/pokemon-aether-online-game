extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_ANIMATION_ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const DisguiseEventOrderScript := preload("res://scripts/battle/battle_disguise_event_order.gd")

var failed := false


func _init() -> void:
	_check_pre_event_render_skips_final_team_hud_refresh()
	_check_damage_continuity_is_normalized_before_hud_rewind()
	_check_non_pvp_switch_events_are_not_deduped_by_species()
	_check_initial_setup_switch_events_are_filtered_once()
	_check_initial_event_seq_cursor_tracks_start_event_boundary()
	_check_initial_start_events_include_booster_energy_item_events()
	_check_initial_setup_keeps_specific_form_species()
	_check_wild_player_lead_is_ready_on_entry()
	_check_wild_player_lead_uses_authoritative_active_slot()
	_check_team_preview_lead_selection_unlocks_party_grid()
	_check_initial_shiny_lead_uses_entrance_identity()
	_check_stat_stage_events_normalize_drops()
	_check_pvp_render_restores_canonical_party_state()
	_check_pvp_sprite_restore_stays_inside_render_batch()
	_check_local_force_switch_render_restores_canonical_party_state()
	_check_api_response_uses_rendered_event_cursor()
	_check_chained_force_switch_request_survives_entry_hazard_faint()
	_check_pivot_ko_wait_state_blocks_fainted_fallback()
	_check_pvp_state_and_field_wait_for_render_cursor()
	_check_pvp_restore_keeps_rendered_hp_and_field_events()
	_check_authoritative_render_batch_survives_transport_reordering()
	_check_stale_local_response_cannot_restart_consumed_waiter()
	_check_event_ahead_snapshot_bypasses_only_transport_supersession()
	_check_ended_snapshot_waits_for_final_render()
	_check_authoritative_terminal_waits_for_render()
	_check_local_forfeit_terminal_unblocks_action_wait()
	_check_force_switch_phase_release_recovers()
	_check_animation_wait_has_render_barrier_watchdog()
	_check_instant_prepare_events_render_as_one_action()
	_check_disguise_form_change_follows_recoil_damage()
	_check_resolved_response_holds_species_until_ordered_form_event()
	_check_animated_forme_change_is_prepared_before_render()
	quit(1 if failed else 0)


func _check_disguise_form_change_follows_recoil_damage() -> void:
	var events := [
		{"type": "move", "actor": "p1a: Mimikyu", "move": "Swords Dance", "target": "p1a: Mimikyu"},
		{"type": "statChange", "target": "p1a: Mimikyu", "stat": "atk", "amount": 2},
		{"type": "move", "actor": "p2a: Hitmonchan", "move": "Bullet Punch", "target": "p1a: Mimikyu"},
		{"type": "ability", "target": "p1a: Mimikyu", "ability": "Disguise"},
		{
			"type": "formeChange",
			"target": "p1a: Mimikyu-Busted",
			"species": "Mimikyu-Busted",
			"source": "ability: Disguise",
		},
		{
			"type": "damage",
			"target": "p1a: Mimikyu",
			"previousHp": 251,
			"hp": 220,
			"maxHp": 251,
			"amount": 31,
			"source": "pokemon: Mimikyu-Busted",
		},
		{"type": "turn", "turn": 2},
	]

	var ordered: Array = DisguiseEventOrderScript.move_busted_form_changes_after_recoil(events)
	_check_equal(str((ordered[0] as Dictionary).get("move", "")), "Swords Dance", "Mimikyu's earlier move stays ahead of Hitmonchan and Disguise")
	_check_equal(str((ordered[4] as Dictionary).get("type", "")), "damage", "Disguise recoil renders before Mimikyu becomes Busted")
	_check_equal(str((ordered[5] as Dictionary).get("type", "")), "formeChange", "Busted form and Inactive badge render after recoil damage")

	var no_recoil_events := [events[0], events[1], events[2], events[3], events[4], events[6]]
	var no_recoil_ordered: Array = DisguiseEventOrderScript.move_busted_form_changes_after_recoil(no_recoil_events)
	_check_equal(str((no_recoil_ordered[4] as Dictionary).get("type", "")), "formeChange", "Disguise form timing is unchanged when the generation has no recoil event")

	var unrelated_form_events := [
		{"type": "formeChange", "target": "p1a: Aegislash", "species": "Aegislash-Blade"},
		{"type": "damage", "target": "p1a: Aegislash", "source": "pokemon: Mimikyu-Busted"},
	]
	var unrelated_ordered: Array = DisguiseEventOrderScript.move_busted_form_changes_after_recoil(unrelated_form_events)
	_check_equal(str((unrelated_ordered[0] as Dictionary).get("type", "")), "formeChange", "non-Disguise form changes keep their server order")


func _check_resolved_response_holds_species_until_ordered_form_event() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var submit_index := source.find("func _submit_player_choice_and_resolve")
	var capture_index := source.find("_capture_ordered_response_display_species()", submit_index)
	var request_index := source.find("await action_flow.submit_player_choice_and_resolve", submit_index)
	_check_equal(capture_index >= 0 and capture_index < request_index, true, "wild resolution captures visible species before the final response arrives")
	_check_equal(source.contains("ordered_response_display_species_hold.get(player_id"), true, "pre-event sprite and Disguise badge use the held visible species")
	_check_equal(source.contains("BattleState.get_mimikyu_disguise_state_for_species(canonical_species) == \"\""), true, "the response display hold is scoped to canonical Mimikyu and cannot delay unrelated forms")
	_check_equal(
		source.contains("var apply_forme_change_after_render := event_type == \"formeChange\""),
		true,
		"formeChange releases the display hold only at its ordered event"
	)


func _check_animated_forme_change_is_prepared_before_render() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_index := source.find("func _render_battle_events(")
	var next_function_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, next_function_index - render_index)
	var animated_form_index := render_source.find("var apply_forme_change_after_render :=")
	var render_event_index := render_source.find("await event_renderer.render_event(event_data, presentation, suppress_presentation_waits)")
	var deferred_form_index := render_source.find("if apply_forme_change_after_render:", render_event_index)
	_check_equal(
		animated_form_index >= 0 and animated_form_index < render_event_index,
		true,
		"animated form changes prepare their new visual form before the transformation effect"
	)
	_check_equal(
		deferred_form_index > render_event_index,
		true,
		"ordinary form changes keep their existing post-render update order"
	)


func _check_pre_event_render_skips_final_team_hud_refresh() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _update_battle_presentation_before_event_render(events: Array) -> void:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "pre-event presentation function exists")
	_check_equal(function_source.contains("_update_hud_panels("), false, "pre-event presentation does not push final active HUD HP")
	_check_equal(function_source.contains("_update_hud_panels()"), false, "pre-event presentation does not push final team HUD")
	_check_equal(function_source.contains("_update_party_slots()"), false, "pre-event presentation does not push final party slots")


func _check_damage_continuity_is_normalized_before_hud_rewind() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _rewind_active_hud_hp_for_events(events: Array) -> void:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)
	var normalize_index := function_source.find("normalize_damage_event_continuity")
	var hud_rewind_index := function_source.find("_set_active_hud_hp_from_event")

	_check_equal(function_index >= 0, true, "active HUD rewind function exists")
	_check_equal(normalize_index >= 0, true, "damage continuity is normalized in the pre-render rewind path")
	_check_equal(
		normalize_index < hud_rewind_index,
		true,
		"multi-hit continuity is repaired before stale previous HP can reach the HUD"
	)

func _check_non_pvp_switch_events_are_not_deduped_by_species() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _should_dedupe_rendered_non_pvp_event(event_data: Dictionary) -> bool:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "non-PvP dedupe function exists")
	_check_equal(function_source.contains("event_type == \"turn\""), true, "turn events are still deduped")
	_check_equal(function_source.contains("event_type == \"switch\""), false, "repeat switch events are not deduped by species")
	_check_equal(function_source.contains("event_type == \"drag\""), false, "repeat drag events are not deduped by species")


func _check_animation_wait_has_render_barrier_watchdog() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_ANIMATION_ROUTER_PATH)
	var function_index := source.find("func _wait_for_animation_node(")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "animation wait function exists")
	_check_equal(
		function_source.contains("elapsed_seconds >= MAX_ANIMATION_WAIT_SECONDS"),
		true,
		"stalled animations cannot hold a PvP render barrier indefinitely"
	)
	_check_equal(
		function_source.contains("await tree.process_frame"),
		true,
		"animation watchdog keeps presentation asynchronous while it waits"
	)


func _check_instant_prepare_events_render_as_one_action() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_index := source.find("func _render_battle_events(")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)
	var charge_index := source.find("func _move_event_starts_a_charge_turn(")
	var charge_next_index := source.find("\nfunc ", charge_index + 1)
	var charge_source := source.substr(charge_index, charge_next_index - charge_index)
	var resolution_index := source.find("func _prepare_event_resolves_in_same_batch(")
	var resolution_next_index := source.find("\nfunc ", resolution_index + 1)
	var resolution_source := source.substr(
		resolution_index,
		resolution_next_index - resolution_index
	)

	_check_equal(
		render_source.contains(
			'event_type == "prepare" and _prepare_event_resolves_in_same_batch(ordered_events, event_index)'
		),
		true,
		"instant Solar Beam prepare event is not rendered as a second action"
	)
	_check_equal(
		charge_source.contains(
			"matching_prepare and not _prepare_event_resolves_in_same_batch(events, next_index)"
		),
		true,
		"same-batch prepare plus damage does not suppress the immediate move"
	)
	_check_equal(
		resolution_source.contains('"damage"')
			and resolution_source.contains('next_type in ["move", "switch", "drag", "turn"]'),
		true,
		"prepare classification distinguishes an immediate result from a real charge-turn boundary"
	)


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
		original_species_source.find("_is_specific_battle_form_species(fallback_species)") < original_species_source.find("battle_state.get_active_pokemon_species(\"p1\")"),
		true,
		"initial setup checks explicit form species before canonical state species"
	)
	_check_equal(form_check_index >= 0, true, "specific battle form helper exists")
	_check_equal(
		form_check_source.contains("replace(\" \", \"-\")"),
		true,
		"specific battle form helper treats spaced form names as form species"
	)
	_check_equal(
		form_check_source.contains("\"-terastal\""),
		true,
		"PvP identity correction preserves Terapagos Terastal form"
	)

	var metadata_source := FileAccess.get_file_as_string("res://scripts/battle/battle_display_metadata.gd")
	_check_equal(
		metadata_source.contains("\"-terastal\""),
		true,
		"battle display metadata preserves Terapagos Terastal form"
	)


func _check_wild_player_lead_is_ready_on_entry() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var prepare_index := source.find("func prepare_wild_battle_from_response(")
	var prepare_next_index := source.find("\nfunc ", prepare_index + 1)
	var prepare_source := source.substr(prepare_index, prepare_next_index - prepare_index)

	_check_equal(prepare_index >= 0, true, "wild battle preparation exists")
	_check_equal(
		prepare_source.find("_show_original_player_lead_before_initial_events") < prepare_source.find("player_sprite_box.visible = true"),
		true,
		"wild lead sprite is prepared and visible before the covered battle scene is revealed"
	)


func _check_wild_player_lead_uses_authoritative_active_slot() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var prepare_index := source.find("func prepare_wild_battle_from_response(")
	var prepare_next_index := source.find("\nfunc ", prepare_index + 1)
	var prepare_source := source.substr(prepare_index, prepare_next_index - prepare_index)
	_check_equal(
		prepare_source.find("_apply_initial_battle_response(api_response)")
			< prepare_source.find('battle_state.get_active_player_pokemon("p1")'),
		true,
		"wild lead resolves from the authoritative response after it is applied"
	)
	_check_equal(
		prepare_source.contains("active_player_pokemon = response_player_pokemon"),
		true,
		"wild setup adopts the auto-selected usable party member"
	)
	_check_equal(
		prepare_source.contains("_show_original_player_lead_before_initial_events(player_species, player_lead_pokemon)"),
		true,
		"wild lead sprite is prepared from the auto-selected usable party member"
	)
	_check_equal(
		prepare_source.find("active_player_pokemon = response_player_pokemon")
			< prepare_source.find("_show_original_player_lead_before_initial_events(player_species, player_lead_pokemon)"),
		true,
		"wild entry stages the authoritative usable lead before the battle is revealed"
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
	var restore_index := source.find("func _restore_pvp_authoritative_presentation(")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)
	var temporary_index := source.find("func _set_temporary_switch_in_condition(")
	var temporary_next_index := source.find("\nfunc ", temporary_index + 1)
	var temporary_source := source.substr(temporary_index, temporary_next_index - temporary_index)

	_check_equal(render_index >= 0, true, "PvP opponent render function exists")
	_check_equal(render_source.contains("Callable(self, \"_restore_pvp_opponent_response_presentation\").bind(batch_response, opponent_events)"), true, "PvP render schedules canonical restore after presentation rewinds")
	_check_equal(restore_index >= 0, true, "canonical PvP presentation restore exists")
	_check_equal(restore_source.contains("pvp_response_order.canonical_snapshot_for_render_cursor("), true, "restore cannot select a canonical PvP projection ahead of the rendered cursor")
	_check_equal(restore_source.contains("battle_state.load_from_api_response(canonical_response, false)"), true, "canonical snapshot replaces temporary BattleState changes without replaying history")
	_check_equal(restore_source.contains("_sync_player_save_party_status_from_battle_state()"), true, "canonical restore synchronizes local party HP and faint state")
	_check_equal(restore_source.contains("_sync_presentation_field_from_battle_state()"), false, "batch restore cannot overwrite ordered weather and hazard presentation")
	_check_equal(restore_source.contains("_update_battle_status_panels()"), true, "canonical restore refreshes weather visuals and field timers")
	_check_equal(restore_source.contains("_update_party_slots()"), true, "party rails refresh after canonical restore")
	_check_equal(temporary_source.contains("target_is_fainted and not event_proves_alive"), true, "ambiguous switch presentation cannot revive a fainted target")


func _check_pvp_sprite_restore_stays_inside_render_batch() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var batch_index := source.find("func _render_pvp_event_batch(")
	var batch_next_index := source.find("\nfunc ", batch_index + 1)
	var batch_source := source.substr(batch_index, batch_next_index - batch_index)
	var render_index := source.find("func _render_pvp_opponent_response(")
	var render_next_index := source.find("\nfunc ", render_index + 1)
	var render_source := source.substr(render_index, render_next_index - render_index)
	var restore_index := source.find("func _restore_pvp_opponent_response_presentation(")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)

	_check_equal(batch_index >= 0, true, "PvP batch renderer exists")
	_check_equal(batch_source.contains("post_render.call(batch_context)"), true, "PvP batch invokes post-render reconciliation before completion")
	_check_equal(batch_source.contains("_set_battle_input_locked(true)"), true, "PvP render batches lock input before their first animation")
	_check_equal(batch_source.contains("mechanics_panel.visible = false"), true, "Mega and Z-Move controls remain hidden during PvP rendering")
	_check_equal(render_source.contains("_render_pvp_event_batch(render_response, opponent_events, true, source, post_render)"), true, "opponent response supplies its restore callback to the active batch")
	_check_equal(
		restore_source.contains(
			"func _restore_pvp_opponent_response_presentation(\n"
			+ "\tbatch_context: Dictionary,\n"
			+ "\tresponse: Dictionary,\n"
			+ "\trendered_events: Array\n"
			+ ") -> void:"
		),
		true,
		"post-render callback accepts call-time batch context before bound response arguments"
	)
	_check_equal(restore_source.contains("batch_context.get(\"event_seq_end\", -1)"), true, "canonical restore uses the active batch cursor before it completes")
	_check_equal(restore_source.contains("_update_active_sprites(\"pvp_authoritative_restore\")"), true, "canonical sprite refresh occurs inside the active batch")


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

func _check_api_response_uses_rendered_event_cursor() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := source.find("func _apply_api_response(")
	var apply_next_index := source.find("\nfunc ", apply_index + 1)
	var apply_source := source.substr(apply_index, apply_next_index - apply_index)

	_check_equal(apply_index >= 0, true, "shared API response loader exists")
	_check_equal(
		apply_source.contains(
			"action_flow.apply_response(\n"
			+ "\t\tresponse,\n"
			+ "\t\tapply_event_conditions,\n"
			+ "\t\tnot defer_state_load,\n"
			+ "\t\trendered_event_cursor\n"
			+ "\t)"
		),
		true,
		"NPC and PvP responses cannot rewind HP events that were already rendered"
	)


func _check_chained_force_switch_request_survives_entry_hazard_faint() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var process_index := source.find("func _process_pvp_choice_queue_entry(")
	var process_next_index := source.find("\nfunc ", process_index + 1)
	var process_source := source.substr(process_index, process_next_index - process_index)
	var preserve_index := source.find("func _clear_completed_local_force_switch_request(")
	var preserve_next_index := source.find("\nfunc ", preserve_index + 1)
	var preserve_source := source.substr(preserve_index, preserve_next_index - preserve_index)

	_check_equal(
		process_source.contains("_clear_completed_local_force_switch_request(display_response)"),
		true,
		"completed local forced switch checks for a chained request"
	)
	_check_equal(
		preserve_source.contains(
			"BattleForceSwitchFlow.should_preserve_chained_request("
		),
		true,
		"entry-hazard faint keeps the newly issued forced-switch request selectable"
	)
	_check_equal(
		preserve_source.contains("_clear_force_switch_request_for_player(_get_local_state_player_id())"),
		true,
		"resolved forced switches still clear their completed request"
	)


func _check_pivot_ko_wait_state_blocks_fainted_fallback() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	for function_name in [
		"_local_player_needs_force_switch_ui",
		"_opponent_player_needs_force_switch_ui",
	]:
		var function_index := source.find("func %s() -> bool:" % function_name)
		var next_function_index := source.find("\nfunc ", function_index + 1)
		var function_source := source.substr(function_index, next_function_index - function_index)
		var waiting_guard_index := function_source.find(
			"if request_is_waiting or not decision_allows_choice:"
		)
		var fainted_fallback_index := function_source.find(
			"should_infer_pvp_force_switch_from_fainted_active"
		)

		_check_equal(function_index >= 0, true, "%s exists" % function_name)
		_check_equal(
			waiting_guard_index >= 0 and waiting_guard_index < fainted_fallback_index,
			true,
			"%s honors wait/LOCKED before the fainted-active fallback" % function_name
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
	_check_equal(
		apply_source.contains("not defer_state_load,\n\t\trendered_event_cursor"),
		true,
		"action flow retains the current presentation state and ignores already rendered HP history"
	)
	_check_equal(
		apply_source.contains(
			"var rendered_event_cursor := _get_battle_state_render_cursor()"
		),
		true,
		"PvP state loading uses its render-batch cursor instead of the non-PvP cursor"
	)
	_check_equal(barrier_source.contains("pvp_event_queue.last_rendered_seq < 0"), true, "Team Preview can establish its lead state before the first render cursor")
	_check_equal(render_source.contains("if not _is_pvp_battle():\n\t\t_sync_presentation_field_from_battle_state()"), true, "PvP field effects are not overwritten before the render cursor advances")

	var force_wait_index := source.find("func _pvp_should_wait_for_force_switch_phase_release(")
	var force_wait_next_index := source.find("\nfunc ", force_wait_index + 1)
	var force_wait_source := source.substr(force_wait_index, force_wait_next_index - force_wait_index)
	_check_equal(
		force_wait_source.contains("return _pvp_is_waiting_for_force_switch_phase_release()"),
		true,
		"rendering_events to awaiting_force_switch always waits for released participant requests"
	)
	_check_equal(
		force_wait_source.contains("if _is_spectator_battle():\n\t\treturn false"),
		true,
		"spectators never block their render queue on participant force-switch prompts"
	)

	var show_moves_index := source.find("func _show_moves() -> void:")
	var show_moves_next_index := source.find("\nfunc ", show_moves_index + 1)
	var show_moves_source := source.substr(show_moves_index, show_moves_next_index - show_moves_index)
	_check_equal(
		show_moves_source.contains("if _pvp_is_waiting_for_force_switch_phase_release():"),
		true,
		"move controls cannot reopen inside the force-switch render barrier"
	)
	_check_equal(
		show_moves_source.contains('current_action_panel.set_message(_t("battle.prompt.waiting_switch"))'),
		true,
		"critical-hit text is replaced while waiting for the force-switch phase"
	)
	_check_equal(
		show_moves_source.contains('str(pvp_event_queue.current_event_batch_id) != ""'),
		true,
		"phase updates cannot reopen move controls during an active render batch"
	)

	var ack_callback_index := source.find("func _on_pvp_render_batch_completed(")
	var ack_callback_next_index := source.find("\nfunc ", ack_callback_index + 1)
	var ack_callback_source := source.substr(
		ack_callback_index,
		ack_callback_next_index - ack_callback_index
	)
	var ack_retry_index := source.find("func _run_pvp_render_ack_retry(owned_generation: int) -> void:")
	var ack_retry_next_index := source.find("\nfunc ", ack_retry_index + 1)
	var ack_retry_source := source.substr(ack_retry_index, ack_retry_next_index - ack_retry_index)
	_check_equal(
		ack_callback_source.contains("_start_pvp_render_ack_retry()"),
		true,
		"successful renders start reliable ACK delivery"
	)
	_check_equal(
		ack_retry_source.contains("_retry_pending_pvp_render_ack()"),
		true,
		"render ACK is retried until the released phase is observed"
	)
	_check_equal(
		ack_retry_source.contains('pvp_last_phase == "rendering_events"'),
		false,
		"render ACK retry does not depend on a potentially stale local phase"
	)

	var realtime_update_index := source.find("func _on_pvp_realtime_battle_update(")
	var realtime_update_next_index := source.find("\nfunc ", realtime_update_index + 1)
	var realtime_update_source := source.substr(
		realtime_update_index,
		realtime_update_next_index - realtime_update_index
	)
	_check_equal(
		realtime_update_source.find('if message_type == "pvp.phase_update":')
			< realtime_update_source.find("var is_snapshot_message :="),
		true,
		"phase releases bypass the generic realtime stale filter"
	)


func _check_pvp_restore_keeps_rendered_hp_and_field_events() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var restore_index := source.find("func _restore_pvp_authoritative_presentation(")
	var restore_next_index := source.find("\nfunc ", restore_index + 1)
	var restore_source := source.substr(restore_index, restore_next_index - restore_index)
	var condition_index := source.find("func _reapply_rendered_condition_events(events: Array) -> void:")
	var condition_next_index := source.find("\nfunc ", condition_index + 1)
	var condition_source := source.substr(condition_index, condition_next_index - condition_index)
	var sync_index := source.find("func _sync_presentation_field_from_battle_state() -> void:")
	var sync_next_index := source.find("\nfunc ", sync_index + 1)
	var sync_source := source.substr(sync_index, sync_next_index - sync_index)
	var reconciliation_index := source.find("func _apply_pvp_snapshot_reconciliation(")
	var reconciliation_next_index := source.find("\nfunc ", reconciliation_index + 1)
	var reconciliation_source := source.substr(reconciliation_index, reconciliation_next_index - reconciliation_index)

	_check_equal(restore_source.contains("_reapply_rendered_condition_events(rendered_events)"), true, "canonical restore retains rendered hazard HP")
	_check_equal(restore_source.contains("_reapply_rendered_field_effect_events(rendered_events)"), false, "canonical restore cannot replay field starts against a future turn")
	_check_equal(condition_source.contains('"damage", "heal", "faint", "status", "ability", "pokemonEffect":'), true, "restore replays condition and form-changing events")
	_check_equal(condition_source.contains('"switch", "drag":'), true, "restore recognizes public spectator switch events")
	_check_equal(condition_source.contains("if _is_spectator_battle():"), true, "only spectators replay switches over a request-free public batch")
	_check_equal(condition_source.contains("Participant switch events deliberately remain canonical"), true, "participant Pursuit presentation keeps canonical switch state")
	var render_events_index := source.find("func _render_battle_events(")
	var render_events_next_index := source.find("\nfunc ", render_events_index + 1)
	var render_events_source := source.substr(render_events_index, render_events_next_index - render_events_index)
	_check_equal(render_events_source.contains("var defer_field_effect_end :="), true, "field-ending presentation has an explicit event boundary")
	_check_equal(
		render_events_source.find("await event_renderer.render_event(event_data, presentation, suppress_presentation_waits)")
			< render_events_source.find("if defer_field_effect_end:", render_events_source.find("await event_renderer.render_event(event_data, presentation, suppress_presentation_waits)")),
		true,
		"weather and terrain disappear only after their ordered end event is presented"
	)
	_check_equal(sync_source.contains('if not battle_state.field.has("effects"):'), true, "omitted realtime field snapshot cannot erase active weather")
	_check_equal(reconciliation_source.contains("_sync_presentation_field_from_battle_state()"), true, "cursor-safe snapshot reconciliation can recover complete field presentation")
	_check_equal(render_events_source.contains("presentation_state.set_turn(turn)"), true, "turn UI advances at the ordered turn event")
	_check_equal(render_events_source.contains("_update_battle_status_panels()"), true, "ordered turn events refresh the visible turn and effect counters")


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


func _check_stale_local_response_cannot_restart_consumed_waiter() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := source.find("func _apply_api_response(")
	var apply_next_index := source.find("\nfunc ", apply_index + 1)
	var apply_source := source.substr(apply_index, apply_next_index - apply_index)
	var drain_index := source.find("func _drain_pvp_event_queue() -> bool:")
	var drain_next_index := source.find("\nfunc ", drain_index + 1)
	var drain_source := source.substr(drain_index, drain_next_index - drain_index)

	_check_equal(
		apply_source.contains("and not is_required_render_batch"),
		true,
		"an unrendered authoritative batch bypasses stale canonical-state rejection"
	)
	_check_equal(
		apply_source.contains('apply_outcome["status"] = "stale_noop"'),
		true,
		"the shared response loader exposes stale success as an explicit no-op"
	)
	_check_equal(
		drain_source.contains('str(apply_outcome.get("status", "")) == "applied"')
			and drain_source.contains("and not skip_render"),
		true,
		"a stale or already-rendered local envelope cannot start a second opponent waiter"
	)
	_check_equal(
		drain_source.find("_acknowledge_already_rendered_pvp_batch(queue_response, source)")
			< drain_source.find("var should_process_choice_entry :="),
		true,
		"duplicate render delivery still retries its ACK before being treated as a no-op"
	)


func _check_event_ahead_snapshot_bypasses_only_transport_supersession() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var reconcile_index := source.find("func _reconcile_pvp_battle_from_room(")
	var reconcile_next_index := source.find("\nfunc ", reconcile_index + 1)
	var reconcile_source := source.substr(reconcile_index, reconcile_next_index - reconcile_index)
	var http_index := source.find("func _apply_pvp_http_reconciliation_when_safe(")
	var http_next_index := source.find("\nfunc ", http_index + 1)
	var http_source := source.substr(http_index, http_next_index - http_index)
	var stale_index := source.find("func _is_stale_pvp_snapshot_response(")
	var stale_next_index := source.find("\nfunc ", stale_index + 1)
	var stale_source := source.substr(stale_index, stale_next_index - stale_index)

	_check_equal(
		reconcile_source.contains("has_required_render_catchup")
			and reconcile_source.contains(") and not has_required_render_catchup:"),
		true,
		"the opponent watchdog accepts a snapshot only when its event cursor advances presentation"
	)
	_check_equal(
		reconcile_source.contains("source,\n\t\thas_required_render_catchup")
			and http_source.contains("allow_unrendered_event_catchup := false")
			and http_source.contains("may_apply_unrendered_event_catchup")
			and http_source.contains("_is_stale_pvp_snapshot_response("),
		true,
		"only the event-ahead watchdog forwards catch-up proof into HTTP snapshot ordering"
	)
	var battle_guard_index := stale_source.find('response_battle_id != battle_state.battle_id')
	var turn_guard_index := stale_source.find("response_turn < current_turn")
	var order_guard_index := stale_source.find("pvp_response_order.is_stale(response)")
	_check_equal(
		battle_guard_index >= 0
			and turn_guard_index > battle_guard_index
			and order_guard_index > turn_guard_index,
		true,
		"event catch-up never bypasses cross-battle or older-turn safety checks"
	)


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
	var drain_index := source.find("func _drain_pvp_event_queue() -> bool:")
	var drain_next_index := source.find("\nfunc ", drain_index + 1)
	var drain_source := source.substr(drain_index, drain_next_index - drain_index)
	var idle_drain_index := source.find("func _drain_idle_pvp_realtime_updates() -> void:")
	var idle_drain_next_index := source.find("\nfunc ", idle_drain_index + 1)
	var idle_drain_source := source.substr(idle_drain_index, idle_drain_next_index - idle_drain_index)
	var reconciliation_index := source.find("func _apply_pvp_snapshot_reconciliation(")
	var reconciliation_next_index := source.find("\nfunc ", reconciliation_index + 1)
	var reconciliation_source := source.substr(reconciliation_index, reconciliation_next_index - reconciliation_index)

	_check_equal(finish_index >= 0, true, "authoritative terminal handler exists")
	_check_equal(finish_source.contains("should_defer_authoritative_terminal_until_render"), true, "normal terminal waits while canonical render work is unfinished")
	_check_equal(finish_source.contains("is_animation_free_authoritative_terminal_reason(end_reason)"), true, "durable timeout, disconnect, and forfeit are recognized as animation-free terminal work")
	_check_equal(finish_source.contains("not is_animation_free_terminal"), true, "animation-free terminal work does not wait forever for a separate ended projection")
	_check_equal(finish_source.contains("pvp_pending_authoritative_terminal = message.duplicate(true)"), true, "early terminal is retained for post-render completion")
	_check_equal(callback_source.contains("_retry_pending_pvp_authoritative_terminal.call_deferred()"), true, "render completion retries the retained terminal")
	_check_equal(drain_source.contains("_retry_pending_pvp_authoritative_terminal.call_deferred()"), true, "render queue exhaustion retries the retained terminal")
	_check_equal(idle_drain_source.contains("_retry_pending_pvp_authoritative_terminal.call_deferred()"), true, "realtime queue exhaustion retries the retained terminal")
	_check_equal(reconciliation_source.contains("_retry_pending_pvp_authoritative_terminal.call_deferred()"), true, "ended snapshot reconciliation retries the retained terminal")
	_check_equal(reconciliation_source.contains("_update_pvp_phase_contract_from_response(reconciliation, source)"), true, "canonical reconciliation also restores the authoritative phase")


func _check_local_forfeit_terminal_unblocks_action_wait() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var confirm_index := source.find("func _on_forfeit_confirmed() -> void:")
	var confirm_next_index := source.find("\nfunc ", confirm_index + 1)
	var confirm_source := source.substr(confirm_index, confirm_next_index - confirm_index)
	var wait_index := source.find("func _send_pvp_realtime_action_and_wait(")
	var wait_next_index := source.find("\nfunc ", wait_index + 1)
	var wait_source := source.substr(wait_index, wait_next_index - wait_index)
	var recovery_index := source.find("func _recover_pvp_realtime_action_timeout(")
	var recovery_next_index := source.find("\nfunc ", recovery_index + 1)
	var recovery_source := source.substr(recovery_index, recovery_next_index - recovery_index)

	_check_equal(confirm_source.find("if battle_finished:") < confirm_source.find("_set_battle_input_locked(false)", confirm_source.find("var response: Dictionary = await _submit_pvp_realtime_forfeit()")), true, "finished forfeit cannot unlock or overwrite its result UI")
	_check_equal(confirm_source.contains("_finish_confirmed_pvp_forfeit(response, _get_local_state_player_id(), \"pvp_forfeit_submit\")"), true, "confirmed local forfeit bypasses the normal animation queue")
	_check_equal(wait_source.contains("if battle_finished:"), true, "every action waiter exits when a durable terminal wins the race")
	_check_equal(wait_source.contains('"terminalConfirmed": true'), true, "action waiter returns a successful terminal confirmation")
	_check_equal(wait_source.contains("await _recover_pvp_realtime_action_timeout(action, player_id, decision)"), true, "lost action responses are classified from the canonical room")
	_check_equal(recovery_source.contains("request_start_activity_seq"), true, "timeout recovery records realtime activity before starting its HTTP request")
	_check_equal(recovery_source.contains("realtime_advanced_during_request"), true, "timeout recovery rejects an HTTP snapshot superseded by realtime")
	_check_equal(recovery_source.contains("_apply_pvp_http_reconciliation_when_safe("), true, "timeout recovery uses the render-safe HTTP snapshot boundary")
	_check_equal(recovery_source.contains("_build_pvp_action_timeout_recovery_response(response, recovery_status)"), true, "server-proven accepted actions survive temporarily unsafe visual reconciliation")
	_check_equal(recovery_source.contains("await _finish_if_battle_ended"), true, "canonical timeout recovery only finishes from a terminal mechanical state")

	var submit_index := source.find("func _submit_pvp_realtime_choice(")
	var submit_next_index := source.find("\nfunc ", submit_index + 1)
	var submit_source := source.substr(submit_index, submit_next_index - submit_index)
	_check_equal(
		submit_source.find("_show_pvp_move_confirmation(")
			< submit_source.find("await _send_pvp_realtime_action_and_wait("),
		true,
		"move confirmation replaces the stale prompt before waiting on realtime transport"
	)
	_check_equal(
		submit_source.find('current_action_panel.set_message("Waiting for opponent...")')
			< submit_source.find("await _send_pvp_realtime_action_and_wait("),
		true,
		"participant waiting text appears immediately after submitting a choice"
	)


func _check_force_switch_phase_release_recovers() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var wait_index := source.find("func _wait_for_pvp_force_switch_phase_release(source: String) -> bool:")
	var wait_next_index := source.find("\nfunc ", wait_index + 1)
	var wait_source := source.substr(wait_index, wait_next_index - wait_index)
	var completion_index := source.find("func _on_pvp_render_batch_completed(completion: Dictionary) -> void:")
	var completion_next_index := source.find("\nfunc ", completion_index + 1)
	var completion_source := source.substr(completion_index, completion_next_index - completion_index)
	var reconciliation_index := source.find("func _reconcile_pvp_battle_from_room(")
	var reconciliation_next_index := source.find("\nfunc ", reconciliation_index + 1)
	var reconciliation_source := source.substr(reconciliation_index, reconciliation_next_index - reconciliation_index)
	var opponent_wait_index := source.find("func _wait_for_pvp_opponent_force_switch_and_render() -> bool:")
	var opponent_wait_next_index := source.find("\nfunc ", opponent_wait_index + 1)
	var opponent_wait_source := source.substr(opponent_wait_index, opponent_wait_next_index - opponent_wait_index)

	_check_equal(wait_index >= 0, true, "force-switch phase release wait exists")
	_check_equal(wait_source.contains("_retry_pending_pvp_render_ack()"), true, "stalled pivot phase retries its idempotent render acknowledgement")
	_check_equal(wait_source.contains('await _reconcile_pvp_battle_from_room("pvp_force_switch_phase_release_recovery")'), true, "stalled pivot phase polls the canonical room")
	_check_equal(wait_source.contains("PVP_FORCE_SWITCH_RECONCILE_MAX_MSEC"), true, "canonical pivot recovery uses a bounded polling interval")
	_check_equal(completion_source.contains("pvp_pending_render_ack_completion = completion.duplicate(true)"), true, "successful render completion retains retryable ACK evidence")
	_check_equal(reconciliation_source.contains("realtime_advanced_during_request"), true, "late room polling cannot overwrite a newer realtime phase")
	_check_equal(reconciliation_source.contains("request_start_activity_seq"), true, "room polling also fences queued realtime activity")
	_check_equal(reconciliation_source.contains("await _apply_pvp_http_reconciliation_when_safe("), true, "room polling uses the render-safe HTTP snapshot boundary")
	var http_reconciliation_index := source.find("func _apply_pvp_http_reconciliation_when_safe(")
	var http_reconciliation_next_index := source.find("\nfunc ", http_reconciliation_index + 1)
	var http_reconciliation_source := source.substr(
		http_reconciliation_index,
		http_reconciliation_next_index - http_reconciliation_index
	)
	_check_equal(
		http_reconciliation_source.contains("_promote_pvp_battle_update_fallback_render(")
			and http_reconciliation_source.contains("await _enqueue_pvp_battle_response("),
		true,
		"a canonical room poll promotes a missed realtime render batch into ordered catch-up"
	)
	_check_equal(
		wait_source.contains("reconciled and pvp_event_queue.has_pending()"),
		true,
		"the pivoting client unwinds its wait so an HTTP-recovered batch can drain"
	)
	_check_equal(opponent_wait_source.contains("_retry_pending_pvp_render_ack()"), true, "the non-pivoting client also retries its barrier acknowledgement")
	_check_equal(opponent_wait_source.contains('await _reconcile_pvp_battle_from_room("pvp_opponent_force_switch_barrier_recovery")'), true, "the non-pivoting client also recovers a missed barrier release")
	_check_equal(
		opponent_wait_source.contains('"pvp_opponent_force_switch_render_watchdog",\n\t\t\t\ttrue')
			and opponent_wait_source.find("pvp_opponent_force_switch_render_watchdog")
				< opponent_wait_source.find("if _pvp_is_waiting_for_force_switch_phase_release():"),
		true,
		"the forced-switch waiter recovers a missing post-pivot render batch without waiting for a phase update"
	)
	_check_equal(
		opponent_wait_source.contains("reconciled and pvp_event_queue.has_pending()"),
		true,
		"the non-pivoting client unwinds its wait so an HTTP-recovered switch can render"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
