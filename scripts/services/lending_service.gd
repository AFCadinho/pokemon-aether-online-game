extends Node

class_name LendingServiceNode

const BASE_ENDPOINT := "/game/loans"
const REQUEST_TIMEOUT_SECONDS := 8.0

var capabilities: Dictionary = {}


func load_capabilities() -> Dictionary:
	return await _get_resource("/capabilities", true)


func load_loans(view := "all", limit := 50, offset := 0) -> Dictionary:
	var normalized := str(view).strip_edges().to_lower()
	if normalized not in ["all", "borrowed", "lent", "history"]:
		normalized = "all"
	return await _get_resource("?view=%s&limit=%d&offset=%d" % [normalized.uri_encode(), clampi(limit, 1, 100), maxi(offset, 0)])


func load_loan(loan_id: String) -> Dictionary:
	if loan_id.strip_edges() == "":
		return _validation_error("Loan id is required.")
	return await _get_resource("/%s" % loan_id.strip_edges().uri_encode())


func load_notifications(limit := 20) -> Dictionary:
	return await _get_resource("/notifications/pending?limit=%d" % clampi(limit, 1, 50))


func acknowledge_notification(notification_id: String) -> Dictionary:
	if notification_id.strip_edges() == "":
		return _validation_error("Notification id is required.")
	return await _command("/notifications/%s/ack" % notification_id.strip_edges().uri_encode(), {})


func load_return_inbox(limit := 50) -> Dictionary:
	return await _get_resource("/returns/inbox?limit=%d" % clampi(limit, 1, 100))


func acknowledge_return(asset_id: String) -> Dictionary:
	if asset_id.strip_edges() == "":
		return _validation_error("Loan asset id is required.")
	return await _command("/returns/%s/ack" % asset_id.strip_edges().uri_encode(), {})


func create_loan(target_username: String, pokemon_ids: Array, items: Array, duration_seconds: int, fee_amount: int, request_id := "") -> Dictionary:
	var username := target_username.strip_edges()
	if username == "":
		return _validation_error("Trainer username is required.")
	var normalized_pokemon: Array[int] = []
	for value: Variant in pokemon_ids:
		var pokemon_id := int(value)
		if pokemon_id <= 0 or pokemon_id in normalized_pokemon:
			return _validation_error("The Pokemon selection is invalid.")
		normalized_pokemon.append(pokemon_id)
	if normalized_pokemon.size() > 6:
		return _validation_error("Choose no more than six Pokemon.")
	var normalized_items: Array[Dictionary] = []
	var item_copy_count := 0
	for value: Variant in items:
		if not value is Dictionary:
			return _validation_error("The item selection is invalid.")
		var item_id := str(value.get("itemId", "")).strip_edges().to_lower().replace("_", "-").replace(" ", "-")
		if item_id == "":
			return _validation_error("The item selection is invalid.")
		var quantity := int(value.get("quantity", 1))
		if quantity < 1 or quantity > 6:
			return _validation_error("Choose between one and six copies of an item.")
		var item := {"itemId": item_id, "quantity": quantity}
		if int(value.get("sourcePokemonId", 0)) > 0:
			if quantity != 1:
				return _validation_error("A held Pokémon can provide only one item copy.")
			item["sourcePokemonId"] = int(value.get("sourcePokemonId", 0))
		normalized_items.append(item)
		item_copy_count += quantity
	if item_copy_count > 6 or (normalized_items.is_empty() and normalized_pokemon.is_empty()):
		return _validation_error("Choose between one and six Pokemon or items.")
	if not normalized_pokemon.is_empty() and not normalized_items.is_empty():
		return _validation_error("A loan offer must contain only Pokemon or only items.")
	if duration_seconds not in [3600, 10800, 21600, 43200, 86400]:
		return _validation_error("Choose a supported loan duration.")
	if fee_amount < 0:
		return _validation_error("The fee cannot be negative.")
	return await _command("", {
		"targetUsername": username,
		"pokemonIds": normalized_pokemon,
		"items": normalized_items,
		"durationSeconds": duration_seconds,
		"feeAmount": fee_amount,
		"requestId": _request_id(request_id),
	})


func accept_loan(loan_id: String, request_id := "") -> Dictionary:
	return await _loan_command(loan_id, "accept", request_id)


func decline_loan(loan_id: String, request_id := "") -> Dictionary:
	return await _loan_command(loan_id, "decline", request_id)


func cancel_loan(loan_id: String, request_id := "") -> Dictionary:
	return await _loan_command(loan_id, "cancel", request_id)


func request_return(loan_id: String, asset_id: String, request_id := "") -> Dictionary:
	if asset_id.strip_edges() == "":
		return _validation_error("Loan asset id is required.")
	return await _command("/%s/request-return" % loan_id.strip_edges().uri_encode(), {
		"assetId": asset_id.strip_edges(),
		"requestId": _request_id(request_id),
	})


func return_assets(loan_id: String, asset_ids: Array = [], request_id := "") -> Dictionary:
	return await _command("/%s/return" % loan_id.strip_edges().uri_encode(), {"assetIds": asset_ids, "requestId": _request_id(request_id)})


func attach_item(asset_id: String, pokemon_id: int, request_id := "") -> Dictionary:
	return await _command("/assets/%s/attach" % asset_id.strip_edges().uri_encode(), {"pokemonId": pokemon_id, "requestId": _request_id(request_id)})


func detach_item(asset_id: String, request_id := "") -> Dictionary:
	return await _command("/assets/%s/detach" % asset_id.strip_edges().uri_encode(), {"requestId": _request_id(request_id)})


func normalize_capabilities(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	return {
		"enabled": bool(source.get("enabled", false)),
		"requiresSameMap": bool(source.get("requiresSameMap", true)),
		"durationsSeconds": _array(source.get("durationsSeconds", [3600, 10800, 21600, 43200, 86400])),
		"maxBorrowedPokemon": maxi(int(source.get("maxBorrowedPokemon", 6)), 0),
		"maxBorrowedItems": maxi(int(source.get("maxBorrowedItems", 6)), 0),
		"maxLentPokemon": maxi(int(source.get("maxLentPokemon", 30)), 0),
		"maxLentItems": maxi(int(source.get("maxLentItems", 30)), 0),
		"maxPendingOffers": maxi(int(source.get("maxPendingOffers", 5)), 0),
	}


func _loan_command(loan_id: String, action: String, request_id: String) -> Dictionary:
	if loan_id.strip_edges() == "":
		return _validation_error("Loan id is required.")
	return await _command("/%s/%s" % [loan_id.strip_edges().uri_encode(), action], {"requestId": _request_id(request_id)})


func _get_resource(path: String, is_capabilities := false) -> Dictionary:
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")
	var response := await _request_json(str(await gateway.call("get_base_url")) + BASE_ENDPOINT + path, HTTPClient.METHOD_GET, gateway.call("get_accept_headers"), "")
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	if is_capabilities:
		capabilities = normalize_capabilities(body)
		return {"success": true, "capabilities": capabilities.duplicate(true)}
	return {"success": true, "body": body}


func _command(path: String, payload: Dictionary) -> Dictionary:
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")
	var response := await _request_json(str(await gateway.call("get_base_url")) + BASE_ENDPOINT + path, HTTPClient.METHOD_POST, gateway.call("get_json_headers"), JSON.stringify(payload))
	return response if not bool(response.get("success", false)) else {"success": true, "loan": _dictionary(response.get("body", {}))}


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
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": "Could not reach the lending service."}
	var parsed: Variant = JSON.parse_string(response_text)
	var parsed_body := _dictionary(parsed)
	if response_code < 200 or response_code >= 300:
		var detail := _dictionary(parsed_body.get("detail", {}))
		return {"success": false, "status": response_code, "code": str(detail.get("code", "")), "error": str(detail.get("message", detail if not detail.is_empty() else "The lending request failed."))}
	return {"success": true, "status": response_code, "body": parsed_body}


func _request_id(value: String) -> String:
	return value.strip_edges() if value.strip_edges() != "" else "%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


func _is_authenticated() -> bool:
	var auth := get_node_or_null("/root/AuthService")
	return auth != null and auth.has_method("is_authenticated") and bool(auth.call("is_authenticated"))


func _validation_error(message: String) -> Dictionary:
	return {"success": false, "error": message}


func _dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []
