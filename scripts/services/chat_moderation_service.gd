extends Node

class_name ChatModerationServiceNode

const MUTES_ENDPOINT := "/game/chat/mutes"
const OVERVIEW_ENDPOINT := "/game/chat/moderation/overview"
const REQUEST_TIMEOUT_SECONDS := 8.0


func get_mute_state(target_user_id: int) -> Dictionary:
	if target_user_id <= 0:
		return _validation_error("Invalid player.")
	return await _request(
		MUTES_ENDPOINT + "/%s" % target_user_id,
		HTTPClient.METHOD_GET,
		""
	)


func get_moderation_overview() -> Dictionary:
	return await _request(OVERVIEW_ENDPOINT, HTTPClient.METHOD_GET, "")


func mute_player(target_user_id: int, duration_minutes: int, reason: String) -> Dictionary:
	var normalized_reason := reason.strip_edges()
	if target_user_id <= 0:
		return _validation_error("Invalid player.")
	if duration_minutes <= 0:
		return _validation_error("Choose a mute duration.")
	if normalized_reason.length() < 3:
		return _validation_error("Enter a reason of at least 3 characters.")
	return await _request(
		MUTES_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"targetUserId": target_user_id,
			"durationMinutes": duration_minutes,
			"reason": normalized_reason,
		})
	)


func unmute_player(target_user_id: int, reason: String) -> Dictionary:
	var normalized_reason := reason.strip_edges()
	if target_user_id <= 0:
		return _validation_error("Invalid player.")
	if normalized_reason.length() < 3:
		return _validation_error("Enter a reason of at least 3 characters.")
	return await _request(
		MUTES_ENDPOINT + "/%s?reason=%s" % [target_user_id, normalized_reason.uri_encode()],
		HTTPClient.METHOD_DELETE,
		""
	)


func _request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers := (
		GatewayApiConfig.get_json_headers()
		if method == HTTPClient.METHOD_POST
		else GatewayApiConfig.get_accept_headers()
	)
	var error := request.request(base_url + path, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var response_code := int(result[1])
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var response_body: Dictionary = parsed if parsed is Dictionary else {}
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": "The moderation request failed."}
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.message({"body": response_body, "status": response_code}),
		}
	return {"success": true, "body": response_body}


func _validation_error(message: String) -> Dictionary:
	return {"success": false, "error": message}
