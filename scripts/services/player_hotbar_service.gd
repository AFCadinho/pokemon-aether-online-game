extends Node

class_name PlayerHotbarServiceNode

signal hotbar_changed(slots: Array)

const HOTBAR_ENDPOINT := "/game/hotbar"
const REQUEST_TIMEOUT_SECONDS := 8.0

var cached_slots: Array = []

func clear_cached_state() -> void:
	cached_slots = []
	hotbar_changed.emit(cached_slots)


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


func move_slot(source_slot: int, target_slot: int) -> Dictionary:
	if source_slot == target_slot:
		return {"success": true, "slots": cached_slots}
	var updated := cached_slots.duplicate(true)
	var source_entry: Dictionary = {}
	var target_entry: Dictionary = {}
	for value: Variant in updated:
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		if int(entry.get("slot", -1)) == source_slot:
			source_entry = entry
		elif int(entry.get("slot", -1)) == target_slot:
			target_entry = entry
	if source_entry.is_empty():
		return {"success": false, "error": "The source hotbar slot is empty."}
	source_entry["slot"] = target_slot
	if not target_entry.is_empty():
		target_entry["slot"] = source_slot
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
		return {
			"success": false,
			"error": BackendErrorLocalizationService.message({"code": "service_unavailable"}),
			"diagnosticError": error_string(error),
		}
	var completed: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	var parsed_body: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	var status := int(completed[1])
	var request_result := int(completed[0])
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": status,
			"error": BackendErrorLocalizationService.transport_message(request_result),
		}
	if status < 200 or status >= 300:
		return BackendErrorLocalizationService.decorate({
			"success": false,
			"status": status,
			"body": parsed_body,
		})
	return {"success": true, "body": parsed_body}
