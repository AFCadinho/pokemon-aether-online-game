extends RefCounted

class_name BattleActionFlow

const HTTP_RESPONSE_TIMEOUT_SECONDS := 15.0

var battle_state: BattleState
var request_node: HTTPRequest
var ability_response_handler: Callable
var local_player_id := "p1"
var http_flow := preload("res://scripts/battle/battle_http_flow.gd").new()
var http_recovery_required := false


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


func apply_response(
	response: Dictionary,
	apply_event_conditions: bool = true,
	load_battle_state: bool = true,
	since_event_seq := -1
) -> bool:
	if not bool(response.get("success", false)):
		print("Battle API failed: ", response)
		return false

	var display_response := map_response_for_local_player(response)
	if ability_response_handler.is_valid():
		ability_response_handler.call(display_response)

	if load_battle_state:
		battle_state.load_from_api_response(display_response, apply_event_conditions, since_event_seq)
	return true

func map_response_for_local_player(response: Dictionary) -> Dictionary:
	if local_player_id != "p2":
		return response
	return _swap_pokemon_sides(response.duplicate(true)) as Dictionary


func submit_player_choice(choice_type: String, slot: int, mega := false, since_event_seq := -1, z_move := false) -> Dictionary:
	var response: Dictionary = await send_player_choice(choice_type, slot, mega, since_event_seq, z_move)
	if not _is_successful_response(response):
		http_recovery_required = true
		return response

	return await accept_http_response(response, since_event_seq)


func submit_player_choice_and_resolve(choice_type: String, slot: int, mega := false, since_event_seq := -1, z_move := false) -> Dictionary:
	var response: Dictionary = await send_player_choice_and_resolve(choice_type, slot, mega, since_event_seq, z_move)
	if not _is_successful_response(response):
		http_recovery_required = true
		return response

	return await accept_http_response(response, since_event_seq)


func submit_npc_choice(player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	var response: Dictionary = await send_npc_choice(player_id, since_event_seq)
	if not _is_successful_response(response):
		http_recovery_required = true
		return response

	return await accept_http_response(response, since_event_seq)


func submit_pass_turn(pass_player_id: String = "p1", player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	var response: Dictionary = await send_pass_turn(pass_player_id, player_id, since_event_seq)
	if not _is_successful_response(response):
		http_recovery_required = true
		return response

	return await accept_http_response(response, since_event_seq)


func accept_http_response(response: Dictionary, since_event_seq: int, recover_gap := true) -> Dictionary:
	if not _is_successful_response(response):
		http_recovery_required = true
		return response
	if str(response.get("battleId", "")) != battle_state.battle_id:
		return {"success": false, "code": "BATTLE_RESPONSE_ID_MISMATCH"}
	if http_flow.has_gap(response, since_event_seq):
		if recover_gap:
			return await recover_http_response(since_event_seq)
		http_recovery_required = true
		return {"success": false, "code": "BATTLE_EVENT_DELIVERY_GAP"}
	if http_flow.is_stale(response):
		var latest: Dictionary = http_flow.order.latest_response.duplicate(true)
		if int(latest.get("eventSeq", -1)) <= since_event_seq:
			latest["events"] = []
			latest["eventBatches"] = []
		return latest
	# Preserve the immutable post-event snapshot before BattleState rewinds HP.
	http_flow.remember(response)
	http_recovery_required = false
	apply_response(response, not _response_has_deferred_display_event(response, since_event_seq), true, since_event_seq)
	return map_response_for_local_player(response)


func recover_http_response(since_event_seq: int) -> Dictionary:
	_set_http_timeout()
	var response: Dictionary = await BattleApiClient.get_npc_battle_state(request_node, battle_state.battle_id, since_event_seq)
	return await accept_http_response(response, since_event_seq, false)


func restore_http_response(response: Dictionary, rendered_seq: int) -> void:
	if http_flow.is_stale(response):
		return
	var snapshot: Dictionary = http_flow.order.canonical_snapshot_for_render_cursor(response, rendered_seq)
	if bool(snapshot.get("state", {}).get("ended", false)):
		snapshot["requests"] = battle_state.requests.duplicate(true)
	battle_state.load_from_api_response(snapshot, false, rendered_seq, true)


func send_player_choice(choice_type: String, slot: int, mega := false, since_event_seq := -1, z_move := false) -> Dictionary:
	_set_http_timeout()
	return await BattleApiClient.send_choice(
		request_node,
		battle_state.battle_id,
		local_player_id,
		choice_type,
		slot,
		mega,
		since_event_seq,
		z_move
		)


func send_player_choice_and_resolve(choice_type: String, slot: int, mega := false, since_event_seq := -1, z_move := false) -> Dictionary:
	_set_http_timeout()
	return await BattleApiClient.send_choice_and_resolve(
		request_node,
		battle_state.battle_id,
		local_player_id,
		choice_type,
		slot,
		mega,
		"basic",
		"p2",
		since_event_seq,
		z_move
	)


func send_npc_choice(player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	_set_http_timeout()
	return await BattleApiClient.send_npc_choice(
		request_node,
		battle_state.battle_id,
		player_id,
		"basic",
		since_event_seq
	)

func send_pass_turn(pass_player_id: String = "p1", player_id: String = "p2", since_event_seq := -1) -> Dictionary:
	_set_http_timeout()
	return await BattleApiClient.send_pass_turn(
		request_node,
		battle_state.battle_id,
		pass_player_id,
		player_id,
		"basic",
		since_event_seq
	)

func _set_http_timeout() -> void:
	if request_node != null:
		request_node.timeout = HTTP_RESPONSE_TIMEOUT_SECONDS


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
		if event_type == "damage" or event_type == "heal" or event_type == "faint":
			return true
		if event_type == "transform" or event_type == "formeChange" or event_type == "mega" or event_type == "primal":
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
