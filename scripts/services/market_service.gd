extends Node

class_name MarketServiceNode

const STANDARD_MARKET_ENDPOINT := "/game/markets/standard"
const STANDARD_MARKET_PURCHASE_ENDPOINT := "/game/markets/standard/purchase"
const REQUEST_TIMEOUT_SECONDS := 8.0


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
	if not _is_authenticated():
		return _auth_error()
	if item_id.strip_edges() == "":
		return _validation_error("Missing item id.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = await gateway.call("get_base_url")
	var response: Dictionary = await _request_json(
		base_url + STANDARD_MARKET_PURCHASE_ENDPOINT,
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify(build_purchase_payload(item_id, quantity))
	)
	return parse_purchase_response(response)


func build_purchase_payload(item_id: String, quantity: int = 1) -> Dictionary:
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
		"items": normalized_items,
	}


func normalize_market_item(value: Variant) -> Dictionary:
	var item: Dictionary = _dictionary_from_value(value)
	return {
		"itemId": str(item.get("itemId", "")),
		"name": str(item.get("name", "")),
		"category": str(item.get("category", "")),
		"shortDesc": str(item.get("shortDesc", "")),
		"costs": normalize_costs(item.get("costs", [])),
	}


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
		})
	return normalized_costs


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


func _extract_error(body: Dictionary, response_code: int) -> String:
	if body.has("detail"):
		var detail: Variant = body.get("detail")
		if typeof(detail) == TYPE_DICTIONARY:
			var detail_dictionary: Dictionary = detail
			return str(detail_dictionary.get("message", detail_dictionary.get("code", "Request failed.")))
		return str(detail)
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


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


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Server connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Server TLS error."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		_:
			return "Request failed: %s." % result
