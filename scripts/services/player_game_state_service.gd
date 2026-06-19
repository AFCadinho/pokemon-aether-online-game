extends Node

class_name PlayerGameStateServiceNode

const PLAYER_POSITION_ENDPOINT := "/game/player-position"
const MAP_PLAYERS_ENDPOINT := "/game/map-players"
const PLAYER_PREFERENCES_ENDPOINT := "/game/preferences"
const PLAYER_PROFILE_ENDPOINT := "/game/profile"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_player_profile() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PROFILE_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var position: Dictionary = _dictionary_from_value(body.get("position", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	var preferences: Dictionary = _dictionary_from_value(body.get("preferences", {}))
	return {
		"success": true,
		"user": _dictionary_from_value(body.get("user", {})),
		"position": {
			"hasState": bool(position.get("hasState", false)),
			"state": _dictionary_from_value(position.get("state", {})),
		},
		"party": {
			"hasParty": bool(party.get("hasParty", false)),
			"party": _array_from_value(party.get("party", [])),
		},
		"preferences": _dictionary_from_value(preferences.get("preferences", {})),
	}


func load_player_position() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_POSITION_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func save_player_position(state: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_POSITION_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(state)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func load_map_players() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAP_PLAYERS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var players_value: Variant = body.get("players", [])
	var players: Array = players_value if players_value is Array else []
	return {
		"success": true,
		"players": players,
	}


func load_player_preferences() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PREFERENCES_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"preferences": _dictionary_from_value(body.get("preferences", {})),
	}


func save_player_preferences(preferences: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PREFERENCES_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(preferences)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"preferences": _dictionary_from_value(body.get("preferences", {})),
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
		return str(body.get("detail"))
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


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
