extends "res://scripts/battle/battle.gd"

signal continue_player_lead
signal continue_npc_lead
signal continue_preview
signal setup_finished
var player_lead_waiting := false
var npc_lead_waiting := false
var preview_waiting := false

func run_setup(preview := false) -> void:
	await setup_trainer_battle_from_response(
		PlayerSave.party[0], {"id": "fixture_trainer", "name": "Fixture Trainer", "_battle_sprite_frames": preload("res://assets/npcs/generic_npc_fallback_frames.tres")},
		{"battleOptions": {"teamPreview": preview}}, Callable(), &"route_1"
	)
	setup_finished.emit()

func _apply_team_preview_battle_response(_response: Dictionary) -> bool:
	return true
func _show_default_trainer_leads_before_selection(_pokemon: Pokemon, _response: Dictionary) -> void:
	pass
func _submit_lead(_player_id: String, _slot: int) -> Dictionary:
	player_lead_waiting = true
	await continue_player_lead
	player_lead_waiting = false
	# Simulate a state refresh trying to show mechanically selected combatants.
	enemy_sprite_box.show()
	enemy_team_preview_layer.show()
	return {"success": true}
func _submit_npc_lead() -> Dictionary:
	npc_lead_waiting = true
	await continue_npc_lead
	npc_lead_waiting = false
	return {"success": false, "error": "fixture lead rejection"}
func _run_trainer_team_preview_lead_selection() -> Dictionary:
	preview_waiting = true
	await continue_preview
	preview_waiting = false
	return {}

func _submit_default_trainer_leads(slot: int) -> Dictionary:
	await _submit_lead("p1", slot)
	return await _submit_npc_lead()
