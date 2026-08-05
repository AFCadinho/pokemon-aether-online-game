extends Node

class_name PartyHealServiceNode

const PLAYER_PARTY_HEAL_ENDPOINT := "/game/party/heal"
const REQUEST_TIMEOUT_SECONDS := 8.0


func heal_party_locally(party: Array) -> bool:
	var changed := false
	for pokemon_value: Variant in party:
		var pokemon := pokemon_value as Pokemon
		if _heal_party_pokemon(pokemon):
			changed = true

	if changed:
		var player_save := _get_player_save()
		if player_save != null:
			player_save.emit_signal("party_changed")
	return changed


func heal_current_party_and_save(respawn_point: Dictionary = {}, public_service := true) -> Dictionary:
	var player_save := _get_player_save()
	if player_save == null:
		return {
			"success": false,
			"error": "Player save is unavailable.",
			"changed": false,
		}

	var party: Array = _get_player_party(player_save)
	if party.is_empty():
		return {
			"success": false,
			"error": "No Pokemon to heal.",
			"changed": false,
		}

	var server_changed := _party_needs_heal(party)
	var server_result := await _heal_current_party_on_server(respawn_point, public_service)
	if bool(server_result.get("success", false)):
		_apply_party_response(player_save, server_result)
		server_result["changed"] = server_changed
		return server_result
	if not _should_fallback_to_local_heal(server_result):
		server_result["changed"] = false
		return server_result

	var changed := heal_party_locally(party)
	var party_state_service := _get_player_party_state_service()
	if party_state_service == null or not party_state_service.has_method("save_current_party"):
		return {
			"success": false,
			"error": "Party state service is unavailable.",
			"changed": changed,
		}

	var result: Dictionary = await party_state_service.call("save_current_party")
	result["changed"] = changed
	return result


func _party_needs_heal(party: Array) -> bool:
	for pokemon_value: Variant in party:
		var pokemon := pokemon_value as Pokemon
		if pokemon == null:
			continue

		var restored_max_hp: int = max(pokemon.max_hp, int(pokemon.stats.get("hp", pokemon.max_hp)), 1)
		if pokemon.max_hp != restored_max_hp or pokemon.current_hp != restored_max_hp or not pokemon.has_saved_hp_state:
			return true

		for move_value: Variant in pokemon.moves:
			if _heal_party_move(move_value) != move_value:
				return true

	return false


func _heal_party_pokemon(pokemon: Pokemon) -> bool:
	if pokemon == null:
		return false

	var changed := false
	var restored_max_hp: int = max(pokemon.max_hp, int(pokemon.stats.get("hp", pokemon.max_hp)), 1)
	if pokemon.max_hp != restored_max_hp:
		pokemon.max_hp = restored_max_hp
		changed = true
	if pokemon.current_hp != restored_max_hp:
		pokemon.current_hp = restored_max_hp
		changed = true
	if not pokemon.has_saved_hp_state:
		pokemon.has_saved_hp_state = true
		changed = true

	for move_index in range(pokemon.moves.size()):
		var healed_move: Variant = _heal_party_move(pokemon.moves[move_index])
		if healed_move != pokemon.moves[move_index]:
			pokemon.moves[move_index] = healed_move
			changed = true

	return changed


func _should_fallback_to_local_heal(server_result: Dictionary) -> bool:
	var status := int(server_result.get("status", 0))
	return status == 404 or status == 405


func _heal_party_move(move_value: Variant) -> Variant:
	if not (move_value is Dictionary):
		return move_value

	var move_data: Dictionary = (move_value as Dictionary).duplicate(true)
	var max_pp: int = int(_get_first_dictionary_value(
		move_data,
		["maxPp", "maxpp", "maxPP", "max_pp", "pp"],
		0
	))
	if max_pp <= 0:
		return move_data

	move_data["pp"] = max_pp
	move_data["currentPp"] = max_pp
	move_data["currentPP"] = max_pp
	move_data["current_pp"] = max_pp
	move_data["maxPp"] = max_pp
	move_data["maxpp"] = max_pp
	return move_data


func _get_first_dictionary_value(dictionary: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key: Variant in keys:
		if dictionary.has(key):
			return dictionary.get(key)
	return fallback


func _get_player_save() -> Node:
	return get_node_or_null("/root/PlayerSave")


func _get_player_party(player_save: Node) -> Array:
	var party_value: Variant = player_save.get("party")
	if party_value is Array:
		return party_value as Array
	return []


func _get_player_party_state_service() -> Node:
	return get_node_or_null("/root/PlayerPartyStateService")


func _heal_current_party_on_server(respawn_point: Dictionary = {}, public_service := true) -> Dictionary:
	var gateway_config := get_node_or_null("/root/GatewayApiConfig")
	if gateway_config == null or not gateway_config.has_method("get_base_url") or not gateway_config.has_method("get_accept_headers") or not gateway_config.has_method("get_json_headers"):
		return {
			"success": false,
			"error": "Gateway config is unavailable.",
		}

	var base_url: String = str(await gateway_config.call("get_base_url"))
	var request_body := JSON.stringify({
		"respawnPoint": respawn_point,
		"publicService": public_service,
	})
	var headers_value: Variant = gateway_config.call("get_json_headers")
	var headers := PackedStringArray()
	if headers_value is PackedStringArray:
		headers = headers_value as PackedStringArray

	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error := request.request(
		base_url + PLAYER_PARTY_HEAL_ENDPOINT,
		headers,
		HTTPClient.METHOD_POST,
		request_body
	)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start heal request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body := {}
	if parsed_body is Dictionary:
		body = parsed_body as Dictionary

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body, response_code),
			"body": body,
			"raw": response_text,
		}

	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
	}


func _apply_party_response(player_save: Node, result: Dictionary) -> void:
	var party_value: Variant = result.get("party", [])
	if party_value is Array and player_save.has_method("replace_party_from_state"):
		player_save.call("replace_party_from_state", party_value as Array)


func _array_from_value(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _request_result_message(request_result: int) -> String:
	return BackendErrorLocalizationService.transport_message(request_result)
