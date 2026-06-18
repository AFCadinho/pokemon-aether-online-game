extends Node

class_name PlayerPartyStateServiceNode

const PLAYER_PARTY_ENDPOINT := "/game/party"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_party() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
	}


func save_party(party_state: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(party_state)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
	}


func save_current_party() -> Dictionary:
	return await save_party(PlayerSave.to_party_state())


func save_current_party_deferred() -> void:
	var result: Dictionary = await save_current_party()
	if not bool(result.get("success", false)):
		push_warning("PlayerPartyStateService: party save failed: %s" % str(result.get("error", "Unknown error")))


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


func _request_result_message(request_result: int) -> String:
	match request_result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Could not resolve server."
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Could not connect to server."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		_:
			return "Request failed."
