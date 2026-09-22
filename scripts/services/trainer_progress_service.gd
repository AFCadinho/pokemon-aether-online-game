extends Node

class_name TrainerProgressServiceNode

signal progress_invalidated

const TRAINER_PROGRESS_ENDPOINT := "/game/trainers/%s/progress"
const TRAINER_REMATCH_ENDPOINT := "/game/trainers/%s/rematch"
const DEVELOPER_REMATCH_MODE_ENDPOINT := "/game/dev/progression/trainer-rematch-mode"
const DEVELOPER_LEVEL_CAP_OVERRIDE_ENDPOINT := "/game/dev/progression/pokemon-level-cap-override"
const REQUEST_TIMEOUT_SECONDS := 5.0


func get_progress(trainer_id: String) -> Dictionary:
	return await _request_progress(trainer_id, false)


func begin_rematch(trainer_id: String) -> Dictionary:
	return await _request_progress(trainer_id, true)


func invalidate_all() -> void:
	progress_invalidated.emit()


func get_developer_rematch_mode() -> Dictionary:
	return await _request_developer_rematch_mode(HTTPClient.METHOD_GET, "")


func set_developer_rematch_mode(enabled: bool) -> Dictionary:
	return await _request_developer_rematch_mode(
		HTTPClient.METHOD_PUT,
		JSON.stringify({"enabled": enabled})
	)


func get_developer_level_cap_override() -> Dictionary:
	return await _request_developer_level_cap_override(HTTPClient.METHOD_GET, "")


func set_developer_level_cap_override(enabled: bool) -> Dictionary:
	return await _request_developer_level_cap_override(
		HTTPClient.METHOD_PUT,
		JSON.stringify({"enabled": enabled})
	)


func _request_developer_level_cap_override(method: HTTPClient.Method, body: String) -> Dictionary:
	return await _request_developer_setting(
		DEVELOPER_LEVEL_CAP_OVERRIDE_ENDPOINT,
		method,
		body,
		"Developer level-cap override"
	)


func _request_developer_rematch_mode(method: HTTPClient.Method, body: String) -> Dictionary:
	return await _request_developer_setting(
		DEVELOPER_REMATCH_MODE_ENDPOINT,
		method,
		body,
		"Developer rematch mode"
	)


func _request_developer_setting(endpoint: String, method: HTTPClient.Method, body: String, label: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(
		base_url + endpoint,
		GatewayApiConfig.get_json_headers(),
		method,
		body
	)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "%s request failed to start: %s" % [label, error_string(error)],
		}

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
		}
	var parsed: Variant = JSON.parse_string(response_text) if not response_text.is_empty() else null
	if response_code < 200 or response_code >= 300:
		var message := "%s request failed with status %s" % [label, response_code]
		if parsed is Dictionary:
			message = str((parsed as Dictionary).get("detail", message))
		return {
			"success": false,
			"status": response_code,
			"error": message,
		}
	if not parsed is Dictionary:
		return {
			"success": false,
			"status": response_code,
			"error": "%s response was not valid JSON." % label,
		}
	return {
		"success": true,
		"enabled": bool((parsed as Dictionary).get("enabled", false)),
	}


func _request_progress(trainer_id: String, begin_daily_rematch: bool) -> Dictionary:
	var normalized_id := trainer_id.strip_edges()
	if normalized_id.is_empty():
		return {
			"success": false,
			"error": "Missing trainer id.",
		}
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	# Trainer NPCs request their progress while a map is still assembling. Wait
	# until the initial render work has crossed two frame boundaries so the
	# HTTPRequest timeout does not expire during a blocked loading frame.
	await GatewayApiConfig.wait_for_metadata_request_frame()
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var url := base_url + TRAINER_PROGRESS_ENDPOINT % normalized_id.uri_encode()
	var method := HTTPClient.METHOD_GET
	var headers := GatewayApiConfig.get_accept_headers()
	if begin_daily_rematch:
		url = base_url + TRAINER_REMATCH_ENDPOINT % normalized_id.uri_encode()
		method = HTTPClient.METHOD_POST
		headers = GatewayApiConfig.get_json_headers()
	var error := request.request(WebRuntime.gameplay_url(url), headers, method, "{}" if begin_daily_rematch else "")
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Trainer progress request failed to start: %s" % error_string(error),
		}

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
		}
	var parsed: Variant = JSON.parse_string(response_text) if not response_text.is_empty() else null
	if response_code < 200 or response_code >= 300:
		var message := "Trainer progress request failed with status %s" % response_code
		if parsed is Dictionary:
			message = str((parsed as Dictionary).get("detail", message))
		return {
			"success": false,
			"status": response_code,
			"error": message,
		}
	if not parsed is Dictionary:
		return {
			"success": false,
			"status": response_code,
			"error": "Trainer progress response was not valid JSON.",
		}
	return {
		"success": true,
		"progress": (parsed as Dictionary).duplicate(true),
	}
