extends Node

class_name PlayerHotbarServiceNode

signal hotbar_changed(slots: Array)

const HOTBAR_ENDPOINT := "/game/hotbar"
const REQUEST_TIMEOUT_SECONDS := 8.0

var cached_slots: Array = []


func load_hotbar() -> Dictionary:
	var response := await _request_json(HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = response.get("body", {}) as Dictionary
	cached_slots = (body.get("slots", []) as Array).duplicate(true)
	hotbar_changed.emit(cached_slots)
	return {"success": true, "slots": cached_slots}


func save_hotbar(slots: Array) -> Dictionary:
	var response := await _request_json(HTTPClient.METHOD_PUT, JSON.stringify({"slots": slots}))
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = response.get("body", {}) as Dictionary
	cached_slots = (body.get("slots", []) as Array).duplicate(true)
	hotbar_changed.emit(cached_slots)
	return {"success": true, "slots": cached_slots}


func assign(slot_index: int, entry_type: String, entry_id: String) -> Dictionary:
	var updated := cached_slots.duplicate(true)
	for index in range(updated.size() - 1, -1, -1):
		if int((updated[index] as Dictionary).get("slot", -1)) == slot_index:
			updated.remove_at(index)
	updated.append({"slot": slot_index, "entryType": entry_type, "entryId": entry_id})
	return await save_hotbar(updated)


func clear_slot(slot_index: int) -> Dictionary:
	var updated := cached_slots.duplicate(true)
	for index in range(updated.size() - 1, -1, -1):
		if int((updated[index] as Dictionary).get("slot", -1)) == slot_index:
			updated.remove_at(index)
	return await save_hotbar(updated)


func _request_json(method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var base_url: String = await GatewayApiConfig.get_base_url()
	var headers := GatewayApiConfig.get_accept_headers() if method == HTTPClient.METHOD_GET else GatewayApiConfig.get_json_headers()
	var error := request.request(base_url + HOTBAR_ENDPOINT, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start hotbar request."}
	var completed: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	var parsed_body: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	var status := int(completed[1])
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		var detail: Variant = parsed_body.get("detail", {})
		var message := str((detail as Dictionary).get("message", "Hotbar request failed.")) if detail is Dictionary else str(detail)
		return {"success": false, "status": status, "error": message}
	return {"success": true, "body": parsed_body}
