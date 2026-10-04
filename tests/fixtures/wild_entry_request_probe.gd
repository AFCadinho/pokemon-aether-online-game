extends "res://scripts/world/world.gd"

signal continue_position
signal continue_response
signal entry_finished
var position_waiting := false
var response_waiting := false

func run_entry() -> void:
	await start_triggered_wild_battle_for_area("fixture", "grass", "Pikachu")
	entry_finished.emit()

func _lock_overworld_for_battle() -> void:
	pass
func _unlock_overworld_after_battle() -> void:
	pass
func _publish_world_presence(_force := false) -> void:
	pass
func _save_player_activity_state_deferred(_state: String, _context: Dictionary = {}) -> void:
	pass
func _show_wild_encounter_start_error(_response: Dictionary) -> void:
	pass
func sync_player_position_for_world_action() -> Dictionary:
	position_waiting = true
	await continue_position
	position_waiting = false
	return {"success": true}
func create_triggered_wild_battle_response(_area: String, _encounter_type := "grass", _forced_species := "", _static_encounter_id := "") -> Dictionary:
	response_waiting = true
	await continue_response
	response_waiting = false
	return {"success": false, "code": "offline_fixture_rejection", "error": "fixture rejection"}
