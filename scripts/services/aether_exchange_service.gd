extends Node

class_name AetherExchangeServiceNode

const LISTINGS_ENDPOINT := "/game/exchange/listings"
const PORTFOLIO_ENDPOINT := "/game/exchange/me"
const REQUEST_TIMEOUT_SECONDS := 10.0


func load_listings(asset_type := "", query := "", limit := 50, offset := 0, filters: Dictionary = {}) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var endpoint := LISTINGS_ENDPOINT + "?limit=%d&offset=%d" % [clampi(limit, 1, 100), maxi(offset, 0)]
	var normalized_type := str(asset_type).strip_edges().to_lower()
	if normalized_type in ["item", "pokemon"]:
		endpoint += "&assetType=%s" % normalized_type.uri_encode()
	var normalized_query := str(query).strip_edges()
	if not normalized_query.is_empty():
		endpoint += "&query=%s" % normalized_query.uri_encode()
	for filter_key: String in [
		"minPrice", "maxPrice", "itemCategory", "minLevel", "maxLevel",
		"type", "nature", "ability", "shiny", "hiddenAbility", "minIvTotal",
	]:
		if not filters.has(filter_key):
			continue
		var filter_value: Variant = filters.get(filter_key)
		if filter_value == null or str(filter_value).strip_edges().is_empty():
			continue
		endpoint += "&%s=%s" % [filter_key.uri_encode(), str(filter_value).uri_encode()]
	return _parse_listings_response(await _request(endpoint, HTTPClient.METHOD_GET, {}))


func load_portfolio() -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var response := await _request(PORTFOLIO_ENDPOINT, HTTPClient.METHOD_GET, {})
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"wallet": _dictionary(body.get("wallet", {})),
		"listings": _listing_array(body.get("listings", [])),
		"sellableItems": _array(body.get("sellableItems", [])),
		"sellablePokemon": _array(body.get("sellablePokemon", [])),
		"activeListingLimit": maxi(int(body.get("activeListingLimit", 20)), 1),
	}


func create_item_listing(item_id: String, quantity: int, unit_price: int, request_id := "") -> Dictionary:
	return await _mutate(LISTINGS_ENDPOINT, {
		"requestId": _request_id(request_id),
		"assetType": "item",
		"itemId": item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-"),
		"quantity": maxi(quantity, 1),
		"unitPrice": maxi(unit_price, 1),
	})


func create_pokemon_listing(pokemon_id: int, unit_price: int, request_id := "") -> Dictionary:
	return await _mutate(LISTINGS_ENDPOINT, {
		"requestId": _request_id(request_id),
		"assetType": "pokemon",
		"pokemonId": pokemon_id,
		"quantity": 1,
		"unitPrice": maxi(unit_price, 1),
	})


func buy_listing(listing_id: String, request_id := "") -> Dictionary:
	return await _mutate(
		LISTINGS_ENDPOINT + "/%s/buy" % listing_id.strip_edges().uri_encode(),
		{"requestId": _request_id(request_id)}
	)


func cancel_listing(listing_id: String, request_id := "") -> Dictionary:
	return await _mutate(
		LISTINGS_ENDPOINT + "/%s/cancel" % listing_id.strip_edges().uri_encode(),
		{"requestId": _request_id(request_id)}
	)


func _mutate(endpoint: String, payload: Dictionary) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var response := await _request(endpoint, HTTPClient.METHOD_POST, payload)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"listing": normalize_listing(body.get("listing", {})),
		"wallet": _dictionary(body.get("wallet", {})),
	}


func _parse_listings_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"listings": _listing_array(body.get("listings", [])),
		"total": maxi(int(body.get("total", 0)), 0),
		"limit": maxi(int(body.get("limit", 50)), 1),
		"offset": maxi(int(body.get("offset", 0)), 0),
	}


static func normalize_listing(value: Variant) -> Dictionary:
	var listing := _dictionary(value)
	return {
		"id": str(listing.get("id", "")),
		"assetType": str(listing.get("assetType", "")),
		"asset": _dictionary(listing.get("asset", {})),
		"quantity": maxi(int(listing.get("quantity", 1)), 1),
		"unitPrice": maxi(int(listing.get("unitPrice", 1)), 1),
		"totalPrice": maxi(int(listing.get("totalPrice", 1)), 1),
		"status": str(listing.get("status", "active")),
		"isMine": bool(listing.get("isMine", false)),
		"createdAt": str(listing.get("createdAt", "")),
		"soldAt": str(listing.get("soldAt", "")),
		"cancelledAt": str(listing.get("cancelledAt", "")),
	}


func _request(endpoint: String, method: HTTPClient.Method, payload: Dictionary) -> Dictionary:
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return {"success": false, "error": "Gateway API config is unavailable."}
	var base_url: String = await gateway.call("get_base_url")
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var body := JSON.stringify(payload) if method != HTTPClient.METHOD_GET else ""
	var headers: PackedStringArray = gateway.call("get_json_headers") if method != HTTPClient.METHOD_GET else gateway.call("get_accept_headers")
	var start_error := request.request(base_url + endpoint, headers, method, body)
	if start_error != OK:
		request.queue_free()
		return {"success": false, "error": error_string(start_error)}
	var completed: Array = await request.request_completed
	request.queue_free()
	var request_result := int(completed[0])
	var response_code := int(completed[1])
	var response_text := (completed[3] as PackedByteArray).get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": _request_result_message(request_result)}
	var parsed: Variant = JSON.parse_string(response_text)
	var parsed_body := _dictionary(parsed)
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.message({"body": parsed_body, "status": response_code}),
			"body": parsed_body,
		}
	return {"success": true, "status": response_code, "body": parsed_body}


func _request_id(value: String) -> String:
	var normalized := value.strip_edges()
	return normalized if not normalized.is_empty() else "%d-%d" % [Time.get_unix_time_from_system(), randi()]


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "The request timed out."
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE:
			return "Could not connect to the server."
		_:
			return "The request could not be completed."


func _auth_error() -> Dictionary:
	return {"success": false, "error": "Not authenticated."}


func _is_authenticated() -> bool:
	var auth := get_node_or_null("/root/AuthService")
	return auth != null and bool(auth.call("is_authenticated"))


static func _listing_array(value: Variant) -> Array:
	var result: Array = []
	for entry: Variant in _array(value):
		result.append(normalize_listing(entry))
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
