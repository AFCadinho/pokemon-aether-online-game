extends Node

class_name InventoryServiceNode

signal inventory_changed(items: Array)
signal world_pickup_state_changed

const INVENTORY_ENDPOINT := "/game/inventory"
const FISHING_PROGRESSION_ENDPOINT := "/game/fishing/progression"
const FISHING_SELECTION_ENDPOINT := "/game/fishing/selection"
const NPC_ITEM_REWARD_ENDPOINT := "/game/npc-rewards/%s/claim"
const NPC_QUEST_ITEM_TURN_IN_ENDPOINT := "/game/npc-quest-item-turn-ins/%s/claim"
const WORLD_PICKUPS_ENDPOINT := "/game/world-pickups"
const WORLD_PICKUP_CLAIM_ENDPOINT := "/game/world-pickups/%s/claim"
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

var cached_inventory_items: Array = []
var cached_inventory_user_id := 0
var inventory_loaded := false
var collected_world_pickup_ids: Dictionary = {}
var collected_world_pickups_user_id := 0
var collected_world_pickups_loaded := false
var world_pickup_request_active := false


func load_inventory() -> Dictionary:
	if not AuthService.is_authenticated():
		_clear_inventory_cache()
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
	apply_inventory_state(body)
	return {
		"success": true,
		"items": cached_inventory_items.duplicate(true),
	}


func has_item(item_id: String) -> bool:
	var normalized_item_id := item_id.strip_edges().to_lower()
	if (
		normalized_item_id.is_empty()
		or cached_inventory_user_id <= 0
		or cached_inventory_user_id != int(AuthService.current_user.get("id", 0))
	):
		return false
	for value: Variant in cached_inventory_items:
		if not value is Dictionary:
			continue
		var item := value as Dictionary
		if (
			str(item.get("itemId", item.get("item_id", ""))).strip_edges().to_lower() == normalized_item_id
			and int(item.get("quantity", 0)) > 0
		):
			return true
	return false


func apply_inventory_state(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	var inventory := value as Dictionary
	if inventory.get("items", null) is not Array:
		return false
	var items := _array_from_value(inventory.get("items", []))
	cached_inventory_items = items.duplicate(true)
	cached_inventory_user_id = int(AuthService.current_user.get("id", 0))
	inventory_loaded = true
	inventory_changed.emit(cached_inventory_items.duplicate(true))
	return true


func _clear_inventory_cache() -> void:
	cached_inventory_items.clear()
	cached_inventory_user_id = 0
	inventory_loaded = false
	collected_world_pickup_ids.clear()
	collected_world_pickups_user_id = 0
	collected_world_pickups_loaded = false
	world_pickup_request_active = false
	inventory_changed.emit([])
	world_pickup_state_changed.emit()


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
	GameState.fishing_skill_unlocked = bool(progression.get("unlocked", false))
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
	var wallet_result: Dictionary = await PlayerWalletService.load_wallet()
	PlayerWalletService.apply_wallet_result(wallet_result)
	var story_result: Dictionary = await PlayerGameStateService.refresh_story()
	return {
		"success": true,
		"rewardId": str(body.get("rewardId", normalized_reward_id)),
		"itemId": str(body.get("itemId", "")),
		"quantity": maxi(int(body.get("quantity", 1)), 1),
		"claimed": bool(body.get("claimed", false)),
		"alreadyOwned": bool(body.get("alreadyOwned", false)),
		"inventoryRefreshSuccess": bool(inventory_result.get("success", false)),
		"fishingProgressionRefreshSuccess": bool(progression_result.get("success", false)),
		"walletRefreshSuccess": bool(wallet_result.get("success", false)),
		"storyRefreshSuccess": bool(story_result.get("success", false)),
	}


func load_collected_world_pickups(force_refresh := false) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var current_user_id := int(AuthService.current_user.get("id", 0))
	if (
		not force_refresh
		and collected_world_pickups_loaded
		and collected_world_pickups_user_id == current_user_id
	):
		return {
			"success": true,
			"collectedPickupIds": collected_world_pickup_ids.keys(),
		}
	if world_pickup_request_active:
		await world_pickup_state_changed
		return {
			"success": collected_world_pickups_loaded and collected_world_pickups_user_id == current_user_id,
			"collectedPickupIds": collected_world_pickup_ids.keys(),
		}

	world_pickup_request_active = true
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + WORLD_PICKUPS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	world_pickup_request_active = false
	if not bool(response.get("success", false)):
		world_pickup_state_changed.emit()
		return response

	var body := _dictionary_from_value(response.get("body", {}))
	collected_world_pickup_ids.clear()
	for pickup_id_value: Variant in _array_from_value(body.get("collectedPickupIds", [])):
		var normalized_pickup_id := str(pickup_id_value).strip_edges().to_lower()
		if normalized_pickup_id != "":
			collected_world_pickup_ids[normalized_pickup_id] = true
	collected_world_pickups_user_id = current_user_id
	collected_world_pickups_loaded = true
	world_pickup_state_changed.emit()
	return {
		"success": true,
		"collectedPickupIds": collected_world_pickup_ids.keys(),
	}


func is_world_pickup_collected(pickup_id: String) -> bool:
	var normalized_pickup_id := pickup_id.strip_edges().to_lower()
	return (
		collected_world_pickups_loaded
		and collected_world_pickups_user_id == int(AuthService.current_user.get("id", 0))
		and collected_world_pickup_ids.has(normalized_pickup_id)
	)


func claim_world_pickup(pickup_id: String) -> Dictionary:
	var normalized_pickup_id := pickup_id.strip_edges().to_lower()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_pickup_id == "":
		return {"success": false, "error": "Missing world pickup id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + WORLD_PICKUP_CLAIM_ENDPOINT % normalized_pickup_id.uri_encode(),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body := _dictionary_from_value(response.get("body", {}))
	var collected_pickup_ids := _array_from_value(body.get("collectedPickupIds", [normalized_pickup_id]))
	if collected_pickup_ids.is_empty():
		collected_pickup_ids = [normalized_pickup_id]
	for collected_pickup_id_value: Variant in collected_pickup_ids:
		var collected_pickup_id := str(collected_pickup_id_value).strip_edges().to_lower()
		if collected_pickup_id != "":
			collected_world_pickup_ids[collected_pickup_id] = true
	collected_world_pickups_user_id = int(AuthService.current_user.get("id", 0))
	collected_world_pickups_loaded = true
	world_pickup_state_changed.emit()
	var inventory_result := await load_inventory()
	return {
		"success": true,
		"pickupId": str(body.get("pickupId", normalized_pickup_id)),
		"itemId": str(body.get("itemId", "")),
		"quantity": maxi(int(body.get("quantity", 1)), 1),
		"claimed": bool(body.get("claimed", false)),
		"alreadyCollected": bool(body.get("alreadyCollected", false)),
		"inventoryRefreshSuccess": bool(inventory_result.get("success", false)),
	}


func turn_in_npc_quest_item(turn_in_id: String) -> Dictionary:
	var normalized_turn_in_id := turn_in_id.strip_edges().to_lower()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_turn_in_id == "":
		return {"success": false, "error": "Missing NPC quest item turn-in id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + NPC_QUEST_ITEM_TURN_IN_ENDPOINT % normalized_turn_in_id.uri_encode(),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory_result: Dictionary = await load_inventory()
	var story_result: Dictionary = await PlayerGameStateService.refresh_story()
	return {
		"success": true,
		"turnInId": str(body.get("turnInId", normalized_turn_in_id)),
		"itemId": str(body.get("itemId", "")),
		"quantity": maxi(int(body.get("quantity", 1)), 1),
		"turnedIn": bool(body.get("turnedIn", false)),
		"alreadyTurnedIn": bool(body.get("alreadyTurnedIn", false)),
		"inventoryRefreshSuccess": bool(inventory_result.get("success", false)),
		"storyRefreshSuccess": bool(story_result.get("success", false)),
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
	var story_refresh_success := false
	if bool(body.get("caught", false)):
		var story_result: Dictionary = await PlayerGameStateService.refresh_story()
		story_refresh_success = bool(story_result.get("success", false))
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
		"storyRefreshSuccess": story_refresh_success,
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
