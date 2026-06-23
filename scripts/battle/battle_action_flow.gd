extends RefCounted

class_name BattleActionFlow

var battle_state: BattleState
var request_node: HTTPRequest
var ability_response_handler: Callable
var local_player_id := "p1"


func setup(
	state: BattleState,
	http_request: HTTPRequest,
	on_successful_response: Callable = Callable()
) -> void:
	battle_state = state
	request_node = http_request
	ability_response_handler = on_successful_response

func set_local_player_id(player_id: String) -> void:
	local_player_id = "p2" if player_id == "p2" else "p1"


func apply_response(response: Dictionary, apply_event_conditions: bool = true) -> bool:
	if not bool(response.get("success", false)):
		print("Battle API failed: ", response)
		return false

	var display_response := map_response_for_local_player(response)
	if ability_response_handler.is_valid():
		ability_response_handler.call(display_response)

	battle_state.load_from_api_response(display_response, apply_event_conditions)
	return true

func map_response_for_local_player(response: Dictionary) -> Dictionary:
	if local_player_id != "p2":
		return response
	return _swap_pokemon_sides(response.duplicate(true)) as Dictionary


func submit_player_choice(choice_type: String, slot: int, mega := false, since_event_seq := -1) -> Dictionary:
	var response: Dictionary = await send_player_choice(choice_type, slot, mega, since_event_seq)
	if not _is_successful_response(response):
		print("Player choice failed: ", response)
		return response

	if not apply_response(response, not _response_has_deferred_display_event(response, since_event_seq)):
		return response

	return map_response_for_local_player(response)


func submit_npc_choice(player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	var response: Dictionary = await send_npc_choice(player_id, since_event_seq)
	if not _is_successful_response(response):
		print("NPC choice failed: ", response)
		return response

	if not apply_response(response, not _response_has_deferred_display_event(response, since_event_seq)):
		return response

	return map_response_for_local_player(response)


func send_player_choice(choice_type: String, slot: int, mega := false, since_event_seq := -1) -> Dictionary:
	return await BattleApiClient.send_choice(
		request_node,
		battle_state.battle_id,
		local_player_id,
		choice_type,
		slot,
		mega,
		since_event_seq
	)


func send_npc_choice(player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	return await BattleApiClient.send_npc_choice(
		request_node,
		battle_state.battle_id,
		player_id,
		"basic",
		since_event_seq
	)

func _swap_pokemon_sides(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value as Dictionary
			var result := {}
			for key: Variant in source.keys():
				result[_swap_pokemon_sides(key)] = _swap_pokemon_sides(source[key])
			return result
		TYPE_ARRAY:
			var source_array: Array = value as Array
			var result_array := []
			for item: Variant in source_array:
				result_array.append(_swap_pokemon_sides(item))
			return result_array
		TYPE_STRING:
			return _swap_side_tokens(str(value))
		_:
			return value

func _swap_side_tokens(value: String) -> String:
	return value.replace("p1", "__PAO_P1__").replace("p2", "p1").replace("__PAO_P1__", "p2")


func _is_successful_response(response: Dictionary) -> bool:
	return bool(response.get("success", false))

func _response_has_deferred_display_event(response: Dictionary, since_event_seq := -1) -> bool:
	var events: Array = _get_unrendered_response_events(response, since_event_seq)
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if event_type == "transform" or event_type == "mega":
			return true

	return false

func _get_unrendered_response_events(response: Dictionary, since_event_seq := -1) -> Array:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return []

	var events: Array = events_value as Array
	if since_event_seq < 0:
		return events

	var response_event_seq := int(response.get("eventSeq", -1))
	if response_event_seq < 0:
		return events

	var first_event_seq := response_event_seq - events.size() + 1
	var unrendered_events: Array = []
	for index: int in range(events.size()):
		var event_seq := first_event_seq + index
		if event_seq > since_event_seq:
			unrendered_events.append(events[index])

	return unrendered_events
