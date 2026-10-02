extends "res://tests/fixtures/wild_entry_request_probe.gd"

var entry_result: Dictionary = {}
func run_trainer_entry() -> void:
	entry_result = await start_trainer_battle({"id": "fixture_trainer", "name": "Fixture Trainer", "_battle_sprite_frames": preload("res://assets/npcs/generic_npc_fallback_frames.tres")})
	entry_finished.emit()

func create_trainer_battle_response(_trainer_id: String, _is_rematch := false) -> Dictionary:
	response_waiting = true
	await continue_response
	response_waiting = false
	return {"success": false, "code": "offline_fixture_rejection", "error": "fixture rejection"}
