extends Node

class_name RockSmashServiceNode

signal state_changed(state: Dictionary)

const ROCK_SMASH_ENDPOINT := "/game/rock-smash"
const SMASH_ENDPOINT := "/game/rock-smash/smash"
const REQUEST_TIMEOUT_SECONDS := 8.0

var state: Dictionary = {}
var state_loaded := false
var was_authenticated := false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	var authenticated := AuthService.is_authenticated()
	if authenticated and not was_authenticated:
		load_state.call_deferred()
	elif not authenticated and was_authenticated:
		state.clear()
		state_loaded = false
		state_changed.emit({})
	was_authenticated = authenticated


func load_state() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var response := await _request_json(ROCK_SMASH_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	_apply_state(_dictionary_from_value(response.get("body", {})))
	return {"success": true, "state": state.duplicate(true)}


func smash_rock(rock_id: String, field_move_result: Dictionary) -> Dictionary:
	var normalized_rock_id := rock_id.strip_edges().to_lower()
	if normalized_rock_id.is_empty():
		return {"success": false, "error": "Missing Rock Smash rock id."}
	var source := str(field_move_result.get("source", "")).strip_edges().to_lower()
	var pokemon_id := 0
	var pokemon: Pokemon = field_move_result.get("pokemon") as Pokemon
	if source == "pokemon" and pokemon != null:
		pokemon_id = pokemon.owned_pokemon_id
	var response := await _request_json(
		SMASH_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"rockId": normalized_rock_id,
			"requestId": _new_request_id(),
			"source": source,
			"pokemonId": pokemon_id if pokemon_id > 0 else null,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	_apply_state(_dictionary_from_value(body.get("state", {})))
	var inventory_result: Dictionary = await InventoryService.load_inventory()
	var story_result: Dictionary = await PlayerGameStateService.refresh_story()
	return {
		"success": true,
		"rockId": str(body.get("rockId", normalized_rock_id)),
		"rockType": str(body.get("rockType", "training")),
		"rewardItems": _array_from_value(body.get("rewardItems", [])).duplicate(true),
		"experienceAwarded": maxi(int(body.get("experienceAwarded", 0)), 0),
		"state": state.duplicate(true),
		"inventoryRefreshSuccess": bool(inventory_result.get("success", false)),
		"storyRefreshSuccess": bool(story_result.get("success", false)),
	}


func is_rock_smashed_today(rock_id: String) -> bool:
	var ids_value: Variant = state.get("smashedRockIds", [])
	return ids_value is Array and rock_id.strip_edges().to_lower() in ids_value


func is_unlocked() -> bool:
	return bool(state.get("unlocked", false))


func _apply_state(next_state: Dictionary) -> void:
	state = next_state.duplicate(true)
	state_loaded = true
	state_changed.emit(state.duplicate(true))


func _request_json(endpoint: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var headers := GatewayApiConfig.get_accept_headers()
	if not body.is_empty():
		headers = GatewayApiConfig.get_json_headers()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(base_url + endpoint, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": BackendErrorLocalizationService.message({"code": "service_unavailable"}),
			"diagnosticError": error_string(error),
		}
	var result: Array = await request.request_completed
	request.queue_free()
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary_from_value(parsed)
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.transport_message(int(result[0])),
			"body": response_body,
		}
	if response_code < 200 or response_code >= 300:
		return BackendErrorLocalizationService.decorate({
			"success": false,
			"status": response_code,
			"body": response_body,
		})
	return {"success": true, "status": response_code, "body": response_body}


func _new_request_id() -> String:
	return "%s-%s-%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]


func _array_from_value(value: Variant) -> Array:
	return value as Array if value is Array else []


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
