class_name ShinyTrackerServiceNode
extends Node

const TRACKER_ENDPOINT := "/game/shiny-tracker"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_tracker() -> Dictionary:
	return await _request_json(TRACKER_ENDPOINT, HTTPClient.METHOD_GET)


func start_hunt(species_id: String, replace_active: bool = false) -> Dictionary:
	return await _request_json(
		TRACKER_ENDPOINT + "/hunts",
		HTTPClient.METHOD_POST,
		{"speciesId": species_id, "replaceActive": replace_active}
	)


func stop_hunt(hunt_id: String) -> Dictionary:
	return await _request_json(
		TRACKER_ENDPOINT + "/hunts/%s/stop" % hunt_id.uri_encode(),
		HTTPClient.METHOD_POST
	)


func share_hunt(hunt_id: String) -> Dictionary:
	return await _request_json(
		TRACKER_ENDPOINT + "/hunts/%s/share" % hunt_id.uri_encode(),
		HTTPClient.METHOD_POST
	)


func load_shared_hunt(share_id: String) -> Dictionary:
	return await _request_json(
		TRACKER_ENDPOINT + "/shared/%s" % share_id.uri_encode(),
		HTTPClient.METHOD_GET
	)


func _request_json(endpoint: String, method: HTTPClient.Method, payload: Dictionary = {}) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers := GatewayApiConfig.get_accept_headers()
	var body := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var base_url: String = await GatewayApiConfig.get_base_url()
	var error := request.request(base_url + endpoint, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var status := int(result[1])
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var response_body: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		return {
			"success": false,
			"status": status,
			"error": BackendErrorLocalizationService.message({"body": response_body, "status": status}),
			"body": response_body,
		}
	return {"success": true, "tracker": response_body}
