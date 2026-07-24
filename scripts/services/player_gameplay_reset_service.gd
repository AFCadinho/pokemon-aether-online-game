extends Node

class_name PlayerGameplayResetServiceNode

const RESET_ENDPOINT := "/game/dev/new-game-reset"
const REQUEST_TIMEOUT_SECONDS := 12.0

var pending_request_id := ""


func reset_gameplay() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"status": 401,
			"error": "Not authenticated.",
		}
	if pending_request_id == "":
		pending_request_id = _new_request_id()

	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var base_url: String = await GatewayApiConfig.get_base_url()
	var payload := JSON.stringify({
		"requestId": pending_request_id,
		"confirmation": "RESET",
		"scopeVersion": "gameplay-v1",
	})
	var start_error := request.request(
		base_url + RESET_ENDPOINT,
		GatewayApiConfig.get_json_headers(),
		HTTPClient.METHOD_POST,
		payload
	)
	if start_error != OK:
		request.queue_free()
		return {
			"success": false,
			"status": 0,
			"requestId": pending_request_id,
			"error": "Could not start the gameplay reset request.",
		}

	var completed: Array = await request.request_completed
	request.queue_free()
	var transport_result := int(completed[0])
	var status := int(completed[1])
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	var body: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	if transport_result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		return {
			"success": false,
			"status": status,
			"requestId": pending_request_id,
			"error": _error_message(body, "Gameplay reset failed."),
		}

	var result := body.duplicate(true)
	result["success"] = bool(body.get("success", true))
	result["status"] = status
	pending_request_id = ""
	return result


func abandon_pending_request() -> void:
	pending_request_id = ""


func _new_request_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		push_error("PlayerGameplayResetService: could not generate a UUID.")
		return "00000000-0000-4000-8000-000000000000"
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8),
		value.substr(8, 4),
		value.substr(12, 4),
		value.substr(16, 4),
		value.substr(20, 12),
	]


func _error_message(body: Dictionary, fallback: String) -> String:
	var detail: Variant = body.get("detail", body.get("error", fallback))
	if detail is Dictionary:
		return str((detail as Dictionary).get("message", fallback))
	var message := str(detail).strip_edges()
	return message if message != "" else fallback
