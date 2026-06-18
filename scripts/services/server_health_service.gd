extends RefCounted
class_name ServerHealthService

const DEFAULT_HEALTH_URL := "https://pokeaether.com/health"
const REQUEST_TIMEOUT_SECONDS := 8.0
const USER_AGENT_HEADER := "User-Agent: PokeAether/1.0"
const PRESENCE_ENDPOINT := "/presence/online-count"


static func check_async(parent: Node, health_url: String = DEFAULT_HEALTH_URL) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	parent.add_child(request)

	var error: Error = request.request(
		health_url,
		[USER_AGENT_HEADER],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		request.queue_free()
		return {
			"online": false,
			"error": "Could not start health request: %s" % error_string(error),
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
			"error": "Health check returned HTTP %s." % response_code,
		}

	var parsed_body: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed_body) != TYPE_DICTIONARY:
		return {
			"online": false,
			"status": response_code,
			"error": "Health response is invalid.",
		}

	var response: Dictionary = parsed_body
	var status_text: String = str(response.get("status", "")).strip_edges().to_lower()
	return {
		"online": status_text == "online",
		"status": response_code,
		"server_status": status_text,
	}


static func check_presence_async(parent: Node) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	return await request_presence_async(parent, base_url.rstrip("/") + PRESENCE_ENDPOINT)


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
			return "Server health check timed out."
		_:
			return "Server health check failed: %s." % result
