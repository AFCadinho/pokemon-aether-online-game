extends RefCounted

const DEFAULT_STATUS_URL := "https://admin.pokeaether.com/auth/status"
const REQUEST_TIMEOUT_SECONDS := 8.0
const USER_AGENT_HEADER := "User-Agent: PokeAetherLauncher/1.0"


static func check_async(parent: Node, status_url: String = DEFAULT_STATUS_URL) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	parent.add_child(request)

	var error: Error = request.request(
		status_url,
		[USER_AGENT_HEADER],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		request.queue_free()
		return {
			"online": false,
			"error": "Could not start server status request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var body: PackedByteArray = result[3]

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"online": false,
			"status": response_code,
			"error": _request_result_message(request_result),
		}

	if response_code < 200 or response_code >= 300:
		return {
			"online": false,
			"status": response_code,
			"error": "Server status returned HTTP %s." % response_code,
		}

	var parsed_body: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed_body) != TYPE_DICTIONARY:
		return {
			"online": false,
			"status": response_code,
			"error": "Server status response is invalid.",
		}

	var response: Dictionary = parsed_body
	var status_result := parse_status_response(response)
	if not bool(status_result.get("valid", false)):
		return {
			"online": false,
			"status": response_code,
			"error": "Server status response is invalid.",
		}
	status_result["status"] = response_code
	return status_result


static func parse_status_response(response: Dictionary) -> Dictionary:
	if response.has("available"):
		var mode := str(response.get("mode", "")).strip_edges().to_lower()
		if typeof(response.get("available")) != TYPE_BOOL or not mode in ["open", "draining", "closed"]:
			return {"valid": false, "online": false}
		var available := bool(response.get("available", false))
		if available != (mode == "open"):
			return {"valid": false, "online": false}
		return {
			"valid": true,
			"online": available,
			"reachable": true,
			"maintenance": not available,
			"server_status": mode,
			"message": str(response.get("message", "")).strip_edges(),
			"disconnect_at": str(response.get("disconnectAt", "")).strip_edges(),
		}

	# Keep accepting the old infrastructure-health shape for local overrides.
	var status_text := str(response.get("status", "")).strip_edges().to_lower()
	if status_text not in ["online", "ok", "degraded"]:
		return {"valid": false, "online": false}
	return {
		"valid": true,
		"online": status_text in ["online", "ok"],
		"reachable": true,
		"maintenance": false,
		"server_status": status_text,
		"message": "",
	}


static func request_presence_async(parent: Node, presence_url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	parent.add_child(request)

	var error: Error = request.request(
		presence_url,
		[USER_AGENT_HEADER],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"onlineUsers": 0,
			"error": "Could not start presence request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var body: PackedByteArray = result[3]

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"onlineUsers": 0,
			"status": response_code,
			"error": _request_result_message(request_result),
		}

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"onlineUsers": 0,
			"status": response_code,
			"error": "Presence request returned HTTP %s." % response_code,
		}

	var parsed_body: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed_body) != TYPE_DICTIONARY:
		return {
			"success": false,
			"onlineUsers": 0,
			"status": response_code,
			"error": "Presence response is invalid.",
		}

	var response: Dictionary = parsed_body
	return {
		"success": true,
		"onlineUsers": int(response.get("onlineUsers", 0)),
		"connections": int(response.get("connections", 0)),
		"status": response_code,
	}


static func _request_result_message(result: int) -> String:
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
			return "Server status check timed out."
		_:
			return "Server status check failed: %s." % result
