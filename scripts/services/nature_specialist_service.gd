extends Node

# A timeout keeps the same preview/request pair for safe retries across map changes.
var pending_request: Dictionary = {}
var pending_display: Dictionary = {}
var pending_account_id := ""

func state() -> Dictionary:
	_reset_for_account()
	return await _request("", HTTPClient.METHOD_GET, {})

func preview(pokemon_id: int, nature: String) -> Dictionary:
	return await _request("/preview", HTTPClient.METHOD_POST, {"pokemonId": pokemon_id, "nature": nature})

func confirm(preview_id: String, display: Dictionary = {}) -> Dictionary:
	_reset_for_account()
	if pending_request.is_empty():
		pending_account_id = AuthService.get_user_id_text()
		pending_display = display.duplicate(true)
		var hex := Crypto.new().generate_random_bytes(16).hex_encode()
		var request_id := "%s-%s-%s-%s-%s" % [hex.substr(0,8), hex.substr(8,4), hex.substr(12,4), hex.substr(16,4), hex.substr(20,12)]
		pending_request = {"previewId": preview_id, "requestId": request_id}
	var account_identity := pending_account_id
	var response := await _request("/confirm", HTTPClient.METHOD_POST, pending_request.duplicate(true))
	if account_identity != AuthService.get_user_id_text():
		return {"success": false, "error": "Account changed. Reopen the Nature Specialist."}
	if bool(response.get("success", false)):
		pending_request.clear()
		pending_display.clear()
		await PlayerPartyStateService.refresh_party()
		PlayerWalletService.apply_wallet_result(await PlayerWalletService.load_wallet())
	elif int(response.get("status", 0)) >= 400:
		var detail: Dictionary = response.get("body", {}).get("detail", {}) if response.get("body", {}).get("detail", {}) is Dictionary else {}
		if not bool(detail.get("retryable", false)):
			pending_request.clear()
			pending_display.clear()
	return response

func _reset_for_account() -> void:
	if pending_account_id != AuthService.get_user_id_text():
		pending_request.clear()
		pending_display.clear()
		pending_account_id = AuthService.get_user_id_text()

func _request(path: String, method: HTTPClient.Method, payload: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	return await PlayerPartyStateService._request_json(base_url + "/game/nature-specialist" + path, method,
		GatewayApiConfig.get_json_headers(), JSON.stringify(payload) if method != HTTPClient.METHOD_GET else "")
