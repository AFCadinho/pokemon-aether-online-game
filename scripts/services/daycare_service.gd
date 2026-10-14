extends Node

# Preserve uncertain writes across map changes. The server owns durable receipts.
var pending_request: Dictionary = {}
var pending_display: Dictionary = {}
var pending_account_id := ""

func state() -> Dictionary:
	_reset_for_account()
	return await _request("", HTTPClient.METHOD_GET, {})

func preview(selection: Dictionary) -> Dictionary:
	_reset_for_account()
	return await _request("/preview", HTTPClient.METHOD_POST, selection)

func confirm(preview_id: String, display: Dictionary = {}) -> Dictionary:
	_reset_for_account()
	if pending_request.is_empty():
		pending_display = display.duplicate(true)
		pending_request = {"kind": "deposit", "path": "/confirm", "payload": {"previewId": preview_id, "requestId": _uuid()}}
	return await retry()

func pickup(job_id: String) -> Dictionary:
	_reset_for_account()
	if pending_request.is_empty():
		pending_request = {"kind": "pickup", "path": "/" + job_id + "/pickup", "payload": {"requestId": _uuid()}}
	return await retry()

func retry() -> Dictionary:
	_reset_for_account()
	if pending_request.is_empty():
		return {"success": false, "error": LocalizationManager.text("ui.daycare.no_pending")}
	var identity := pending_account_id
	var response := await _request(str(pending_request.get("path", "")), HTTPClient.METHOD_POST, pending_request.get("payload", {}))
	if identity != AuthService.get_user_id_text():
		_reset_for_account()
		return {"success": false, "error": LocalizationManager.text("ui.daycare.account_changed")}
	if bool(response.get("success", false)):
		pending_request.clear()
		pending_display.clear()
		await PlayerPartyStateService.refresh_party()
		PlayerWalletService.apply_wallet_result(await PlayerWalletService.load_wallet())
	else:
		var status := int(response.get("status", 0))
		var detail: Variant = response.get("body", {}).get("detail", {})
		var retryable := detail is Dictionary and bool(detail.get("retryable", false))
		# A network/server failure may hide a successful commit; keep its request ID.
		if status >= 400 and status < 500 and status not in [408, 429] and not retryable:
			pending_request.clear()
			pending_display.clear()
	return response

func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _reset_for_account() -> void:
	var identity := AuthService.get_user_id_text()
	if pending_account_id != identity:
		pending_request.clear()
		pending_display.clear()
		pending_account_id = identity

func _request(path: String, method: HTTPClient.Method, payload: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": LocalizationManager.text("ui.daycare.auth_required")}
	var identity := AuthService.get_user_id_text()
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await PlayerPartyStateService._request_json(base_url + "/game/daycare" + path, method,
		GatewayApiConfig.get_json_headers(), JSON.stringify(payload) if method != HTTPClient.METHOD_GET else "")
	if identity != AuthService.get_user_id_text():
		return {"success": false, "error": LocalizationManager.text("ui.daycare.account_changed")}
	return response
