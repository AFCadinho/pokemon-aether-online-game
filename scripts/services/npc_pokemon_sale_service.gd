extends Node

class_name NpcPokemonSaleServiceNode

const SALE_ENDPOINT := "/game/npc-pokemon-sales/%s"
const PURCHASE_ENDPOINT := "/game/npc-pokemon-sales/%s/purchase"
const REQUEST_TIMEOUT_SECONDS := 8.0


func get_sale(sale_id: String) -> Dictionary:
	return await _sale_request(sale_id, false)


func purchase(sale_id: String) -> Dictionary:
	var result := await _sale_request(sale_id, true)
	if not bool(result.get("success", false)):
		return result
	PlayerWalletService.apply_wallet_result({
		"success": true,
		"wallet": result.get("wallet", {}),
	})
	if bool(result.get("purchased", false)):
		await PlayerPartyStateService.refresh_party()
	return result


func _sale_request(sale_id: String, should_purchase: bool) -> Dictionary:
	var normalized_sale_id := sale_id.strip_edges().to_lower()
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if normalized_sale_id.is_empty():
		return {"success": false, "error": "Missing Pokemon sale id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var endpoint := PURCHASE_ENDPOINT if should_purchase else SALE_ENDPOINT
	var method := HTTPClient.METHOD_POST if should_purchase else HTTPClient.METHOD_GET
	var response := await _request_json(
		base_url + endpoint % normalized_sale_id.uri_encode(),
		method,
		GatewayApiConfig.get_json_headers() if should_purchase else GatewayApiConfig.get_accept_headers()
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"saleId": str(body.get("saleId", normalized_sale_id)),
		"speciesId": str(body.get("speciesId", "")),
		"speciesName": str(body.get("speciesName", "")),
		"level": int(body.get("level", 1)),
		"price": int(body.get("price", 0)),
		"basePrice": int(body.get("basePrice", body.get("price", 0))),
		"currency": str(body.get("currency", "money")),
		"membershipDiscountPercent": int(body.get("membershipDiscountPercent", 0)),
		"purchased": bool(body.get("purchased", false)),
		"alreadyPurchased": bool(body.get("alreadyPurchased", false)),
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"pokemon": _dictionary_from_value(body.get("pokemon", {})),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(url, headers, method, "")
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var body: Dictionary = parsed if parsed is Dictionary else {}
	if request_result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.message({"body": body, "status": response_code}),
			"body": body,
			"raw": response_text,
		}
	return {"success": true, "status": response_code, "body": body}


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
