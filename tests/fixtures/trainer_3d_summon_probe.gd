extends "res://scripts/battle/battle.gd"

signal choose_leads
signal command_started(player_id: String)
var lead_response: Dictionary
var waiting_for_leads := false
var setup_finished := false

func run_setup(player: Pokemon, response: Dictionary) -> void:
	await setup_trainer_battle_from_response(player, {
		"name": "Visibility fixture",
		"_battle_sprite_frames": preload("res://assets/npcs/generic_npc_fallback_frames.tres"),
	}, response)
	setup_finished = true

func _apply_team_preview_battle_response(response: Dictionary) -> bool:
	battle_state.load_from_api_response(response, false)
	return true

func _run_trainer_lead_selection(response: Dictionary) -> Dictionary:
	team_preview_lead_selection_active = _trainer_team_preview_enabled(response)
	if team_preview_lead_selection_active:
		_show_team_preview_layers()
	waiting_for_leads = true
	await choose_leads
	waiting_for_leads = false
	team_preview_lead_selection_active = false
	if not lead_response.is_empty():
		battle_state.load_from_api_response(lead_response, false)
		opponent_party_reveal_policy.reveal_active(_get_display_team_data("p2"))
		# Include a response/settings refresh before setup populates leads again.
		_update_active_sprites("snapshot_reconciliation")
	return lead_response

func _present_initial_summon_command(player_id: String, _pokemon_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	command_started.emit(player_id)

func _render_initial_battle_events(_response: Dictionary) -> void:
	pass
