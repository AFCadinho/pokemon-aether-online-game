extends Node

class_name ModeratorTeleportServiceNode

const TELEPORT_POINTS_ENDPOINT := "/game/moderation/teleport-points"
const TELEPORT_SAFE_POINTS_ENDPOINT := "/game/moderation/teleport-safe-points"
const TELEPORT_SELF_ENDPOINT := "/game/moderation/teleport-self"
const TELEPORT_ONLINE_PLAYERS_ENDPOINT := "/game/moderation/teleport-online-players"
const TELEPORT_TO_PLAYER_ENDPOINT := "/game/moderation/teleport-to-player"
const TELEPORT_PLAYER_ENDPOINT := "/game/moderation/teleport-player"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_teleport_points() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_POINTS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"maps": _array_from_value(body.get("maps", [])),
	}


func load_safe_teleport_points() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_SAFE_POINTS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"maps": _array_from_value(body.get("maps", [])),
	}


func teleport_self(map_id: String, point_id: String, reason: String = "", request_id: String = "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var payload := {
		"requestId": _request_id(request_id),
		"mapId": map_id.strip_edges(),
		"pointId": point_id.strip_edges(),
	}
	var cleaned_reason := reason.strip_edges()
	if cleaned_reason != "":
		payload["reason"] = cleaned_reason

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_SELF_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"state": _dictionary_from_value(body.get("state", {})),
		"commandId": str(body.get("commandId", "")),
		"status": str(body.get("status", "")),
		"idempotent": bool(body.get("idempotent", false)),
	}


func load_online_teleport_players() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_ONLINE_PLAYERS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"players": _array_from_value(body.get("players", [])),
	}


func teleport_to_player(target_player_id: int, reason: String = "", request_id: String = "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var payload := {
		"requestId": _request_id(request_id),
		"targetPlayerId": target_player_id,
	}
	var cleaned_reason := reason.strip_edges()
	if cleaned_reason != "":
		payload["reason"] = cleaned_reason

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_TO_PLAYER_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"state": _dictionary_from_value(body.get("state", {})),
		"commandId": str(body.get("commandId", "")),
		"status": str(body.get("status", "")),
		"idempotent": bool(body.get("idempotent", false)),
	}


func teleport_player(
	target_player_id: int,
	map_id: String,
	point_id: String,
	reason: String = "",
	request_id: String = ""
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var payload := {
		"requestId": _request_id(request_id),
		"targetPlayerId": target_player_id,
		"mapId": map_id.strip_edges(),
		"pointId": point_id.strip_edges(),
	}
	var cleaned_reason := reason.strip_edges()
	if cleaned_reason != "":
		payload["reason"] = cleaned_reason

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TELEPORT_PLAYER_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"state": _dictionary_from_value(body.get("state", {})),
		"commandId": str(body.get("commandId", "")),
		"status": str(body.get("status", "")),
		"idempotent": bool(body.get("idempotent", false)),
	}


func _request_id(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized != "":
		return normalized
	var random_value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [
		random_value.substr(0, 8),
		random_value.substr(8, 4),
		random_value.substr(12, 4),
		random_value.substr(16, 4),
		random_value.substr(20, 12),
	]


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
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
