extends Node

# Aethering accepts only server identities and lock choices. Never send IVs.
const PENDING_PATH := "user://aethering_pending_%d.json"
const REQUEST_TIMEOUT_SECONDS := 12.0
var pending: Dictionary = {}

func load_candidates() -> Dictionary:
	return await _api("candidates", HTTPClient.METHOD_GET)

func preview(selection: Dictionary) -> Dictionary:
	return await _api("preview", HTTPClient.METHOD_POST, {
		"recipientId": int(selection.get("recipientId", 0)),
		"donorId": int(selection.get("donorId", 0)),
		"recipientLock": selection.get("recipientLock"),
		"donorLock": selection.get("donorLock"),
	})

func restore_pending() -> Dictionary:
	pending = {}
	var path := PENDING_PATH % int(AuthService.current_user.get("id", 0))
	if FileAccess.file_exists(path):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary and int(value.get("userId", 0)) == int(AuthService.current_user.get("id", -1)):
			pending = value
	return pending.duplicate(true)

func begin_confirmation(plan: Dictionary, context: Dictionary) -> bool:
	if not pending.is_empty():
		return false
	pending = {"userId": int(AuthService.current_user.get("id", 0)), "requestId": _new_request_id(), "previewId": str(plan.get("previewId", "")), "plan": plan.duplicate(true), "context": context.duplicate(true)}
	var file := FileAccess.open(PENDING_PATH % int(pending["userId"]), FileAccess.WRITE)
	if file == null:
		pending.clear()
		return false
	file.store_string(JSON.stringify(pending))
	file.flush()
	if file.get_error() != OK:
		pending.clear()
		return false
	return true

func confirm_pending() -> Dictionary:
	if pending.is_empty() or int(pending.get("userId", 0)) != int(AuthService.current_user.get("id", -1)):
		return _validation_error("No confirmation for this account.")
	var result := await _api("confirm", HTTPClient.METHOD_POST, {"previewId": pending["previewId"], "requestId": pending["requestId"]})
	# Transport, auth expiry, rate limits, 5xx and busy outcomes remain unresolved.
	# Only definitive domain/validation rejections can discard this receipt.
	var detail: Variant = result.get("body", {}).get("detail", {})
	var retryable := bool(detail.get("retryable", false)) if detail is Dictionary else false
	var status := int(result.get("status", 0))
	if bool(result.get("success", false)) or (status in [400, 404, 409, 422] and not retryable):
		clear_pending()
	return result

func clear_pending() -> void:
	var path := PENDING_PATH % int(pending.get("userId", AuthService.current_user.get("id", 0)))
	pending.clear()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _api(endpoint: String, method: HTTPClient.Method, payload: Dictionary = {}) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	var request_user_id := int(AuthService.current_user.get("id", 0))
	var request_session := AuthService.session_token
	var gateway := _gateway_api_config()
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(base_url + "/game/aethering/" + endpoint, method, gateway.call("get_json_headers"), JSON.stringify(payload) if method != HTTPClient.METHOD_GET else "")
	if request_user_id != int(AuthService.current_user.get("id", 0)) or request_session != AuthService.session_token:
		return {"success": false, "status": 0, "body": {"detail": {"code": "aethering_session_changed"}}}
	if bool(response.get("success", false)):
		return {"success": true, "data": response.get("body", {})}
	return response

func _new_request_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20, 12)]

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
