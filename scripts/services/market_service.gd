extends Node

class_name MarketServiceNode

const STANDARD_MARKET_ENDPOINT := "/game/markets/standard"
const STANDARD_MARKET_PURCHASE_ENDPOINT := "/game/markets/standard/purchase"
const STANDARD_MARKET_SALE_ENDPOINT := "/game/markets/standard/sell"
const MARKET_ENDPOINT_TEMPLATE := "/game/markets/%s"
const MARKET_PURCHASE_ENDPOINT_TEMPLATE := "/game/markets/%s/purchase"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_market(market_id: String) -> Dictionary:
	var normalized_market_id := market_id.strip_edges().to_lower()
	match normalized_market_id:
		"", "standard", "standard_pokemart":
			return await load_standard_market()
		_:
			return await _load_named_market(normalized_market_id)


func _load_named_market(market_id: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(
		base_url + MARKET_ENDPOINT_TEMPLATE % market_id.uri_encode(),
		HTTPClient.METHOD_GET,
		gateway.call("get_accept_headers"),
		""
	)
	return parse_market_catalog_response(response)


func load_standard_market() -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(
		base_url + STANDARD_MARKET_ENDPOINT,
		HTTPClient.METHOD_GET,
		gateway.call("get_accept_headers"),
		""
	)
	return parse_market_catalog_response(response)


func purchase_standard_item(item_id: String, quantity: int = 1) -> Dictionary:
	return await purchase_item("standard_pokemart", item_id, quantity)


func purchase_item(
	market_id: String,
	item_id: String,
	quantity: int = 1,
	request_id: String = ""
) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	if item_id.strip_edges() == "":
		return _validation_error("Missing item id.")
	var normalized_market_id := market_id.strip_edges().to_lower()
	if normalized_market_id in ["", "standard"]:
		normalized_market_id = "standard_pokemart"
	var normalized_request_id := request_id.strip_edges().to_lower()
	if normalized_request_id == "":
		normalized_request_id = _new_request_id()
	if normalized_request_id == "":
		return _validation_error("Could not create a purchase request id.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var endpoint := (
		STANDARD_MARKET_PURCHASE_ENDPOINT
		if normalized_market_id == "standard_pokemart"
		else MARKET_PURCHASE_ENDPOINT_TEMPLATE % normalized_market_id.uri_encode()
	)
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify(build_purchase_payload(item_id, quantity, normalized_request_id))
	)
	return parse_purchase_response(response)


func sell_standard_item(item_id: String, quantity: int = 1) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	if item_id.strip_edges() == "":
		return _validation_error("Missing item id.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(
		base_url + STANDARD_MARKET_SALE_ENDPOINT,
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify(build_sale_payload(item_id, quantity))
	)
	return parse_sale_response(response)


func build_purchase_payload(
	item_id: String,
	quantity: int = 1,
	request_id: String = ""
) -> Dictionary:
	var normalized_request_id := request_id.strip_edges().to_lower()
	if normalized_request_id == "":
		normalized_request_id = _new_request_id()
	return {
		"itemId": item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-"),
		"quantity": max(quantity, 1),
		"requestId": normalized_request_id,
	}


func build_sale_payload(item_id: String, quantity: int = 1) -> Dictionary:
	return {
		"itemId": item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-"),
		"quantity": max(quantity, 1),
	}


func parse_market_catalog_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"market": normalize_market(body.get("market", {})),
	}


func parse_purchase_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"purchase": _dictionary_from_value(body.get("purchase", {})),
	}


func parse_sale_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var inventory: Dictionary = _dictionary_from_value(body.get("inventory", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"sale": _dictionary_from_value(body.get("sale", {})),
	}


func normalize_market(value: Variant) -> Dictionary:
	var market: Dictionary = _dictionary_from_value(value)
	var normalized_items: Array = []
	for item_value in _array_from_value(market.get("items", [])):
		normalized_items.append(normalize_market_item(item_value))

	return {
		"id": str(market.get("id", "")),
		"name": str(market.get("name", "")),
		"type": str(market.get("type", "")),
		"region": str(market.get("region", "")),
		"locationId": str(market.get("locationId", "")),
		"locationName": str(market.get("locationName", "")),
		"badgeCount": _optional_nonnegative_int(market.get("badgeCount"), -1),
		"nextUnlockBadge": _optional_nonnegative_int(market.get("nextUnlockBadge"), -1),
		"items": normalized_items,
	}


func normalize_market_item(value: Variant) -> Dictionary:
	var item: Dictionary = _dictionary_from_value(value)
	return {
		"itemId": str(item.get("itemId", "")),
		"name": str(item.get("name", "")),
		"category": str(item.get("category", "")),
		"shortDesc": str(item.get("shortDesc", "")),
		"sellPrice": max(int(item.get("sellPrice", 0)), 0),
		"requiredBadges": max(int(item.get("requiredBadges", 0)), 0),
		"available": bool(item.get("available", true)),
		"accountUnique": bool(item.get("accountUnique", false)),
		"accountBound": bool(item.get("accountBound", false)),
		"owned": bool(item.get("owned", false)),
		"maxPurchaseQuantity": clampi(int(item.get("maxPurchaseQuantity", 99)), 1, 99),
		"costs": normalize_costs(item.get("costs", [])),
	}


func _new_request_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8),
		value.substr(8, 4),
		value.substr(12, 4),
		value.substr(16, 4),
		value.substr(20, 12),
	]


func normalize_costs(value: Variant) -> Array:
	var normalized_costs: Array = []
	for cost_value in _array_from_value(value):
		var cost: Dictionary = _dictionary_from_value(cost_value)
		var currency := str(cost.get("currency", "")).strip_edges().to_lower()
		if currency == "":
			continue
		normalized_costs.append({
			"currency": currency,
			"amount": max(int(cost.get("amount", 0)), 0),
			"baseAmount": max(int(cost.get("baseAmount", cost.get("amount", 0))), 0),
			"membershipDiscountPercent": max(
				int(cost.get("membershipDiscountPercent", 0)),
				0
			),
		})
	return normalized_costs


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


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _auth_error() -> Dictionary:
	return {
		"success": false,
		"error": "Not authenticated.",
	}


func _validation_error(message: String) -> Dictionary:
	return {
		"success": false,
		"error": message,
	}


func _is_authenticated() -> bool:
	if not is_inside_tree():
		return false
	var auth_service := get_node_or_null("/root/AuthService")
	return auth_service != null and auth_service.has_method("is_authenticated") and bool(auth_service.call("is_authenticated"))


func _gateway_api_config() -> Object:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GatewayApiConfig")


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


func _optional_nonnegative_int(value: Variant, fallback: int) -> int:
	if value == null or typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return max(int(value), 0)


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
