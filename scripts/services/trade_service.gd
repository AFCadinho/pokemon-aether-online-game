extends Node

class_name TradeServiceNode

const CAPABILITIES_ENDPOINT := "/game/trades/capabilities"
const ACTIVE_TRADE_ENDPOINT := "/game/trades/active"
const REQUEST_TIMEOUT_SECONDS := 8.0

var capabilities: Dictionary = {}


func load_capabilities(force_refresh := false) -> Dictionary:
	if not force_refresh and not capabilities.is_empty():
		return {
			"success": true,
			"capabilities": capabilities.duplicate(true),
		}
	if not _is_authenticated():
		return _auth_error()

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(
		base_url + CAPABILITIES_ENDPOINT,
		HTTPClient.METHOD_GET,
		gateway.call("get_accept_headers"),
		""
	)
	if not bool(response.get("success", false)):
		return response

	capabilities = normalize_capabilities(response.get("body", {}))
	return {
		"success": true,
		"capabilities": capabilities.duplicate(true),
	}


func clear_capabilities() -> void:
	capabilities.clear()


func load_active_trade() -> Dictionary:
	return await _load_trade_resource(ACTIVE_TRADE_ENDPOINT, true)


func load_trade(trade_id: String) -> Dictionary:
	var normalized_id := trade_id.strip_edges()
	if normalized_id == "":
		return _validation_error("Trade id is required.")
	return await _load_trade_resource("/game/trades/%s" % normalized_id.uri_encode(), false)


func load_trade_events(trade_id: String, after_seq := 0, limit := 50) -> Dictionary:
	var normalized_id := trade_id.strip_edges()
	if normalized_id == "":
		return _validation_error("Trade id is required.")
	var normalized_after := maxi(after_seq, 0)
	var normalized_limit := clampi(limit, 1, 100)
	return await _load_trade_resource("/game/trades/%s/events?afterSeq=%d&limit=%d" % [normalized_id.uri_encode(), normalized_after, normalized_limit], false, true)


func create_invitation(target_username: String, request_id := "") -> Dictionary:
	var username := target_username.strip_edges()
	if username == "":
		return _validation_error("Username is required.")
	return await _trade_command("", {"targetUsername": username, "requestId": _request_id(request_id)})


func accept_invitation(trade_id: String, expected_revision: int, request_id := "") -> Dictionary:
	return await _invitation_transition(trade_id, "accept", expected_revision, request_id)


func decline_invitation(trade_id: String, expected_revision: int, request_id := "") -> Dictionary:
	return await _invitation_transition(trade_id, "decline", expected_revision, request_id)


func cancel_invitation(trade_id: String, expected_revision: int, request_id := "") -> Dictionary:
	return await _invitation_transition(trade_id, "cancel", expected_revision, request_id)


func load_trade_request_preference() -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(base_url + "/game/trades/preferences/requests", HTTPClient.METHOD_GET, gateway.call("get_accept_headers"), "")
	return response if not bool(response.get("success", false)) else {"success": true, "preference": str(_dictionary_from_value(response.get("body", {})).get("preference", "everyone"))}


func set_trade_request_preference(preference: String) -> Dictionary:
	var normalized := preference.strip_edges().to_lower()
	if normalized not in ["everyone", "friends", "off"]:
		return _validation_error("Invalid trade request preference.")
	return await _trade_command("/preferences/requests", {"preference": normalized}, HTTPClient.METHOD_PUT, false)


func _invitation_transition(trade_id: String, action: String, expected_revision: int, request_id: String) -> Dictionary:
	var normalized_id := trade_id.strip_edges()
	if normalized_id == "":
		return _validation_error("Trade id is required.")
	return await _trade_command("/%s/%s" % [normalized_id.uri_encode(), action], {"requestId": _request_id(request_id), "expectedRevision": maxi(expected_revision, 0)})


func _trade_command(path: String, payload: Dictionary, method := HTTPClient.METHOD_POST, normalize_trade := true) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(base_url + "/game/trades" + path, method, gateway.call("get_json_headers"), JSON.stringify(payload))
	if not bool(response.get("success", false)):
		return response
	return {"success": true, "trade": normalize_trade_snapshot(response.get("body", {}))} if normalize_trade else {"success": true, "body": _dictionary_from_value(response.get("body", {}))}


func _request_id(value: String) -> String:
	var normalized := value.strip_edges()
	return normalized if normalized != "" else str(Time.get_unix_time_from_system()) + "-" + str(randi())


func _load_trade_resource(path: String, active := false, events := false) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")
	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(base_url + path, HTTPClient.METHOD_GET, gateway.call("get_accept_headers"), "")
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	if active:
		var trade_value: Variant = body.get("trade", null)
		return {"success": true, "hasActiveTrade": trade_value is Dictionary, "trade": normalize_trade_snapshot(trade_value) if trade_value is Dictionary else {}}
	return {"success": true, "events": normalize_trade_events(body)} if events else {"success": true, "trade": normalize_trade_snapshot(body)}


func normalize_trade_snapshot(value: Variant) -> Dictionary:
	var source := _dictionary_from_value(value)
	var participants_value: Variant = source.get("participants", [])
	var participants: Array = participants_value if participants_value is Array else []
	return {
		"tradeId": str(source.get("tradeId", "")).strip_edges(),
		"status": str(source.get("status", "")).strip_edges(),
		"revision": maxi(int(source.get("revision", 0)), 0),
		"lastEventSeq": maxi(int(source.get("lastEventSeq", 0)), 0),
		"participants": participants.duplicate(true),
		"createdAt": str(source.get("createdAt", "")),
		"updatedAt": str(source.get("updatedAt", "")),
		"expiresAt": str(source.get("expiresAt", "")),
		"terminalAt": str(source.get("terminalAt", "")),
	}


func normalize_trade_events(value: Variant) -> Dictionary:
	var source := _dictionary_from_value(value)
	var events_value: Variant = source.get("events", [])
	var events: Array = events_value if events_value is Array else []
	return {
		"tradeId": str(source.get("tradeId", "")).strip_edges(),
		"revision": maxi(int(source.get("revision", 0)), 0),
		"lastEventSeq": maxi(int(source.get("lastEventSeq", 0)), 0),
		"afterSeq": maxi(int(source.get("afterSeq", 0)), 0),
		"limit": clampi(int(source.get("limit", 50)), 1, 100),
		"events": events.duplicate(true),
	}


func normalize_capabilities(value: Variant) -> Dictionary:
	var source := _dictionary_from_value(value)
	return {
		"enabled": bool(source.get("enabled", false)),
		"maxPokemonPerSide": clampi(int(source.get("maxPokemonPerSide", 5)), 1, 5),
		"allowHeldItems": bool(source.get("allowHeldItems", false)),
		"requiresSameMap": bool(source.get("requiresSameMap", true)),
		"inviteExpiresInSeconds": maxi(int(source.get("inviteExpiresInSeconds", 30)), 1),
		"reconnectGraceSeconds": maxi(int(source.get("reconnectGraceSeconds", 30)), 1),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _extract_error(body: Dictionary, response_code: int) -> String:
	if body.has("detail"):
		var detail: Variant = body.get("detail")
		if typeof(detail) == TYPE_DICTIONARY:
			var detail_dictionary: Dictionary = detail
			return str(detail_dictionary.get("message", detail_dictionary.get("code", "Request failed.")))
		return str(detail)
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


func _auth_error() -> Dictionary:
	return {
		"success": false,
		"error": "Not authenticated.",
	}


func _validation_error(message: String) -> Dictionary:
	return {
		"success": false,
		"error": message,
	}


func _is_authenticated() -> bool:
	if not is_inside_tree():
		return false
	var auth_service := get_node_or_null("/root/AuthService")
	return auth_service != null and auth_service.has_method("is_authenticated") and bool(auth_service.call("is_authenticated"))


func _gateway_api_config() -> Object:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GatewayApiConfig")


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Server connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Server TLS error."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		_:
			return "Request failed: %s." % result
