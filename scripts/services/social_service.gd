extends Node

class_name SocialServiceNode

const SOCIALS_ENDPOINT := "/game/socials"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_socials() -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT,
		HTTPClient.METHOD_GET,
		gateway.call("get_accept_headers"),
		""
	)
	return _socials_result_from_response(response)


func send_friend_request(username: String) -> Dictionary:
	return await _username_post(SOCIALS_ENDPOINT + "/friend-requests", username)


func accept_friend_request(friendship_id: int) -> Dictionary:
	return await _friend_request_action(friendship_id, "accept")


func decline_friend_request(friendship_id: int) -> Dictionary:
	return await _friend_request_action(friendship_id, "decline")


func cancel_friend_request(friendship_id: int) -> Dictionary:
	return await _friend_request_action(friendship_id, "cancel")


func remove_friend(username: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var normalized_username: String = username.strip_edges()
	if normalized_username == "":
		return _validation_error("Username is required.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT + "/friends/%s" % normalized_username.uri_encode(),
		HTTPClient.METHOD_DELETE,
		gateway.call("get_accept_headers"),
		""
	)
	return _socials_result_from_response(response)


func block_user(username: String) -> Dictionary:
	return await _username_post(SOCIALS_ENDPOINT + "/blocks", username)


func unblock_user(username: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var normalized_username: String = username.strip_edges()
	if normalized_username == "":
		return _validation_error("Username is required.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT + "/blocks/%s" % normalized_username.uri_encode(),
		HTTPClient.METHOD_DELETE,
		gateway.call("get_accept_headers"),
		""
	)
	return _socials_result_from_response(response)


func update_status_message(status_message: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var normalized_status: String = status_message.strip_edges()
	if normalized_status.length() > 100:
		return _validation_error("Status message must be 100 characters or fewer.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT + "/status",
		HTTPClient.METHOD_PUT,
		gateway.call("get_json_headers"),
		JSON.stringify({"statusMessage": normalized_status})
	)
	return _socials_result_from_response(response)


func send_private_message(recipient_username: String, body: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var normalized_recipient: String = recipient_username.strip_edges()
	var normalized_body: String = body.strip_edges()
	if normalized_recipient == "":
		return _validation_error("Recipient username is required.")
	if normalized_body == "":
		return _validation_error("Message body is required.")
	if normalized_body.length() > 300:
		return _validation_error("Message body must be 300 characters or fewer.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT + "/private-messages",
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify({
			"recipientUsername": normalized_recipient,
			"body": normalized_body,
		})
	)
	if not bool(response.get("success", false)):
		return response

	var response_body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"message": _dictionary_from_value(response_body.get("message", {})),
	}


func _friend_request_action(friendship_id: int, action: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()
	if friendship_id <= 0:
		return _validation_error("Missing friend request id.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + SOCIALS_ENDPOINT + "/friend-requests/%s/%s" % [friendship_id, action],
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		"{}"
	)
	return _socials_result_from_response(response)


func _username_post(path: String, username: String) -> Dictionary:
	if not _is_authenticated():
		return _auth_error()

	var normalized_username: String = username.strip_edges()
	if normalized_username == "":
		return _validation_error("Username is required.")

	var gateway := _gateway_api_config()
	if gateway == null:
		return _validation_error("Gateway API config is unavailable.")

	var base_url: String = str(gateway.call("get_base_url"))
	var response: Dictionary = await _request_json(
		base_url + path,
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify({"username": normalized_username})
	)
	return _socials_result_from_response(response)


func _socials_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"overview": _dictionary_from_value(body.get("overview", body)),
		"request": _dictionary_from_value(body.get("request", {})),
		"friend": _dictionary_from_value(body.get("friend", {})),
		"block": _dictionary_from_value(body.get("block", {})),
		"profile": _dictionary_from_value(body.get("profile", {})),
	}


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
		if detail is Dictionary:
			var detail_dictionary: Dictionary = detail as Dictionary
			var message: String = str(detail_dictionary.get("message", "")).strip_edges()
			if message != "":
				return message
			var code: String = str(detail_dictionary.get("code", "")).strip_edges().replace("_", " ")
			if code != "":
				return code.capitalize()
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
