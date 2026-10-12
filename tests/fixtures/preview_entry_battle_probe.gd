extends "res://scripts/battle/battle.gd"

# Preserve production response mapping and entry callbacks; stop at lead input.
signal finish_selection
var selection_started := false
var setup_finished := false

func run_setup(player: Pokemon, response: Dictionary, callback: Callable, training: bool) -> void:
	if training:
		await setup_trainer_battle_from_response(player, {"name": "Scholar"}, response, callback, &"pvp_stadium", true)
	else:
		await setup_pvp_battle_from_response(player, response, callback)
	setup_finished = true

func _connect_pvp_realtime(_player_id: String, _battle_id: String, _response: Dictionary = {}) -> void:
	pass

func _run_trainer_team_preview_lead_selection() -> Dictionary:
	return await _stop_at_selection()

func _run_pvp_team_preview_lead_selection(_player_id: String) -> Dictionary:
	return await _stop_at_selection()

func _stop_at_selection() -> Dictionary:
	selection_started = true
	_set_battle_input_locked(false)
	await finish_selection
	return {}
