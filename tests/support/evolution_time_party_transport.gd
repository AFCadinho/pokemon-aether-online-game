extends "res://scripts/services/player_party_state_service.gd"

signal release_held_response

var requests: Array[Dictionary] = []
var responses: Array[Dictionary] = []
var hold_next := false


func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, body: String) -> Dictionary:
	requests.append(JSON.parse_string(body) as Dictionary)
	var response: Dictionary = responses.pop_front() if not responses.is_empty() else {"success": false, "error": "Missing fixture response"}
	if hold_next:
		hold_next = false
		await release_held_response
	else:
		await get_tree().process_frame
	return response


func _apply_party_response(_result: Dictionary) -> void:
	pass
