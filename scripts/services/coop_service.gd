extends Node

signal state_changed
signal request_failed(message: String)

const ORDINARY_TRAINERS := [
	"kanto_route_1_lass_zoe",
	"kanto_route_2_youngster_mason",
	"kanto_route_2_bug_catcher_cale",
	"kanto_viridian_forest_bug_catcher_rick",
	"kanto_viridian_forest_bug_catcher_doug",
	"kanto_viridian_forest_bug_catcher_anthony",
	"kanto_pewter_city_gym_hiker_flint",
	"kanto_pewter_city_gym_youngster_stone",
]


func trainer_entity(trainer_id: String) -> String:
	if trainer_id in ORDINARY_TRAINERS or trainer_id == "kanto_alpha_gym_brock": return trainer_id
	if trainer_id in ["kanto_route_22_gary_rival", "kanto_route_22_gary_bulbasaur", "kanto_route_22_gary_squirtle", "kanto_route_22_gary_charmander"]:
		return "kanto_route_22_gary_oak"
	return ""

var available := false
var party: Dictionary = {}
var invitations: Array = []
var activity: Dictionary = {}
var view: Dictionary = {}
var pending_command: Dictionary = {}
var pending_start: Dictionary = {}
var _polling := false
var _poll_after := 0.0
var _session_identity := ""
var _sequence := 0
var _applied_sequence := 0


func _process(delta: float) -> void:
	if not AuthService.is_authenticated() or OS.has_feature("web"):
		if not _session_identity.is_empty():
			reset()
		return
	var identity := str(AuthService.current_user.get("id", ""))
	if identity != _session_identity:
		reset()
		_session_identity = identity
	if GameState.get_world() == null:
		return
	_poll_after -= delta
	if _poll_after <= 0.0 and not _polling:
		_polling = true
		await refresh()
		_polling = false
		_poll_after = 2.0 if available else 30.0


func reset() -> void:
	available = false
	party = {}
	invitations = []
	activity = {}
	view = {}
	pending_command = {}
	pending_start = {}
	_session_identity = ""
	_sequence += 1
	_applied_sequence = _sequence
	_poll_after = 0.0
	state_changed.emit()


func refresh() -> Dictionary:
	_sequence += 1
	var sequence := _sequence
	var result := await _request("state", {})
	if result.get("success", false) and sequence >= _applied_sequence:
		_applied_sequence = sequence
		available = true
		apply_state(result.get("body", {}))
	return result


func apply_state(body: Dictionary) -> void:
	party = body.get("party", {}) if body.get("party") is Dictionary else {}
	invitations = body.get("invitations", []) if body.get("invitations") is Array else []
	var incoming: Dictionary = body.get("activity", {}) if body.get("activity") is Dictionary else {}
	if incoming.get("reservationId", "") != activity.get("reservationId", ""):
		view = {}
		pending_command = {}
	elif activity.get("status") in ["finished", "cancelled"] and incoming.get("status") in ["starting", "active"]:
		return
	activity = incoming.duplicate(true)
	if body.get("view") is Dictionary:
		apply_view(body["view"])
	state_changed.emit()


func apply_view(incoming: Dictionary) -> void:
	if str(incoming.get("battleId", "")) != str(activity.get("battleId", "")):
		return
	if not view.is_empty() and int(incoming.get("revision", -1)) < int(view.get("revision", -1)):
		return
	view = incoming.duplicate(true)
	if not pending_command.is_empty() and (view.get("decisionId") != pending_command.get("decisionId") or view.get("locked", true)):
		pending_command = {}
	state_changed.emit()


func try_start(trainer_id: String) -> Dictionary:
	if OS.has_feature("web") or not AuthService.is_authenticated():
		return {"handled": false}
	var state_result := await refresh()
	if not state_result.get("success", false):
		if state_result.get("code") == "coop_gameplay_disabled" and party.is_empty() and activity.is_empty():
			return {"handled": false}
		return {"handled": true, "success": false, "code": "coop_state_unavailable"}
	if party.is_empty():
		return {"handled": false}
	if int(party.get("leaderId", 0)) != int(AuthService.current_user.get("id", 0)):
		return {"handled": true, "success": false, "code": "coop_leader_required"}
	var entity := trainer_entity(trainer_id)
	if entity.is_empty():
		return {"handled": true, "success": false, "code": "coop_interaction_unsupported"}
	var world := GameState.get_world()
	if world == null:
		return {"handled": true, "success": false, "code": "coop_world_unavailable"}
	var position_result: Dictionary = await world.call("sync_player_position_for_world_action")
	if not position_result.get("success", false):
		return {"handled": true, "success": false, "code": "coop_position_unavailable"}
	if pending_start.is_empty():
		pending_start = {"reservationId": new_id(), "entityId": entity}
	elif pending_start.get("entityId") != entity:
		return {"handled": true, "success": false, "code": "coop_start_pending"}
	var result := await _request("start", pending_start)
	# Even when the response was lost, discover the committed shared reservation.
	await refresh()
	if activity.get("reservationId") == pending_start.get("reservationId"):
		pending_start = {}
		return {"handled": true, "success": true, "battleId": activity.get("battleId", "")}
	if result.get("success", false):
		_poll_after = 0.0
		return {"handled": true, "success": true, "battleId": "coop-" + str(pending_start["reservationId"])}
	if int(result.get("status", 0)) in [400, 401, 403, 404, 409, 422]:
		pending_start = {}
	return {"handled": true, "success": false, "code": result.get("code", "coop_start_pending")}


func submit_action(action: Dictionary) -> Dictionary:
	if view.is_empty() or view.get("locked", true) or not pending_command.is_empty():
		return {"success": false}
	if not (view.get("legalActions", []) as Array).has(action):
		return {"success": false}
	pending_command = {"reservationId": activity["reservationId"], "decisionId": view["decisionId"],
		"idempotencyKey": new_id(), "action": action.duplicate(true)}
	state_changed.emit()
	return await retry_command()


func retry_command() -> Dictionary:
	if pending_command.is_empty():
		return {"success": false}
	var result := await _request("decision", pending_command)
	if result.get("success", false):
		pending_command = {}
		apply_view(result.get("body", {}).get("view", {}))
	else:
		await refresh()
		if int(result.get("status", 0)) == 409:
			pending_command = {}
		request_failed.emit("Connection interrupted. Your choice will be checked before retrying.")
	state_changed.emit()
	return result


func party_action(action: String, payload: Dictionary = {}) -> Dictionary:
	var result := await _request(action, payload)
	if not result.get("success", false):
		request_failed.emit(str(result.get("error", "Co-op request could not be completed.")))
	await refresh()
	return result


func new_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20, 12)]


func _request(action: String, payload: Dictionary) -> Dictionary:
	var auth_header := AuthService.get_authorization_header()
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.body_size_limit = 262144
	add_child(request)
	var url: String = await GatewayApiConfig.get_base_url()
	if auth_header != AuthService.get_authorization_header():
		request.queue_free()
		return {"success": false, "code": "coop_session_changed"}
	var error := request.request(url + "/game/coop/" + action, GatewayApiConfig.get_json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		return {"success": false, "code": "coop_connection_unavailable"}
	var response: Array = await request.request_completed
	request.queue_free()
	if auth_header != AuthService.get_authorization_header():
		return {"success": false, "code": "coop_session_changed"}
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var status := int(response[1])
	var detail: Dictionary = data.get("detail", {}) if data.get("detail") is Dictionary else {}
	return {"success": int(response[0]) == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300,
		"status": status, "body": data, "code": detail.get("code", "coop_connection_unavailable"),
		"error": BackendErrorLocalizationService.message({"body": data, "status": status})}
