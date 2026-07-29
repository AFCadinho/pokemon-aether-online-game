extends Node

class_name InventoryServiceNode

const INVENTORY_ENDPOINT := "/game/inventory"
const FISHING_PROGRESSION_ENDPOINT := "/game/fishing/progression"
const FISHING_SELECTION_ENDPOINT := "/game/fishing/selection"
const NPC_ITEM_REWARD_ENDPOINT := "/game/npc-rewards/%s/claim"
const APPEARANCE_INVENTORY_ENDPOINT := "/game/appearance/inventory"
const INVENTORY_ITEM_USE_ENDPOINT := "/game/inventory/items/%s/use"
const APPEARANCE_ITEM_RETURN_ENDPOINT := "/game/appearance/inventory/items/%s/return"
const TRAINER_NAME_CHANGE_ENDPOINT := "/game/trainer-services/name-change"
const TRAINER_GENDER_CHANGE_ENDPOINT := "/game/trainer-services/gender-change"
const WILD_BATTLE_CATCH_ENDPOINT := "/game/wild-battles/%s/catch"
const POKEMON_ITEM_USE_ENDPOINT := "/game/pokemon/%s/items/use"
const DEV_ADD_ITEM_ENDPOINT := "/game/dev/inventory/items"
const DEV_CLEAR_ITEMS_ENDPOINT := "/game/dev/inventory/items"
const ITEM_SEARCH_ENDPOINT := "/game/items/search?q=%s"
const DEV_ITEM_SEARCH_ENDPOINT := "/game/dev/items/search?q=%s"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_inventory() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + INVENTORY_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var items := _array_from_value(body.get("items", []))
	return {
		"success": true,
		"items": items,
	}


func load_fishing_progression(area_id := "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var endpoint := FISHING_PROGRESSION_ENDPOINT
	var normalized_area_id := str(area_id).strip_edges()
	if normalized_area_id != "":
		endpoint += "?areaId=%s" % normalized_area_id.uri_encode()
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var progression := _dictionary_from_value(response.get("body", {}))
	apply_fishing_progression(progression)
	return {"success": true, "progression": progression}


func select_fishing_rod(item_id: String, area_id := "") -> Dictionary:
	var normalized_item_id := item_id.strip_edges().to_lower()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + FISHING_SELECTION_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": normalized_item_id,
			"areaId": str(area_id).strip_edges(),
		})
	)
	if not bool(response.get("success", false)):
		return response

	var progression := _dictionary_from_value(response.get("body", {}))
	apply_fishing_progression(progression)
	return {"success": true, "progression": progression}


func apply_fishing_progression(progression: Dictionary) -> void:
	GameState.fishing_level = maxi(int(progression.get("level", 1)), 1)
	GameState.fishing_total_experience = maxi(int(progression.get("totalExperience", 0)), 0)
	GameState.fishing_experience_into_level = maxi(int(progression.get("experienceIntoLevel", 0)), 0)
	GameState.fishing_experience_for_next_level = maxi(int(progression.get("experienceForNextLevel", 0)), 0)
	GameState.selected_fishing_rod_item_id = str(progression.get("selectedRodItemId", "")).strip_edges().to_lower()
	GameState.fishing_region = str(progression.get("region", "kanto")).strip_edges().to_lower()
	GameState.fishing_region_badge_count = maxi(int(progression.get("badgeCount", 0)), 0)
	GameState.fishing_rods = _array_from_value(progression.get("rods", [])).duplicate(true)
	GameState.fishing_tier = maxi(int(progression.get("activeTier", 0)), 0)
	GameState.fishing_unlocked = bool(progression.get("selectedRodUsable", false)) and GameState.fishing_tier > 0
	get_tree().call_group("fishing_action_controller", "refresh_from_game_state")
	get_tree().call_group("player", "refresh_fishing_prompt")


func claim_npc_item_reward(reward_id: String) -> Dictionary:
	var normalized_reward_id := reward_id.strip_edges().to_lower()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_reward_id == "":
		return {"success": false, "error": "Missing NPC reward id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + NPC_ITEM_REWARD_ENDPOINT % normalized_reward_id.uri_encode(),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory_result: Dictionary = await load_inventory()
	var progression_result: Dictionary = await load_fishing_progression("")
	return {
		"success": true,
		"rewardId": str(body.get("rewardId", normalized_reward_id)),
		"itemId": str(body.get("itemId", "")),
		"quantity": maxi(int(body.get("quantity", 1)), 1),
		"claimed": bool(body.get("claimed", false)),
		"alreadyOwned": bool(body.get("alreadyOwned", false)),
		"inventoryRefreshSuccess": bool(inventory_result.get("success", false)),
		"fishingProgressionRefreshSuccess": bool(progression_result.get("success", false)),
	}


func load_appearance_inventory() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + APPEARANCE_INVENTORY_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"slotLimit": int(body.get("slotLimit", 8)),
		"slotCounts": _dictionary_from_value(body.get("slotCounts", {})),
		"unlocks": _array_from_value(body.get("unlocks", [])),
	}


func use_inventory_item(item_id: String) -> Dictionary:
	var normalized_item_id := item_id.strip_edges()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_item_id == "":
		return {"success": false, "error": "Missing item id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + INVENTORY_ITEM_USE_ENDPOINT % normalized_item_id.uri_encode(),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	var appearance_inventory: Dictionary = _dictionary_from_value(body.get("appearanceInventory", {}))
	return {
		"success": true,
		"itemId": str(body.get("itemId", normalized_item_id)),
		"useAction": str(body.get("useAction", "")),
		"durationDays": maxi(int(body.get("durationDays", 0)), 0),
		"grantedItems": _array_from_value(body.get("grantedItems", [])),
		"guild": _dictionary_from_value(body.get("guild", {})),
		"user": _dictionary_from_value(body.get("user", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"appearanceSlotLimit": int(appearance_inventory.get("slotLimit", 8)),
		"appearanceSlotCounts": _dictionary_from_value(appearance_inventory.get("slotCounts", {})),
		"appearanceUnlocks": _array_from_value(appearance_inventory.get("unlocks", [])),
	}


func return_appearance_item(item_id: String) -> Dictionary:
	var normalized_item_id := item_id.strip_edges()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_item_id == "":
		return {"success": false, "error": "Missing item id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + APPEARANCE_ITEM_RETURN_ENDPOINT % normalized_item_id.uri_encode(),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	var appearance_inventory: Dictionary = _dictionary_from_value(body.get("appearanceInventory", {}))
	return {
		"success": true,
		"itemId": str(body.get("itemId", normalized_item_id)),
		"returnedUnlocks": _array_from_value(body.get("returnedUnlocks", [])),
		"inventory": _array_from_value(inventory.get("items", [])),
		"appearanceSlotLimit": int(appearance_inventory.get("slotLimit", 8)),
		"appearanceSlotCounts": _dictionary_from_value(appearance_inventory.get("slotCounts", {})),
		"appearanceUnlocks": _array_from_value(appearance_inventory.get("unlocks", [])),
	}


func change_trainer_name(username: String, display_name: String) -> Dictionary:
	return await _trainer_service_request(TRAINER_NAME_CHANGE_ENDPOINT, {"username": username, "displayName": display_name})


func change_trainer_gender(gender: String) -> Dictionary:
	return await _trainer_service_request(TRAINER_GENDER_CHANGE_ENDPOINT, {"gender": gender})


func _trainer_service_request(endpoint: String, payload: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(base_url + endpoint, HTTPClient.METHOD_POST, GatewayApiConfig.get_json_headers(), JSON.stringify(payload))
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var inventory := _dictionary_from_value(body.get("inventory", {}))
	var appearance_inventory := _dictionary_from_value(body.get("appearanceInventory", {}))
	return {
		"success": true,
		"user": _dictionary_from_value(body.get("user", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"appearanceUnlocks": _array_from_value(appearance_inventory.get("unlocks", [])),
		"appearanceSlotLimit": int(appearance_inventory.get("slotLimit", 8)),
		"appearanceSlotCounts": _dictionary_from_value(appearance_inventory.get("slotCounts", {})),
		"returnedCosmeticItemCount": int(body.get("returnedCosmeticItemCount", 0)),
	}


func catch_wild_pokemon(battle_id: String, item_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if battle_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing battle id.",
		}
	if item_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing item id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var endpoint := WILD_BATTLE_CATCH_ENDPOINT % battle_id.uri_encode()
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": item_id,
		})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"battleId": str(body.get("battleId", battle_id)),
		"caught": bool(body.get("caught", false)),
		"shakeCount": int(body.get("shakeCount", 0)),
		"requiresBattleTurn": bool(body.get("requiresBattleTurn", false)),
		"message": str(body.get("message", "")),
		"itemId": str(body.get("itemId", item_id)),
		"addedToParty": bool(body.get("addedToParty", false)),
		"storageLocation": PokemonStorageService.normalize_storage_location(body.get("storageLocation", {})),
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"party": _array_from_value(party.get("party", [])),
	}


func use_pokemon_item(pokemon_id: int, item_id: String, quantity: int = 1) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if pokemon_id <= 0:
		return {
			"success": false,
			"error": "Missing Pokemon id.",
		}
	if item_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing item id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var endpoint := POKEMON_ITEM_USE_ENDPOINT % str(pokemon_id).uri_encode()
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": item_id,
			"quantity": max(quantity, 1),
		})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"reward": _dictionary_from_value(body.get("reward", {})),
		"party": _array_from_value(party.get("party", [])),
		"inventory": _array_from_value(inventory.get("items", [])),
	}


func dev_add_item(item_id: String, quantity: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if item_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing item id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_ADD_ITEM_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": item_id,
			"quantity": max(quantity, 1),
		})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var items := _array_from_value(body.get("items", []))
	return {
		"success": true,
		"items": items,
	}


func search_dev_items(query: String) -> Dictionary:
	return await _search_items(DEV_ITEM_SEARCH_ENDPOINT, query)


func search_items(query: String) -> Dictionary:
	return await _search_items(ITEM_SEARCH_ENDPOINT, query)


func _search_items(endpoint_template: String, query: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + endpoint_template % query.uri_encode(),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	return {
		"success": true,
		"items": _array_from_value(response.get("body", [])),
	}


func dev_clear_inventory() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_CLEAR_ITEMS_ENDPOINT,
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var items := _array_from_value(body.get("items", []))
	return {
		"success": true,
		"items": items,
	}

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
		"body": parsed_body,
	}


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


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
