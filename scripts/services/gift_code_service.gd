extends Node

class_name GiftCodeServiceNode

const REDEEM_ENDPOINT := "/game/gift-codes/redeem"
const REQUEST_TIMEOUT_SECONDS := 8.0


func redeem(code: String, request_id: String = "") -> Dictionary:
	var normalized_code := code.strip_edges()
	if not AuthService.is_authenticated():
		return {"success": false, "error": LocalizationManager.text("backend.error.auth_required")}
	if normalized_code == "":
		return {"success": false, "error": LocalizationManager.text("ui.gift_code.error.empty")}
	var normalized_request_id := request_id.strip_edges()
	if normalized_request_id == "":
		normalized_request_id = _new_request_id()

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + REDEEM_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({"code": normalized_code, "requestId": normalized_request_id})
	)
	if not bool(response.get("success", false)):
		return response

	var body := _dictionary(response.get("body", {}))
	var wallet_response := _dictionary(body.get("wallet", {}))
	var wallet := _dictionary(wallet_response.get("wallet", {}))
	PlayerSave.money = maxi(int(wallet.get("money", PlayerSave.money)), 0)
	PlayerSave.gems = maxi(int(wallet.get("gems", PlayerSave.gems)), 0)
	PlayerSave.aetherite = maxi(int(wallet.get("aetherite", PlayerSave.aetherite)), 0)
	PlayerSave.battle_points = maxi(int(wallet.get("battle_points", PlayerSave.battle_points)), 0)

	var party_response := _dictionary(body.get("party", {}))
	var party := _array(party_response.get("party", []))
	PlayerSave.replace_party_from_state(party)
	var inventory_response := _dictionary(body.get("inventory", {}))
	return {
		"success": true,
		"redemptionId": str(body.get("redemptionId", "")),
		"publicMessage": str(body.get("publicMessage", "")),
		"rewards": _array(body.get("rewards", [])),
		"inventory": _array(inventory_response.get("items", [])),
		"party": party,
		"wallet": wallet,
		"storageLocations": _array(body.get("storageLocations", [])),
	}


func _new_request_id() -> String:
	var value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8), value.substr(8, 4), value.substr(12, 4),
		value.substr(16, 4), value.substr(20, 12),
	]


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var start_error := request.request(url, headers, method, body)
	if start_error != OK:
		request.queue_free()
		return {"success": false, "error": error_string(start_error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.transport_message(int(result[0])),
		}
	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary(parsed)
	if response_code < 200 or response_code >= 300:
		return BackendErrorLocalizationService.decorate({"success": false, "status": response_code, "body": response_body})
	return {"success": true, "status": response_code, "body": response_body}


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
