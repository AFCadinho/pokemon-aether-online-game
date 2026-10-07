extends "res://scripts/services/player_game_state_service.gd"

var saves := 0
var saved_payload: Dictionary = {}
var save_reply := {"success": true, "hasState": true, "state": {"teleportRevision": 7}}
func save_player_position(state: Dictionary) -> Dictionary:
	saves += 1
	saved_payload = state.duplicate(true)
	await get_tree().process_frame
	return save_reply
