extends "res://scripts/services/guild_service.gd"

var response: Dictionary = {}
var requests: Array = []
var wait_for_frame := false

func _authenticated_request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	requests.append([path, method, JSON.parse_string(body)])
	if wait_for_frame:
		await get_tree().process_frame
	return response.duplicate(true)
