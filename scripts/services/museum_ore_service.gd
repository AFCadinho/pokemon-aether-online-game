extends Node

const QUOTE_ENDPOINT := "/game/museum/ores"
const SALE_ENDPOINT := "/game/museum/ores/sell-all"


func get_quote() -> Dictionary:
	return await _request(QUOTE_ENDPOINT, HTTPClient.METHOD_GET)


func sell_all(quote_id: String, request_id: String) -> Dictionary:
	var response := await _request(SALE_ENDPOINT, HTTPClient.METHOD_POST, {
		"quoteId": quote_id, "requestId": request_id,
	})
	if bool(response.get("success", false)):
		var body: Dictionary = response.get("body", {})
		if body.get("wallet") is Dictionary:
			PlayerWalletService.apply_wallet_result({"success": true, "wallet": body.wallet})
		await InventoryService.load_inventory()
	return response


func _request(endpoint: String, method: HTTPClient.Method, payload: Dictionary = {}) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	var headers := GatewayApiConfig.get_json_headers() if method == HTTPClient.METHOD_POST else GatewayApiConfig.get_accept_headers()
	var error := request.request(await GatewayApiConfig.get_base_url() + endpoint, headers, method,
		JSON.stringify(payload) if method == HTTPClient.METHOD_POST else "")
	if error != OK:
		request.queue_free()
		return {"success": false, "error": BackendErrorLocalizationService.message({"code": "service_unavailable"})}
	var result: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var body: Dictionary = parsed if parsed is Dictionary else {}
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": BackendErrorLocalizationService.transport_message(int(result[0]))}
	var response := {"success": int(result[1]) >= 200 and int(result[1]) < 300, "status": int(result[1]), "body": body}
	return response if response.success else BackendErrorLocalizationService.decorate(response)
