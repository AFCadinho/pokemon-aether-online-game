extends Node

class_name DonatorStoreServiceNode

const STORE_ENDPOINT := "/game/donator-store"
const PURCHASE_ENDPOINT := "/game/donator-store/purchase"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_store() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + STORE_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"store": _normalize_store(body.get("store", {})),
	}


func purchase_item(item_id: String, request_id: String = "") -> Dictionary:
	var normalized_item_id := item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_item_id == "":
		return {"success": false, "error": "Missing item id."}

	var normalized_request_id := request_id.strip_edges()
	if normalized_request_id == "":
		normalized_request_id = _new_request_id()
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PURCHASE_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"itemId": normalized_item_id,
			"requestId": normalized_request_id,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var inventory := _dictionary_from_value(body.get("inventory", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"purchase": _dictionary_from_value(body.get("purchase", {})),
	}


func _normalize_store(value: Variant) -> Dictionary:
	var store := _dictionary_from_value(value)
	var items: Array[Dictionary] = []
	for item_value: Variant in _array_from_value(store.get("items", [])):
		var item := _dictionary_from_value(item_value)
		var costs: Array[Dictionary] = []
		for cost_value: Variant in _array_from_value(item.get("costs", [])):
			var cost := _dictionary_from_value(cost_value)
			var currency := str(cost.get("currency", "")).strip_edges().to_lower()
			if currency == "":
				continue
			costs.append({
				"currency": currency,
				"amount": maxi(int(cost.get("amount", 0)), 0),
			})
		items.append({
			"itemId": str(item.get("itemId", "")).strip_edges(),
			"name": str(item.get("name", "")),
			"category": str(item.get("category", "")),
			"shortDesc": str(item.get("shortDesc", "")),
			"genders": _array_from_value(item.get("genders", [])),
			"costs": costs,
		})
	return {
		"id": str(store.get("id", "")),
		"name": str(store.get("name", "")),
		"type": str(store.get("type", "")),
		"items": items,
	}


func _new_request_id() -> String:
	var value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8),
		value.substr(8, 4),
		value.substr(12, 4),
		value.substr(16, 4),
		value.substr(20, 12),
	]


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}

	var result: Array = await request.request_completed
	request.queue_free()
	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
		}

	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary_from_value(parsed)
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(response_body, response_code),
			"body": response_body,
		}
	return {"success": true, "status": response_code, "body": response_body}


func _extract_error(body: Dictionary, response_code: int) -> String:
	var detail: Variant = body.get("detail")
	if detail is Dictionary:
		return str((detail as Dictionary).get("message", "Request failed."))
	if detail != null:
		return str(detail)
	return str(body.get("error", "Request failed with HTTP %s." % response_code))


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


func _dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _array_from_value(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []
