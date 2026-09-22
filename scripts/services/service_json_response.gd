extends RefCounted
## Decode object-based API replies without printing raw bodies or parser errors.
## Transport failures are not JSON replies. A malformed 2xx is not a success.
static func decode(result: int, status: int, payload: PackedByteArray, allow_no_content := false) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": status,
			"error": BackendErrorLocalizationService.transport_message(result),
			"requestResult": result}
	var text := payload.get_string_from_utf8().strip_edges()
	if allow_no_content and status in [204, 205] and text.is_empty():
		return {"success": true, "status": status, "body": {}}
	var parser := JSON.new()
	var valid_object := false
	if not text.is_empty() and parser.parse(text) == OK:
		valid_object = parser.data is Dictionary
	var body: Dictionary = parser.data if valid_object else {}
	if status < 200 or status >= 300:
		return BackendErrorLocalizationService.decorate({"success": false, "status": status, "body": body})
	if not valid_object:
		return BackendErrorLocalizationService.decorate({"success": false, "status": status,
			"code": "service_unavailable", "diagnosticCode": "invalid_json_response"})
	return {"success": true, "status": status, "body": body}
