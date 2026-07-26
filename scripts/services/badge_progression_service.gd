extends Node

class_name BadgeProgressionServiceNode

const BADGES_ENDPOINT := "/game/progression/gym-badges"
const DEV_BADGES_ENDPOINT := "/game/dev/progression/gym-badges"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_gym_badges() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + BADGES_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	var result := _badge_result_from_response(response)
	if bool(result.get("success", false)):
		PlayerSave.apply_gym_badge_state(result)
	return result


func dev_set_gym_badges(region: String, badge_ids: Array[String], earned: bool) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if badge_ids.is_empty():
		return {"success": false, "error": "Choose at least one Gym Badge."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_BADGES_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"region": region.strip_edges().to_lower(),
			"badgeIds": badge_ids,
			"earned": earned,
		})
	)
	var result := _badge_result_from_response(response)
	if bool(result.get("success", false)):
		PlayerSave.apply_gym_badge_state(result)
	return result


func _badge_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"badges": _array_from_value(body.get("badges", [])),
		"earnedCount": max(int(body.get("earnedCount", 0)), 0),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = parsed_body if typeof(parsed_body) == TYPE_DICTIONARY else {}
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}
	return {"success": true, "status": response_code, "body": body_dictionary}


func _extract_error(body: Dictionary, response_code: int) -> String:
	if body.has("detail"):
		return str(body.get("detail"))
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array_from_value(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


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
