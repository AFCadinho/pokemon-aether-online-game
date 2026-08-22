extends Node

class_name PlayerPartyStateServiceNode

const PLAYER_PARTY_ENDPOINT := "/game/party"
const PLAYER_PARTY_BATTLE_ENDPOINT := "/game/party/battle-state"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_party() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	GameState.apply_pokemon_level_cap_state(_dictionary_from_value(body.get("pokemonLevelCap", {})))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(body.get("pokemonLevelCap", {})),
	}


func refresh_party() -> Dictionary:
	var result: Dictionary = await load_party()
	_apply_party_response(result)
	return result


func save_party(party_state: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(party_state)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(body.get("pokemonLevelCap", {})),
	}


func save_battle_state(battle_state: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_BATTLE_ENDPOINT,
		HTTPClient.METHOD_PATCH,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(battle_state)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(body.get("pokemonLevelCap", {})),
	}


func save_current_party() -> Dictionary:
	var result: Dictionary = await save_party(PlayerSave.to_party_state())
	_apply_party_response(result)
	return result


func swap_party_slots(from_slot: int, to_slot: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT + "/swap",
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"fromSlot": from_slot,
			"toSlot": to_slot,
		})
	)
	var result: Dictionary = _party_result_from_response(response)
	_apply_party_response(result)
	return result


func set_party_slot(slot: int, pokemon_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT + "/set-slot",
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"slot": slot,
			"pokemonId": pokemon_id,
		})
	)
	var result: Dictionary = _party_result_from_response(response)
	_apply_party_response(result)
	return result


func clear_party_slot(slot: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PARTY_ENDPOINT + "/%s" % slot,
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	var result: Dictionary = _party_result_from_response(response)
	_apply_party_response(result)
	return result


func create_pokemon(pokemon_data: Dictionary, add_to_party: bool = true, origin_method: String = "gift") -> Dictionary:
	return await _create_owned_pokemon("/game/pokemon", _with_current_origin(pokemon_data, origin_method), add_to_party)


func get_starter_options() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/starter/options",
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"dataRevision": str(body.get("dataRevision", "")),
		"choices": _array_from_value(body.get("choices", [])),
		"total": int(body.get("total", 0)),
		"alreadyClaimed": bool(body.get("alreadyClaimed", false)),
		"selectedSpeciesId": str(body.get("selectedSpeciesId", "")),
		"selectedSpeciesName": str(body.get("selectedSpeciesName", "")),
		"rivalStarterSpeciesId": str(body.get("rivalStarterSpeciesId", "")),
		"rivalStarterSpeciesName": str(body.get("rivalStarterSpeciesName", "")),
		"rivalTrainerId": str(body.get("rivalTrainerId", "")),
	}


func claim_starter(species_id: String) -> Dictionary:
	var normalized_species_id := species_id.strip_edges()
	if normalized_species_id.is_empty():
		return {
			"success": false,
			"error": "Missing starter species.",
		}
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/starter",
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"speciesId": normalized_species_id,
			"addToParty": true,
		})
	)
	var result: Dictionary = _pokemon_create_result_from_response(response)
	_apply_party_response(result)
	return result


func dev_create_pokemon(
	pokemon_data: Dictionary,
	add_to_party: bool = true,
	preserve_direct_battle_form: bool = false,
	test_purpose: String = ""
) -> Dictionary:
	return await _create_owned_pokemon(
		"/game/dev/pokemon",
		_with_current_origin(pokemon_data, "generated"),
		add_to_party,
		{
			"preserveDirectBattleForm": preserve_direct_battle_form,
			"testPurpose": test_purpose,
		}
	)


func content_creator_create_pokemon(pokemon_data: Dictionary, add_to_party: bool = true) -> Dictionary:
	return await _create_owned_pokemon("/game/content-creator/pokemon", _with_current_origin(pokemon_data, "content_creator"), add_to_party)


func content_creator_clear_party_pokemon() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/content-creator/pokemon/party",
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	var result: Dictionary = _party_result_from_response(response)
	_apply_party_response(result)
	return result


func dev_clear_party() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/dev/party",
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	var result: Dictionary = _party_result_from_response(response)
	_apply_party_response(result)
	return result


func cleanup_dev_test_pokemon() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/dev/pokemon/test-fixtures",
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	var result := {
		"success": true,
		"cleaned": maxi(int(body.get("cleaned", 0)), 0),
		"hasParty": bool(party.get("hasParty", false)),
		"party": _array_from_value(party.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
	}
	_apply_party_response(result)
	return result


func _create_owned_pokemon(
	endpoint: String,
	pokemon_data: Dictionary,
	add_to_party: bool = true,
	extra_fields: Dictionary = {}
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var request_body := {
		"pokemon": pokemon_data,
		"addToParty": add_to_party,
	}
	for key: Variant in extra_fields:
		request_body[key] = extra_fields[key]
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(request_body)
	)
	var result: Dictionary = _pokemon_create_result_from_response(response)
	_apply_party_response(result)
	return result


func _with_current_origin(pokemon_data: Dictionary, method: String) -> Dictionary:
	var payload: Dictionary = pokemon_data.duplicate(true)
	var origin_value: Variant = payload.get("origin", {})
	if origin_value is Dictionary and not (origin_value as Dictionary).is_empty():
		return payload

	var origin: Dictionary = _get_current_location_origin(method, int(payload.get("level", 0)))
	payload["origin"] = origin
	payload["location"] = str(origin.get("locationName", "")).strip_edges()
	return payload


func _get_current_location_origin(method: String, met_level: int = 0) -> Dictionary:
	var current_map: Node = GameState.current_map as Node
	var metadata: Dictionary = {}
	if current_map != null and current_map.has_method("get_location_metadata"):
		var metadata_value: Variant = current_map.call("get_location_metadata")
		if metadata_value is Dictionary:
			metadata = metadata_value as Dictionary

	var map_id := ""
	var location_name := ""
	var region_id := ""
	var region_name := ""
	if current_map != null:
		if current_map.has_method("get_map_id"):
			map_id = str(current_map.call("get_map_id")).strip_edges()
		if current_map.has_method("get_map_display_name"):
			location_name = str(current_map.call("get_map_display_name")).strip_edges()
		if current_map.has_method("get_map_region_name"):
			region_name = str(current_map.call("get_map_region_name")).strip_edges()

	var origin := {
		"locationId": str(metadata.get("locationId", map_id)).strip_edges(),
		"locationName": str(metadata.get("locationName", location_name)).strip_edges(),
		"regionId": str(metadata.get("regionId", region_name.to_lower().replace(" ", "_"))).strip_edges(),
		"regionName": str(metadata.get("regionName", region_name)).strip_edges(),
		"mapId": str(metadata.get("mapId", map_id)).strip_edges(),
		"method": method,
	}
	if origin["locationId"] == "":
		origin["locationId"] = "unknown"
	if origin["locationName"] == "":
		origin["locationName"] = "Unknown Location"
	if origin["regionId"] == "":
		origin["regionId"] = "unknown"
	if origin["regionName"] == "":
		origin["regionName"] = origin["regionId"]
	if met_level > 0:
		origin["metLevel"] = met_level
	return origin


func rename_pokemon(pokemon_id: int, nickname: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/nickname" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({"nickname": nickname})
	)
	var result: Dictionary = _pokemon_nickname_result_from_response(response)
	_apply_party_response(result)
	return result


func give_pokemon_held_item(pokemon_id: int, item_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0 or item_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing Pokemon or item.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/held-item" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": item_id,
		})
	)
	var result: Dictionary = _pokemon_item_result_from_response(response)
	_apply_party_response(result)
	return result


func take_pokemon_held_item(pokemon_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/held-item" % pokemon_id,
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	var result: Dictionary = _pokemon_item_result_from_response(response)
	_apply_party_response(result)
	return result


func set_pokemon_ball(pokemon_id: int, ball_item_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0 or ball_item_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing Pokemon or ball.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/ball" % pokemon_id,
		HTTPClient.METHOD_PATCH,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"ballItemId": ball_item_id,
		})
	)
	var result: Dictionary = _pokemon_item_result_from_response(response)
	_apply_party_response(result)
	return result


func allocate_pokemon_evs(pokemon_id: int, stat_id: String, value: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0 or stat_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing Pokemon or stat.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/evs/allocate" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"stat": stat_id,
			"value": clampi(value, 0, 252),
		})
	)
	var result: Dictionary = _pokemon_ev_allocation_result_from_response(response)
	_apply_party_response(result)
	return result


func learn_pokemon_move(pokemon_id: int, move_id: String, replace_slot: int = -1, skip: bool = false, source_item_id: String = "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0 or move_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing Pokemon or move.",
		}

	var payload := {
		"moveId": move_id,
		"skip": skip,
	}
	if replace_slot >= 0:
		payload["replaceSlot"] = replace_slot
	if source_item_id.strip_edges() != "":
		payload["sourceItemId"] = source_item_id

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/moves/learn" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	var result: Dictionary = _pokemon_move_learn_result_from_response(response)
	_apply_party_response(result)
	return result


func reorder_pokemon_moves(pokemon_id: int, move_ids: Array[String]) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0 or move_ids.is_empty() or move_ids.size() > 4:
		return {
			"success": false,
			"error": "Missing Pokemon or move order.",
		}

	var normalized_move_ids: Array[String] = []
	for move_id: String in move_ids:
		var normalized_move_id: String = move_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
		if normalized_move_id == "" or normalized_move_ids.has(normalized_move_id):
			return {
				"success": false,
				"error": "Move order contains invalid or duplicate moves.",
			}
		normalized_move_ids.append(normalized_move_id)

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/moves/reorder" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({"moveIds": normalized_move_ids})
	)
	var result: Dictionary = _pokemon_move_reorder_result_from_response(response)
	_apply_party_response(result)
	return result


func evolve_pokemon(pokemon_id: int, target_species_id: String, confirm: bool = true) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon.",
		}
	if confirm and target_species_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing target species.",
		}

	var payload := {
		"targetSpeciesId": target_species_id,
		"confirm": confirm,
	}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/game/pokemon/%s/evolution" % pokemon_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	var result: Dictionary = _pokemon_evolution_result_from_response(response)
	_apply_party_response(result)
	return result


func save_current_party_deferred() -> void:
	var result: Dictionary = await save_party(PlayerSave.to_party_state())
	if not bool(result.get("success", false)):
		push_warning("PlayerPartyStateService: party save failed: %s" % str(result.get("error", "Unknown error")))


func save_current_battle_party_state_deferred(context: Dictionary = {}) -> void:
	var battle_payload: Dictionary = PlayerSave.to_battle_state()
	for key: Variant in context:
		battle_payload[key] = context[key]
	var result: Dictionary = await save_battle_state(battle_payload)
	if not bool(result.get("success", false)):
		push_warning("PlayerPartyStateService: battle party save failed: %s" % str(result.get("error", "Unknown error")))
		return

	_apply_party_response(result)


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
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
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _party_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasParty": bool(body.get("hasParty", false)),
		"party": _array_from_value(body.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(body.get("pokemonLevelCap", {})),
	}


func _pokemon_item_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"hasParty": bool(party.get("hasParty", false)),
		"party": _array_from_value(party.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
	}


func _pokemon_nickname_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"nickname": str(body.get("nickname", "")),
		"fee": maxi(int(body.get("fee", 0)), 0),
		"changed": bool(body.get("changed", false)),
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"hasParty": bool(party.get("hasParty", false)),
		"party": _array_from_value(party.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
	}


func _pokemon_create_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	var pokemon: Dictionary = _dictionary_from_value(body.get("pokemon", {}))
	return {
		"success": true,
		"pokemon": pokemon,
		"hasParty": bool(party.get("hasParty", false)),
		"party": _array_from_value(party.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
		"storageLocation": PokemonStorageService.normalize_storage_location(body.get("storageLocation", {})),
		"alreadyClaimed": bool(body.get("alreadyClaimed", false)),
		"rivalStarterSpeciesId": str(body.get("rivalStarterSpeciesId", "")),
		"rivalStarterSpeciesName": str(body.get("rivalStarterSpeciesName", "")),
		"rivalTrainerId": str(body.get("rivalTrainerId", "")),
	}


func _pokemon_move_learn_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"party": _array_from_value(party.get("party", [])),
		"hasParty": bool(party.get("hasParty", false)),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
		"learnedMove": _dictionary_from_value(body.get("learnedMove", {})),
		"replacedMove": _dictionary_from_value(body.get("replacedMove", {})),
		"skipped": bool(body.get("skipped", false)),
	}


func _pokemon_move_reorder_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"party": _array_from_value(party.get("party", [])),
		"hasParty": bool(party.get("hasParty", false)),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
		"moveIds": _array_from_value(body.get("moveIds", [])),
	}


func _pokemon_evolution_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"party": _array_from_value(party.get("party", [])),
		"hasParty": bool(party.get("hasParty", false)),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
		"evolution": _dictionary_from_value(body.get("evolution", {})),
		"learnedMoves": _array_from_value(body.get("learnedMoves", [])),
		"moveLearnCandidates": _array_from_value(body.get("moveLearnCandidates", [])),
		"skipped": bool(body.get("skipped", false)),
	}


func _pokemon_ev_allocation_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"party": _array_from_value(party.get("party", [])),
		"hasParty": bool(party.get("hasParty", false)),
		"allocation": _dictionary_from_value(body.get("allocation", {})),
		"evTrainingTutorial": _dictionary_from_value(body.get("evTrainingTutorial", {})),
	}


func _apply_party_response(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return

	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		PlayerSave.replace_party_from_state(party_value as Array)
	var level_cap_value: Variant = result.get("pokemonLevelCap", {})
	if level_cap_value is Dictionary:
		GameState.apply_pokemon_level_cap_state(level_cap_value as Dictionary)


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _request_result_message(request_result: int) -> String:
	return BackendErrorLocalizationService.transport_message(request_result)
