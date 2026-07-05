extends Node

class_name InventoryServiceNode

const INVENTORY_ENDPOINT := "/game/inventory"
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
	return {
		"success": true,
		"items": _array_from_value(body.get("items", [])),
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
	return {
		"success": true,
		"items": _array_from_value(body.get("items", [])),
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
	return {
		"success": true,
		"items": _array_from_value(body.get("items", [])),
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
	if body.has("detail"):
		return str(body.get("detail"))
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


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
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		_:
			return "Request failed."
