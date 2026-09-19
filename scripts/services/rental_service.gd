extends Node

var pending_requests: Dictionary = {}

func request(path: String, payload: Dictionary = {}, mutate := false, post := false) -> Dictionary:
	var auth := get_node_or_null("/root/AuthService")
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if auth == null or gateway == null or not bool(auth.call("is_authenticated")):
		return {"success": false, "error": "Please sign in."}
	var body := payload.duplicate(true)
	var key := path + JSON.stringify(payload)
	if mutate:
		if not pending_requests.has(key):
			pending_requests[key] = "%d-%d" % [Time.get_ticks_usec(), randi()]
		body["requestId"] = pending_requests[key]
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var url: String = str(await gateway.call("get_base_url")) + "/game/rentals" + path
	var use_post := mutate or post
	var error := http.request(url, gateway.call("get_json_headers"), HTTPClient.METHOD_POST if use_post else HTTPClient.METHOD_GET, JSON.stringify(body) if use_post else "")
	if error != OK:
		http.queue_free()
		return {"success": false, "error": "Could not reach the rental service. Please retry."}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "Connection interrupted. Retry the same action to check its result."}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary:
		return {"success": false, "error": "Invalid rental response."}
	if int(result[1]) < 200 or int(result[1]) >= 300:
		var detail: Variant = parsed.get("detail", {})
		return {"success": false, "error": str(detail.get("message", "Rental request failed.")) if detail is Dictionary else str(detail)}
	if mutate:
		pending_requests.erase(key)
	return {"success": true, "body": parsed}
