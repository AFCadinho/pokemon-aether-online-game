extends "res://scripts/world/world.gd"

var callback_calls := 0
var start_response: Dictionary = {}
var change_session := false

func _build_current_player_position_state(_spawn_marker: String, _use_confirmed := false) -> Dictionary:
	return {"mapId": "fixture", "position": {"x": 10.0, "y": 20.0}, "walkSteps": pending_happiness_walk_steps, "appearance": {}}

func _get_current_player_position_signature(_confirmed := false) -> String:
	return "fixture-position"

func start_probe(state: Dictionary) -> Dictionary:
	callback_calls += 1
	assert(int(state.get("walkSteps")) == 10)
	await get_tree().process_frame
	if change_session:
		AuthService.session_token = "different-fixture-session"
	return start_response
