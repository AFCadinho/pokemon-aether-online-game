extends "res://scripts/services/coop_service.gd"
signal response_ready(response: Dictionary)
var requests: Array[Dictionary] = []
func _request(action: String, payload: Dictionary) -> Dictionary:
	requests.append({"action": action, "payload": payload.duplicate(true)})
	return await response_ready
func refresh() -> Dictionary:
	return {"success": false}
