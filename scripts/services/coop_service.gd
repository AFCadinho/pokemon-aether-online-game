extends Node

signal state_changed
signal partner_connection_changed(connected: bool)
signal request_failed(message: String)
signal invitation_received(invitation: Dictionary)
signal invitation_sent(username: String)
signal invitation_failed(message: String)
signal party_profile_missing(source: String)

const ORDINARY_TRAINERS := [
	"kanto_route_1_youngster_liam",
	"kanto_viridian_forest_bug_catcher_sammy",
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
var _seen_invitations: Dictionary = {}
var _sent_invitations: Dictionary = {}
var _reported_profile_source := ""


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
		var active_battle: bool = activity.get("status") == "active"
		var awaiting_battle: bool = activity.get("status") == "starting" or (active_battle and view.is_empty())
		var awaiting_exit: bool = activity.get("status") == "active" and (bool(view.get("ended", false))
			or (view.get("exitRequest") is Dictionary and not (view["exitRequest"] as Dictionary).is_empty()))
		var tracking_party_presence: bool = party.get("memberIds", []) is Array and party["memberIds"].size() == 2
		# Presence drives both the Adventure Party HUD and co-op AI takeover.
		# Keep it responsive while a party exists, and especially during a battle.
		_poll_after = 0.5 if awaiting_battle or awaiting_exit or active_battle else 1.0 if tracking_party_presence else 2.0 if available else 30.0


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
	_seen_invitations.clear()
	_sent_invitations.clear()
	_reported_profile_source = ""
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
	var previous_activity: Dictionary = activity.duplicate(true)
	party = body.get("party", {}) if body.get("party") is Dictionary else {}
	# Godot parses JSON numbers as floats (e.g. 7.0), but the server's public
	# member maps use canonical integer-string keys ("7").
	if party.get("memberIds") is Array:
		var normalized_ids: Array[int] = []
		for member_id: Variant in party["memberIds"]:
			normalized_ids.append(int(member_id))
		party["memberIds"] = normalized_ids
	if party.has("leaderId"):
		party["leaderId"] = int(party["leaderId"])
	var member_ids: Array = party.get("memberIds", []) if party.get("memberIds") is Array else []
	if member_ids.size() == 2:
		var names: Dictionary = party.get("memberUsernames", {}) if party.get("memberUsernames") is Dictionary else {}
		var appearances: Dictionary = party.get("memberAppearances", {}) if party.get("memberAppearances") is Dictionary else {}
		var incomplete := false
		for member_id: Variant in member_ids:
			var key := str(int(member_id))
			var appearance: Dictionary = appearances.get(key, {}) if appearances.get(key) is Dictionary else {}
			if str(names.get(key, "")).is_empty() or str(appearance.get("body", "")).is_empty():
				incomplete = true
		if incomplete:
			var source := _diagnostic_gateway_source()
			if source != _reported_profile_source:
				_reported_profile_source = source
				party_profile_missing.emit(source)
		else:
			_reported_profile_source = ""
	else:
		_reported_profile_source = ""
	invitations = body.get("invitations", []) if body.get("invitations") is Array else []
	var incoming: Dictionary = body.get("activity", {}) if body.get("activity") is Dictionary else {}
	if incoming.get("reservationId", "") != activity.get("reservationId", ""):
		view = {}
		pending_command = {}
	elif activity.get("status") in ["finished", "cancelled"] and incoming.get("status") in ["starting", "active"]:
		return
	activity = incoming.duplicate(true)
	var world := GameState.get_world()
	if activity.is_empty() and (world == null or not bool(world.get("is_in_battle"))):
		for invitation_value: Variant in invitations:
			if invitation_value is not Dictionary:
				continue
			var invitation: Dictionary = invitation_value
			var invitation_id := str(invitation.get("invitationId", ""))
			if invitation_id.is_empty() or _seen_invitations.has(invitation_id):
				continue
			_seen_invitations[invitation_id] = true
			invitation_received.emit(invitation.duplicate(true))
	if body.get("view") is Dictionary:
		apply_view(body["view"])
	state_changed.emit()
	var same_active_battle: bool = (
		str(previous_activity.get("reservationId", "")) != ""
		and previous_activity.get("reservationId") == activity.get("reservationId")
		and previous_activity.get("status") == "active"
		and activity.get("status") == "active"
	)
	if same_active_battle and bool(previous_activity.get("partnerConnected", true)) != bool(activity.get("partnerConnected", true)):
		partner_connection_changed.emit(bool(activity.get("partnerConnected", false)))


func _diagnostic_gateway_source() -> String:
	var gateway := str(GatewayApiConfig.cached_url)
	if gateway.begins_with("http://localhost:8000") or gateway.begins_with("http://127.0.0.1:8000"):
		return "local development"
	if gateway.begins_with("https://api.pokeaether.com"):
		return "production"
	return "custom/unknown"


func apply_view(incoming: Dictionary) -> void:
	if str(incoming.get("battleId", "")) != str(activity.get("battleId", "")):
		return
	if not view.is_empty() and int(incoming.get("revision", -1)) < int(view.get("revision", -1)):
		return
	view = incoming.duplicate(true)
	if bool(view.get("ended", false)) or (view.get("exitRequest") is Dictionary and not (view["exitRequest"] as Dictionary).is_empty()):
		_poll_after = 0.0
	if not pending_command.is_empty() and (view.get("decisionId") != pending_command.get("decisionId") or view.get("locked", true)
		or (view.get("exitRequest") is Dictionary and not view.get("legalActions", []).has(pending_command.get("action")))):
		pending_command = {}
	var recovered: Dictionary = view.get("pendingCapture", {}) if view.get("pendingCapture") is Dictionary else {}
	if pending_command.is_empty() and not recovered.is_empty() and recovered.get("decisionId") == view.get("decisionId") and not view.get("locked", true) and not view.get("exitRequest"):
		pending_command = {"reservationId": activity["reservationId"], "decisionId": recovered["decisionId"],
			"idempotencyKey": recovered["idempotencyKey"], "action": {"type": "capture", "itemId": recovered["itemId"]}}
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
	var world := GameState.get_world()
	if world == null:
		return {"handled": true, "success": false, "code": "coop_world_unavailable"}
	var position_result: Dictionary = await world.call("sync_player_position_for_world_action")
	if not position_result.get("success", false):
		return {"handled": true, "success": false, "code": "coop_position_unavailable"}
	state_result = await refresh()
	if not state_result.get("success", false):
		return {"handled": true, "success": false, "code": "coop_state_unavailable"}
	if party.is_empty():
		return {"handled": false}
	if not _partner_is_ready_for_coop():
		return {"handled": false}
	if int(party.get("leaderId", 0)) != int(AuthService.current_user.get("id", 0)):
		return {"handled": true, "success": false, "code": "coop_leader_required"}
	var entity := trainer_entity(trainer_id)
	if entity.is_empty():
		return {"handled": true, "success": false, "code": "coop_interaction_unsupported"}
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


func try_wild_step(encounter_type: String) -> Dictionary:
	if OS.has_feature("web") or not AuthService.is_authenticated():
		return {"handled": false}
	if party.is_empty():
		return {"handled": false}
	if not _partner_is_ready_for_coop():
		return {"handled": false, "status": "solo"}
	if encounter_type != "grass":
		var refreshed := await refresh()
		if refreshed.get("success", false) and not _partner_is_ready_for_coop():
			return {"handled": false, "status": "solo"}
		return {"handled": true, "success": false, "code": "coop_wild_method_unsupported"}
	if not activity.is_empty():
		if activity.get("reservationId") == pending_start.get("reservationId"):
			pending_start = {}
		return {"handled": true, "success": true}
	var world := GameState.get_world()
	if world == null:
		return {"handled": true, "success": false, "code": "coop_world_unavailable"}
	var position_result: Dictionary = await world.call("sync_player_position_for_world_action")
	if not position_result.get("success", false):
		return {"handled": true, "success": false, "code": "coop_position_unavailable"}
	if pending_start.is_empty():
		pending_start = {"reservationId": new_id(), "kind": "grass-step"}
	elif pending_start.get("kind") != "grass-step":
		return {"handled": true, "success": false, "code": "coop_start_pending"}
	var result := await _request("grass-step", {"reservationId": pending_start["reservationId"]})
	if result.get("success", false):
		pending_start = {}
	elif int(result.get("status", 0)) in [400, 401, 403, 404, 409, 422]:
		pending_start = {}
	elif result.get("code") == "coop_wild_gameplay_disabled":
		pending_start = {}
	# The regular state poll already keeps membership current. A missed grass
	# step is complete in its own response; fetching state before and after
	# every step held movement input for three network round trips.
	if not result.get("success", false) or result.get("body", {}).get("status") != "miss":
		await refresh()
	if not pending_start.is_empty() and activity.get("reservationId") == pending_start.get("reservationId"):
		pending_start = {}
	if result.get("success", false) and result.get("body", {}).get("status") == "solo":
		return {"handled": false, "success": true, "status": "solo"}
	return {"handled": true, "success": result.get("success", false),
		"code": "" if result.get("success", false) else result.get("code", "coop_start_pending"),
		"status": result.get("body", {}).get("status", "")}


func _partner_is_on_another_map() -> bool:
	var map_ids: Dictionary = party.get("memberMapIds", {})
	var own_id := str(int(AuthService.current_user.get("id", 0)))
	var own_map := str(map_ids.get(own_id, ""))
	if own_map.is_empty():
		return false
	for member_id in party.get("memberIds", []):
		var key := str(int(member_id))
		if key != own_id and not str(map_ids.get(key, "")).is_empty() and str(map_ids[key]) != own_map:
			return true
	return false


func _partner_is_ready_for_coop() -> bool:
	if _partner_is_on_another_map():
		return false
	var online: Dictionary = party.get("memberOnline", {}) if party.get("memberOnline") is Dictionary else {}
	var own_id := str(int(AuthService.current_user.get("id", 0)))
	for member_id: Variant in party.get("memberIds", []):
		var key := str(int(member_id))
		if key != own_id and online.get(key) is bool and not bool(online[key]):
			return false
	return true


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
	var payload := pending_command.duplicate(true)
	var capturing: bool = payload.get("action", {}).get("type") == "capture"
	if capturing:
		payload["itemId"] = payload["action"]["itemId"]
		payload.erase("action")
	var result := await _request("capture" if capturing else "decision", payload)
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


func submit_capture(item_id: String) -> Dictionary:
	var options: Dictionary = view.get("captureOptions", {}) if view.get("captureOptions") is Dictionary else {}
	if view.get("locked", true) or not pending_command.is_empty() or not options.get("storageAvailable", false):
		return {"success": false}
	if not options.get("balls", []).any(func(ball: Dictionary) -> bool: return ball.get("itemId") == item_id and int(ball.get("quantity", 0)) > 0):
		return {"success": false}
	pending_command = {"reservationId": activity["reservationId"], "decisionId": view["decisionId"],
		"idempotencyKey": new_id(), "action": {"type": "capture", "itemId": item_id}}
	state_changed.emit()
	return await retry_command()


func party_action(action: String, payload: Dictionary = {}) -> Dictionary:
	var result := await _request(action, payload)
	if not result.get("success", false):
		request_failed.emit(str(result.get("error", "Co-op request could not be completed.")))
		if action == "invite":
			var reason := str(result.get("code", ""))
			var feedback := "You or that Trainer is busy or in a battle." if reason == "coop_member_busy" else \
				"That Trainer is offline." if reason == "coop_member_offline" else \
				"That Trainer cannot join with their current party." if reason == "coop_party_size_invalid" else \
				"That Trainer name is shared. Use their unique username." if reason == "coop_recipient_name_ambiguous" else \
				"Trainer not found." if reason == "coop_recipient_unavailable" else \
				str(result.get("error", "Invitation could not be sent."))
			invitation_failed.emit(feedback)
	else:
		if action == "invite":
			var receipt: Dictionary = result.get("body", {})
			var invitation_id := str(receipt.get("invitationId", ""))
			if not invitation_id.is_empty() and not _sent_invitations.has(invitation_id):
				_sent_invitations[invitation_id] = true
				invitation_sent.emit(str(receipt.get("recipientUsername", payload.get("recipientName", "Trainer"))))
		if action == "acknowledge":
			# The accepted acknowledgement is enough to release this local battle.
			# Normal polling will refresh invitations without blocking the world return.
			_sequence += 1
			_applied_sequence = _sequence
			activity = {}
			view = {}
			pending_command = {}
			_poll_after = 0.0
			state_changed.emit()
			return result
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
