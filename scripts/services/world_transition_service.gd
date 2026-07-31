extends Node

class_name WorldTransitionServiceNode

const TRANSITION_ACCESS_ENDPOINT := "/game/world/transitions/%s/access"
const TRANSITION_ENTER_ENDPOINT := "/game/world/transitions/%s/enter"
const REQUEST_TIMEOUT_SECONDS := 8.0

var transition_access_cache: Dictionary = {}


func get_transition_access(transition_id: String, force_refresh := false) -> Dictionary:
	var normalized_transition_id := transition_id.strip_edges()
	if normalized_transition_id.is_empty():
		return {"success": false, "error": "Missing transition_id."}
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if not force_refresh and transition_access_cache.has(normalized_transition_id):
		return {
			"success": true,
			"access": transition_access_cache[normalized_transition_id],
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response := await _request_json(
		base_url + (TRANSITION_ACCESS_ENDPOINT % normalized_transition_id.uri_encode()),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var access := _dictionary_from_value(response.get("body", {}))
	if access.is_empty():
		return {"success": false, "error": "Transition access response was empty."}
	transition_access_cache[normalized_transition_id] = access
	return {"success": true, "access": access}


func enter_transition(transition_id: String) -> Dictionary:
	var normalized_transition_id := transition_id.strip_edges()
	if normalized_transition_id.is_empty():
		return {"success": false, "error": "Missing transition_id."}
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response := await _request_json(
		base_url + (TRANSITION_ENTER_ENDPOINT % normalized_transition_id.uri_encode()),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		"{}"
	)
	if not bool(response.get("success", false)):
		return response

	var body := _dictionary_from_value(response.get("body", {}))
	var access := _dictionary_from_value(body.get("access", {}))
	if not access.is_empty():
		transition_access_cache[normalized_transition_id] = access
	return {
		"success": true,
		"allowed": bool(body.get("allowed", false)),
		"transitionId": str(body.get("transitionId", normalized_transition_id)),
		"access": access,
		"state": _dictionary_from_value(body.get("state", {})),
	}


func clear_cache() -> void:
	transition_access_cache.clear()


func _request_json(
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
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
			"error": BackendErrorLocalizationService.transport_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = parsed_body if typeof(parsed_body) == TYPE_DICTIONARY else {}
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.message({
				"body": body_dictionary,
				"status": response_code,
			}),
			"body": body_dictionary,
			"raw": response_text,
		}
	return {"success": true, "status": response_code, "body": body_dictionary}


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
