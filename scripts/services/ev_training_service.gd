extends Node

class_name EvTrainingServiceNode

const SESSION_ENDPOINT := "/game/ev-training/session"
const END_SESSION_ENDPOINT := "/game/ev-training/session/end"
const FOCUS_ENDPOINT := "/game/ev-training/tutorial/focus"
const TUTORIAL_SESSION_ENDPOINT := "/game/ev-training/tutorial/session"
const REQUEST_TIMEOUT_SECONDS := 5.0


func get_session() -> Dictionary:
	return await _request_json(SESSION_ENDPOINT, HTTPClient.METHOD_GET, "")


func start_session(stat: String, tier: int = 1) -> Dictionary:
	return await _request_json(
		SESSION_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"stat": stat.strip_edges().to_lower(),
			"tier": clampi(tier, 1, 3),
			"requestId": _new_request_id(),
		})
	)


func select_focus_pokemon(pokemon_id: int) -> Dictionary:
	return await _request_json(
		FOCUS_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"pokemonId": pokemon_id,
			"requestId": _new_request_id(),
		})
	)


func start_tutorial_session() -> Dictionary:
	return await _request_json(TUTORIAL_SESSION_ENDPOINT, HTTPClient.METHOD_POST, "{}")


func end_session() -> Dictionary:
	return await _request_json(END_SESSION_ENDPOINT, HTTPClient.METHOD_POST, "{}")


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
		return {"success": false, "error": "Could not start EV training request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var status := int(result[1])
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var response_body := parsed as Dictionary if parsed is Dictionary else {}
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": status, "error": "Network request failed.", "body": response_body}
	if status < 200 or status >= 300:
		return {
			"success": false,
			"status": status,
			"error": _extract_error(response_body, status),
			"body": response_body,
		}
	_apply_wallet(response_body)
	var story := _dictionary(response_body.get("story", {}))
	if not story.is_empty():
		StoryService.apply_story_if_not_stale(story)
	return {
		"success": true,
		"status": status,
		"session": _dictionary(response_body.get("session", {})),
		"wallet": _dictionary(response_body.get("wallet", {})),
		"tutorial": _dictionary(response_body.get("tutorial", {})),
		"story": story,
	}


func _apply_wallet(body: Dictionary) -> void:
	var wallet := _dictionary(body.get("wallet", {}))
	if not wallet.is_empty():
		PlayerSave.money = maxi(int(wallet.get("money", PlayerSave.money)), 0)


func _extract_error(body: Dictionary, status: int) -> String:
	var detail: Variant = body.get("detail", body.get("message", body.get("error", "")))
	if detail is Dictionary:
		return str((detail as Dictionary).get("message", (detail as Dictionary).get("code", "Request failed.")))
	var message := str(detail).strip_edges()
	return message if not message.is_empty() else "Request failed with status %d." % status


func _new_request_id() -> String:
	return "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
