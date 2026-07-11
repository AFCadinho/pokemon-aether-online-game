extends Node

class_name PlayerActionServiceNode

signal statuses_changed(actions: Array)

const ACTIONS_ENDPOINT := "/game/player-actions"
const EXECUTE_ENDPOINT := "/game/player-actions/%s/execute"
const REQUEST_TIMEOUT_SECONDS := 8.0

var cached_actions: Array = []
var pending_request_ids: Dictionary = {}


func load_statuses() -> Dictionary:
	var response := await _request_json(ACTIONS_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary(response.get("body", {}))
	cached_actions = _array(body.get("actions", []))
	statuses_changed.emit(cached_actions)
	return {"success": true, "actions": cached_actions, "serverTime": str(body.get("serverTime", ""))}


func execute(action_id: String, retry: bool = false) -> Dictionary:
	var normalized := action_id.strip_edges().to_lower()
	if normalized == "":
		return {"success": false, "error": "Missing action ID."}
	var request_id := str(pending_request_ids.get(normalized, "")) if retry else ""
	if request_id == "":
		request_id = _new_request_id()
		pending_request_ids[normalized] = request_id
	var response := await _request_json(EXECUTE_ENDPOINT % normalized.uri_encode(), HTTPClient.METHOD_POST,
		JSON.stringify({"requestId": request_id, "parameters": {}}))
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary(response.get("body", {}))
	if bool(body.get("accepted", false)):
		pending_request_ids.erase(normalized)
	await load_statuses()
	return {"success": true, "result": body, "requestId": request_id}


func clear_pending_request(action_id: String) -> void:
	pending_request_ids.erase(action_id.strip_edges().to_lower())


static func format_remaining(seconds: int) -> String:
	var safe: int = max(seconds, 0)
	return "%02d:%02d" % [safe / 60, safe % 60]


func _new_request_id() -> String:
	return "%s-%s" % [Time.get_unix_time_from_system(), randi()]


func _request_json(endpoint: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers: PackedStringArray = GatewayApiConfig.get_accept_headers() if method == HTTPClient.METHOD_GET else GatewayApiConfig.get_json_headers()
	var error: Error = request.request(base_url + endpoint, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var completed: Array = await request.request_completed
	request.queue_free()
	var response_code: int = int(completed[1])
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	var parsed_body: Dictionary = _dictionary(parsed)
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var detail: Variant = parsed_body.get("detail", {})
		var message: String = str((detail as Dictionary).get("message", "Request failed.")) if detail is Dictionary else str(detail)
		return {"success": false, "status": response_code, "error": message}
	return {"success": true, "body": parsed_body}


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
