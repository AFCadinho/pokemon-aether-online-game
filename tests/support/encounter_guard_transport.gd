extends "res://scripts/services/encounter_guard_service.gd"

var requests: Array[Dictionary] = []
var response: Dictionary = {}
var logged_out := false

func _request(method: HTTPClient.Method, suffix := "", body: Dictionary = {}) -> Dictionary:
	requests.append({"method": method, "suffix": suffix, "body": body.duplicate(true)})
	await get_tree().process_frame
	return response.duplicate(true)

func _logout() -> void:
	logged_out = true
	guard = {}
	_reset_renewal()
	AuthService.session_token = ""
	AuthService.current_user = {}
	_hide_lock()
