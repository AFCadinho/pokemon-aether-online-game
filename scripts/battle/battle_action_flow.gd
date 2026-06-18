extends RefCounted

class_name BattleActionFlow

var battle_state: BattleState
var request_node: HTTPRequest
var ability_response_handler: Callable


func setup(
	state: BattleState,
	http_request: HTTPRequest,
	on_successful_response: Callable = Callable()
) -> void:
	battle_state = state
	request_node = http_request
	ability_response_handler = on_successful_response


func apply_response(response: Dictionary, apply_event_conditions: bool = true) -> bool:
	if not bool(response.get("success", false)):
		print("Battle API failed: ", response)
		return false

	if ability_response_handler.is_valid():
		ability_response_handler.call(response)

	battle_state.load_from_api_response(response, apply_event_conditions)
	return true


func submit_player_choice(choice_type: String, slot: int) -> Dictionary:
	var response: Dictionary = await send_player_choice(choice_type, slot)
	if not _is_successful_response(response):
		print("Player choice failed: ", response)
		return response

	if not apply_response(response, not _response_has_transform_event(response)):
		return response

	return response


func submit_npc_choice(player_id: String = "p2") -> Dictionary:
	var response: Dictionary = await send_npc_choice(player_id)
	if not _is_successful_response(response):
		print("NPC choice failed: ", response)
		return response

	if not apply_response(response, not _response_has_transform_event(response)):
		return response

	return response


func send_player_choice(choice_type: String, slot: int) -> Dictionary:
	return await BattleApiClient.send_choice(
		request_node,
		battle_state.battle_id,
		"p1",
		choice_type,
		slot
	)


func send_npc_choice(player_id: String = "p2") -> Dictionary:
	return await BattleApiClient.send_npc_choice(
		request_node,
		battle_state.battle_id,
		player_id
	)


func _is_successful_response(response: Dictionary) -> bool:
	return bool(response.get("success", false))

func _response_has_transform_event(response: Dictionary) -> bool:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return false

	var events: Array = events_value as Array
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) == "transform":
			return true

	return false
