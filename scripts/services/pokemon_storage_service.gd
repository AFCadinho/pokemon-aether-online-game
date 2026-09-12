extends Node

class_name PokemonStorageServiceNode

const BOXES_ENDPOINT := "/game/boxes"
const BOX_ENDPOINT := "/game/boxes/%s"
const STORAGE_MOVE_ENDPOINT := "/game/pokemon/storage/move"
const POKEMON_ENDPOINT := "/game/pokemon/%s"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_boxes() -> Dictionary:
	if not _is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await _get_base_url()
	var response: Dictionary = await _request_json(
		base_url + BOXES_ENDPOINT,
		HTTPClient.METHOD_GET,
		_get_accept_headers(),
		""
	)
	return parse_boxes_response(response)


func load_box(box_index: int) -> Dictionary:
	if not _is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if box_index < 0:
		return {
			"success": false,
			"error": "Invalid box.",
		}

	var base_url: String = await _get_base_url()
	var response: Dictionary = await _request_json(
		base_url + BOX_ENDPOINT % str(box_index).uri_encode(),
		HTTPClient.METHOD_GET,
		_get_accept_headers(),
		""
	)
	return parse_box_response(response)


func rename_box(box_index: int, name: String) -> Dictionary:
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if box_index < 0:
		return {"success": false, "error": "Invalid box."}

	var base_url: String = await _get_base_url()
	var response: Dictionary = await _request_json(
		base_url + BOX_ENDPOINT % str(box_index).uri_encode(),
		HTTPClient.METHOD_PATCH,
		_get_json_headers(),
		JSON.stringify({"name": name.strip_edges()})
	)
	return parse_box_response(response)


func move_pokemon(pokemon_id: int, source: Dictionary, target: Dictionary) -> Dictionary:
	if not _is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon.",
	}

	var payload := build_move_payload(pokemon_id, source, target)
	var base_url: String = await _get_base_url()
	var response: Dictionary = await _request_json(
		base_url + STORAGE_MOVE_ENDPOINT,
		HTTPClient.METHOD_POST,
		_get_json_headers(),
		JSON.stringify(payload)
	)
	var result: Dictionary = parse_move_response(response)
	if bool(result.get("success", false)):
		var party_value: Variant = result.get("party", [])
		if party_value is Array:
			var player_save := get_node_or_null("/root/PlayerSave")
			if player_save != null and player_save.has_method("replace_party_from_state"):
				player_save.call("replace_party_from_state", party_value as Array)
	return result


func release_pokemon(pokemon_id: int) -> Dictionary:
	if not _is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon.",
		}

	var base_url: String = await _get_base_url()
	var response: Dictionary = await _request_json(
		base_url + POKEMON_ENDPOINT % str(pokemon_id).uri_encode(),
		HTTPClient.METHOD_DELETE,
		_get_accept_headers(),
		""
	)
	var result: Dictionary = parse_release_response(response)
	if bool(result.get("success", false)):
		var party_value: Variant = result.get("party", [])
		if party_value is Array:
			var player_save := get_node_or_null("/root/PlayerSave")
			if player_save != null and player_save.has_method("replace_party_from_state"):
				player_save.call("replace_party_from_state", party_value as Array)
	return result


static func build_move_payload(pokemon_id: int, source: Dictionary, target: Dictionary) -> Dictionary:
	var payload := {
		"pokemonId": pokemon_id,
		"target": _normalize_move_location(target),
	}
	if not source.is_empty():
		payload["source"] = _normalize_move_location(source)
	return payload


static func party_location(slot_index: int) -> Dictionary:
	return {
		"type": "party",
		"partySlot": slot_index,
	}


static func next_empty_party_location(party_size: int) -> Dictionary:
	if party_size < 0 or party_size >= 6:
		return {}
	return party_location(party_size)


static func box_location(box_index: int, slot_index: int) -> Dictionary:
	return {
		"type": "box",
		"boxIndex": box_index,
		"slotIndex": slot_index,
	}


static func parse_boxes_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"boxCount": int(body.get("boxCount", 0)),
		"slotsPerBox": int(body.get("slotsPerBox", 0)),
		"boxes": _normalize_boxes_array(body.get("boxes", [])),
	}


static func parse_box_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"boxCount": int(body.get("boxCount", 0)),
		"slotsPerBox": int(body.get("slotsPerBox", 0)),
		"box": _normalize_box_state(body.get("box", {})),
	}


static func parse_move_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"location": normalize_storage_location(body.get("location", {})),
		"party": _array_from_value(party.get("party", [])),
		"hasParty": bool(party.get("hasParty", false)),
	}


static func parse_release_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"party": _array_from_value(body.get("party", [])),
		"hasParty": bool(body.get("hasParty", false)),
	}


static func normalize_storage_location(value: Variant) -> Dictionary:
	var location: Dictionary = _dictionary_from_value(value)
	var location_type: String = str(location.get("type", "")).strip_edges().to_lower()
	if location_type == "party":
		return {
			"type": "party",
			"partySlot": int(location.get("partySlot", location.get("party_slot", -1))),
		}
	if location_type == "box":
		return {
			"type": "box",
			"boxIndex": int(location.get("boxIndex", location.get("box_index", -1))),
			"slotIndex": int(location.get("slotIndex", location.get("slot_index", -1))),
		}
	return {}


static func storage_location_label(value: Variant) -> String:
	var location: Dictionary = normalize_storage_location(value)
	match str(location.get("type", "")):
		"party":
			var party_slot: int = int(location.get("partySlot", -1))
			return "party slot %d" % (party_slot + 1) if party_slot >= 0 else "party"
		"box":
			var box_index: int = int(location.get("boxIndex", -1))
			var slot_index: int = int(location.get("slotIndex", -1))
			if box_index >= 0 and slot_index >= 0:
				return "Box %d slot %d" % [box_index + 1, slot_index + 1]
			if box_index >= 0:
				return "Box %d" % (box_index + 1)
	return "storage"


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	url = WebRuntime.gameplay_url(url)
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


static func _normalize_move_location(location: Dictionary) -> Dictionary:
	var location_type: String = str(location.get("type", "")).strip_edges().to_lower()
	if location_type == "party":
		return party_location(int(location.get("partySlot", location.get("party_slot", -1))))
	if location_type == "box":
		return box_location(
			int(location.get("boxIndex", location.get("box_index", -1))),
			int(location.get("slotIndex", location.get("slot_index", -1)))
		)
	return {
		"type": location_type,
	}


static func _normalize_boxes_array(value: Variant) -> Array:
	var normalized: Array = []
	if typeof(value) != TYPE_ARRAY:
		return normalized
	var boxes: Array = value
	for box_value: Variant in boxes:
		normalized.append(_normalize_box_state(box_value))
	return normalized


static func _normalize_box_state(value: Variant) -> Dictionary:
	var box: Dictionary = _dictionary_from_value(value)
	return {
		"boxIndex": int(box.get("boxIndex", box.get("box_index", 0))),
		"name": str(box.get("name", "")).strip_edges(),
		"slots": _normalize_box_slots_array(box.get("slots", [])),
	}


static func _normalize_box_slots_array(value: Variant) -> Array:
	var normalized: Array = []
	if typeof(value) != TYPE_ARRAY:
		return normalized
	var slots: Array = value
	for slot_value: Variant in slots:
		var slot: Dictionary = _dictionary_from_value(slot_value)
		if slot.is_empty():
			continue
		normalized.append({
			"boxIndex": int(slot.get("boxIndex", slot.get("box_index", 0))),
			"slotIndex": int(slot.get("slotIndex", slot.get("slot_index", 0))),
			"pokemon": _dictionary_from_value(slot.get("pokemon", {})),
		})
	return normalized


static func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)


func _is_authenticated() -> bool:
	var auth_service := get_node_or_null("/root/AuthService")
	if auth_service == null or not auth_service.has_method("is_authenticated"):
		return false
	return bool(auth_service.call("is_authenticated"))


func _get_base_url() -> String:
	var gateway_config := get_node_or_null("/root/GatewayApiConfig")
	if gateway_config == null or not gateway_config.has_method("get_base_url"):
		return ""
	return str(await gateway_config.call("get_base_url"))


func _get_accept_headers() -> PackedStringArray:
	var gateway_config := get_node_or_null("/root/GatewayApiConfig")
	if gateway_config == null or not gateway_config.has_method("get_accept_headers"):
		return PackedStringArray()
	var headers: Variant = gateway_config.call("get_accept_headers")
	return headers as PackedStringArray if headers is PackedStringArray else PackedStringArray()


func _get_json_headers() -> PackedStringArray:
	var gateway_config := get_node_or_null("/root/GatewayApiConfig")
	if gateway_config == null or not gateway_config.has_method("get_json_headers"):
		return PackedStringArray()
	var headers: Variant = gateway_config.call("get_json_headers")
	return headers as PackedStringArray if headers is PackedStringArray else PackedStringArray()
