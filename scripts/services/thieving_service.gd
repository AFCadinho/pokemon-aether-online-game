extends Node

class_name ThievingServiceNode

signal state_changed(state: Dictionary)
signal arrested(arrest: Dictionary)

const THIEVING_ENDPOINT := "/game/thieving"
const PICKPOCKET_ENDPOINT := "/game/thieving/pickpocket"
const PUBLIC_SERVICE_ENDPOINT := "/game/thieving/public-service"
const JAIL_RELEASE_ENDPOINT := "/game/thieving/jail/release"
const JAIL_DETAINEES_ENDPOINT := "/game/thieving/jail/detainees"
const JAIL_BAIL_ENDPOINT := "/game/thieving/jail/bail"
const REQUEST_TIMEOUT_SECONDS := 8.0

var state: Dictionary = {}
var state_loaded := false
var jail_release_generation := 0
var was_authenticated := false


func _ready() -> void:
	set_process(true)
	if not ChatRealtimeService.message_received.is_connected(_on_realtime_message_received):
		ChatRealtimeService.message_received.connect(_on_realtime_message_received)


func _process(_delta: float) -> void:
	var authenticated := AuthService.is_authenticated()
	if authenticated and not was_authenticated:
		load_state.call_deferred()
	elif not authenticated and was_authenticated:
		state.clear()
		state_loaded = false
		jail_release_generation += 1
		state_changed.emit({})
	was_authenticated = authenticated


func load_state() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var response := await _request_json(THIEVING_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	_apply_state(_dictionary_from_value(response.get("body", {})))
	return {"success": true, "state": state.duplicate(true)}


func attempt_pickpocket(npc_id: String) -> Dictionary:
	var normalized_npc_id := npc_id.strip_edges().to_lower()
	if normalized_npc_id == "":
		return {"success": false, "error": "Missing NPC id."}
	var response := await _request_json(
		PICKPOCKET_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"npcId": normalized_npc_id,
			"requestId": _new_request_id(),
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	_apply_state(_dictionary_from_value(body.get("state", {})))
	var reward_item := _dictionary_from_value(body.get("rewardItem", {}))
	await _refresh_wallet()
	if not reward_item.is_empty():
		await InventoryService.load_inventory()
	var arrest := _dictionary_from_value(body.get("arrest", {}))
	if not arrest.is_empty():
		_apply_arrest(arrest)
	return {
		"success": true,
		"outcome": str(body.get("outcome", "")),
		"npcId": str(body.get("npcId", normalized_npc_id)),
		"npcType": str(body.get("npcType", "civilian")),
		"rewardMoney": max(int(body.get("rewardMoney", 0)), 0),
		"rewardItem": reward_item,
		"experienceAwarded": max(int(body.get("experienceAwarded", 0)), 0),
		"catchChance": clampf(float(body.get("catchChance", 0.0)), 0.0, 1.0),
		"arrest": arrest,
		"state": state.duplicate(true),
	}


func use_public_service(service_type: String) -> Dictionary:
	if not state_loaded:
		var load_result := await load_state()
		if not bool(load_result.get("success", false)):
			return load_result
	if int(state.get("wanted", 0)) < 100:
		return {"success": true, "allowed": true, "state": state.duplicate(true)}
	var response := await _request_json(
		PUBLIC_SERVICE_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({"serviceType": service_type})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	_apply_state(_dictionary_from_value(body.get("state", {})))
	await _refresh_wallet()
	var arrest := _dictionary_from_value(body.get("arrest", {}))
	if not arrest.is_empty():
		_apply_arrest(arrest)
	return {
		"success": true,
		"allowed": bool(body.get("allowed", false)),
		"arrest": arrest,
		"state": state.duplicate(true),
	}


func is_npc_attempted_today(npc_id: String) -> bool:
	var attempted_value: Variant = state.get("attemptedNpcIds", [])
	return attempted_value is Array and npc_id.strip_edges().to_lower() in attempted_value


func get_level() -> int:
	return max(int(state.get("level", 1)), 1)


func is_unlocked() -> bool:
	return bool(state.get("unlocked", false))


func is_most_wanted() -> bool:
	return int(state.get("wanted", 0)) >= 100


func load_bailable_detainees() -> Dictionary:
	var response := await _request_json(JAIL_DETAINEES_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	return {"success": true, "detainees": _array_from_value(body.get("detainees", []))}


func pay_bail(target_player_id: int) -> Dictionary:
	var response := await _request_json(
		JAIL_BAIL_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"targetPlayerId": target_player_id,
			"requestId": _new_uuid(),
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var next_state := _dictionary_from_value(body.get("state", {}))
	if not next_state.is_empty():
		_apply_state(next_state)
	PlayerSave.money = maxi(int(body.get("payerMoney", PlayerSave.money)), 0)
	return {
		"success": true,
		"targetPlayerId": int(body.get("targetPlayerId", target_player_id)),
		"targetDisplayName": str(body.get("targetDisplayName", "")),
		"paidAmount": maxi(int(body.get("paidAmount", 0)), 0),
		"payerMoney": maxi(int(body.get("payerMoney", 0)), 0),
	}


func _apply_state(next_state: Dictionary) -> void:
	state = next_state.duplicate(true)
	state_loaded = true
	state_changed.emit(state.duplicate(true))
	if bool(state.get("jailed", false)) and not bool(state.get("jailPermanent", false)):
		_schedule_jail_release(max(int(state.get("jailRemainingSeconds", 0)), 0))
	elif bool(state.get("releaseAvailable", false)):
		_schedule_jail_release(0)
	else:
		# Cancel a timer from an earlier theft sentence when bail or a permanent
		# staff detention replaces that state.
		jail_release_generation += 1


func _apply_arrest(arrest: Dictionary) -> void:
	arrested.emit(arrest.duplicate(true))
	var lost_money: int = maxi(int(arrest.get("lostMoney", 0)), 0)
	_add_system_message(LocalizationManager.text(
		"ui.thieving.arrested",
		{"amount": lost_money}
	), true)
	_teleport_to_destination(_dictionary_from_value(arrest.get("destination", {})))
	_schedule_jail_release(max(int(arrest.get("sentenceSeconds", 0)), 0))


func _refresh_wallet() -> bool:
	var result: Dictionary = await PlayerWalletService.load_wallet()
	if not bool(result.get("success", false)):
		return false
	PlayerWalletService.apply_wallet_result(result)
	get_tree().call_group("ui_overlay", "refresh_money_display")
	return true


func _schedule_jail_release(seconds: int) -> void:
	jail_release_generation += 1
	var generation := jail_release_generation
	_release_after_sentence(generation, seconds)


func _release_after_sentence(generation: int, seconds: int) -> void:
	if seconds > 0:
		await get_tree().create_timer(float(seconds)).timeout
	if generation != jail_release_generation:
		return
	var response := await _request_json(JAIL_RELEASE_ENDPOINT, HTTPClient.METHOD_POST, "")
	if generation != jail_release_generation or not bool(response.get("success", false)):
		return
	var body := _dictionary_from_value(response.get("body", {}))
	_apply_state(_dictionary_from_value(body.get("state", {})))
	_teleport_to_destination(_dictionary_from_value(body.get("destination", {})))
	_add_system_message(LocalizationManager.text("ui.thieving.released"))


func _teleport_to_destination(destination: Dictionary) -> void:
	var scene_path := str(destination.get("mapScenePath", "")).strip_edges()
	var spawn_marker := str(destination.get("spawnMarker", "")).strip_edges()
	if scene_path == "" or spawn_marker == "":
		return
	var world := GameState.get_world()
	if world != null and world.has_method("load_map"):
		world.call_deferred("load_map", scene_path, spawn_marker)


func _request_json(endpoint: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var headers := GatewayApiConfig.get_accept_headers()
	if body != "":
		headers = GatewayApiConfig.get_json_headers()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(base_url + endpoint, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary_from_value(parsed)
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": "Network request failed.", "body": response_body}
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(response_body, response_code),
			"body": response_body,
		}
	return {"success": true, "status": response_code, "body": response_body}


func _extract_error(body: Dictionary, status: int) -> String:
	var detail: Variant = body.get("detail", body.get("message", body.get("error", "")))
	if detail is Dictionary:
		return str((detail as Dictionary).get("message", (detail as Dictionary).get("code", "Request failed.")))
	var message := str(detail).strip_edges()
	return message if message != "" else "Request failed with status %d." % status


func _add_system_message(message: String, warning := false) -> void:
	var method := "add_system_warning" if warning else "add_system_message"
	get_tree().call_group("ui_overlay", method, message)


func _new_request_id() -> String:
	return "%s-%s-%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]


func _new_uuid() -> String:
	var random_value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [
		random_value.substr(0, 8),
		random_value.substr(8, 4),
		random_value.substr(12, 4),
		random_value.substr(16, 4),
		random_value.substr(20, 12),
	]


func _on_realtime_message_received(message: Dictionary) -> void:
	if str(message.get("type", "")).strip_edges().to_lower() == "jail.state.changed":
		load_state.call_deferred()


func _array_from_value(value: Variant) -> Array:
	return value as Array if value is Array else []


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
