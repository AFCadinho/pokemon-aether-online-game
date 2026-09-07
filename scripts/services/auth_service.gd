extends Node

class_name AuthServiceNode

const ClientBuild := preload("res://scripts/services/client_build.gd")
const SESSION_FILE_PATH := "user://auth_session.json"
const REQUEST_TIMEOUT_SECONDS := 12.0
const PRIVACY_REQUEST_TIMEOUT_SECONDS := 60.0
const USER_AGENT_HEADER := "User-Agent: PokeAether/1.0"
const CONTENT_TYPE_HEADER := "Content-Type: application/json"
const ACCEPT_HEADER := "Accept: application/json"

var session_token := ""
var expires_at := ""
var current_user: Dictionary = {}
var session_type := "player"
var impersonated_by_user_id := 0
var account_switch_pending := false
var pending_login_notice := ""


func is_authenticated() -> bool:
	return session_token != "" and not current_user.is_empty()


func is_impersonating() -> bool:
	return (
		is_authenticated()
		and session_type == "impersonation"
		and impersonated_by_user_id > 0
	)


func get_authorization_header() -> String:
	if session_token == "":
		return ""
	return "Authorization: Bearer %s" % session_token


func set_pending_login_notice(message: String) -> void:
	pending_login_notice = message.strip_edges()


func take_pending_login_notice() -> String:
	var message := pending_login_notice
	pending_login_notice = ""
	return message


func login(username: String, password: String, remember_me: bool) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var payload := {
		"username": username,
		"password": password,
		"rememberMe": remember_me,
	}

	var response: Dictionary = await _request_json(
		base_url + "/auth/login",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, CONTENT_TYPE_HEADER, ACCEPT_HEADER])),
		JSON.stringify(payload)
	)

	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	_apply_auth_response(body)
	_refresh_trade_session.call_deferred()

	if remember_me:
		_save_session()
	else:
		_clear_session_file()

	return {
		"success": true,
		"user": current_user,
		"expiresAt": expires_at,
	}


func impersonate_with_token(token: String) -> Dictionary:
	var normalized_token := token.strip_edges()
	if normalized_token == "":
		return {
			"success": false,
			"error": "Missing impersonation token.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/impersonate/consume",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([
			USER_AGENT_HEADER,
			CONTENT_TYPE_HEADER,
			ACCEPT_HEADER,
			get_authorization_header(),
		])),
		JSON.stringify({"token": normalized_token})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	_reset_account_runtime_state()
	_apply_auth_response(body)
	account_switch_pending = true
	_refresh_trade_session.call_deferred()
	_clear_session_file()

	return {
		"success": true,
		"user": current_user,
		"expiresAt": expires_at,
	}


func stop_impersonating() -> Dictionary:
	if not is_impersonating():
		return {
			"success": false,
			"error": "No active impersonation session.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/impersonate/stop",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([
			USER_AGENT_HEADER,
			ACCEPT_HEADER,
			get_authorization_header(),
		])),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var remember_me := bool(body.get("rememberMe", false))
	_reset_account_runtime_state()
	_apply_auth_response(body)
	account_switch_pending = true
	_refresh_trade_session.call_deferred()
	if remember_me:
		_save_session()
	else:
		_clear_session_file()
	return {
		"success": true,
		"user": current_user,
		"expiresAt": expires_at,
	}


func restore_saved_session() -> Dictionary:
	var saved_session: Dictionary = _load_session_file()
	var saved_token := str(saved_session.get("token", ""))
	if saved_token == "":
		return {
			"success": false,
			"error": "No saved session.",
		}

	session_token = saved_token
	expires_at = str(saved_session.get("expiresAt", ""))
	current_user = _dictionary_from_value(saved_session.get("user", {}))
	session_type = "player"
	impersonated_by_user_id = 0
	account_switch_pending = false

	var me_response: Dictionary = await me()
	if bool(me_response.get("success", false)):
		_save_session()
		_refresh_trade_session.call_deferred()
		return me_response

	clear_session()
	return me_response


func me() -> Dictionary:
	if session_token == "":
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/me",
		HTTPClient.METHOD_GET,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, ACCEPT_HEADER, get_authorization_header()])),
		""
	)

	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	if body.has("user"):
		current_user = _dictionary_from_value(body.get("user", {}))
	else:
		current_user = body
	if body.has("expiresAt"):
		expires_at = str(body.get("expiresAt", ""))

	return {
		"success": true,
		"user": current_user,
		"expiresAt": expires_at,
	}


func logout() -> Dictionary:
	if session_token == "":
		clear_session()
		return {"success": true}
	var trade_realtime_service: Object = get_node_or_null("/root/TradeRealtimeService")
	if trade_realtime_service != null and trade_realtime_service.has_method("leave_active_trade_for_exit"):
		await trade_realtime_service.call("leave_active_trade_for_exit")

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/logout",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, ACCEPT_HEADER, get_authorization_header()])),
		""
	)
	clear_session()
	return response


func create_account_portal_launch(locale: String) -> Dictionary:
	if session_token == "":
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if is_impersonating():
		return {
			"success": false,
			"error": "Account management is unavailable while impersonating a player.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/account-portal/launch",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([
			USER_AGENT_HEADER,
			CONTENT_TYPE_HEADER,
			ACCEPT_HEADER,
			get_authorization_header(),
		])),
		JSON.stringify({"locale": locale})
	)
	if not bool(response.get("success", false)):
		return response

	var body := _dictionary_from_value(response.get("body", {}))
	var url := str(body.get("url", "")).strip_edges()
	if not _is_safe_account_portal_url(url, base_url):
		return {
			"success": false,
			"error": "The account portal returned an invalid address.",
		}
	return {
		"success": true,
		"url": url,
		"expiresAt": str(body.get("expiresAt", "")),
	}


func _is_safe_account_portal_url(url: String, gateway_base_url: String) -> bool:
	if url.length() > 2048 or url.contains("\n") or url.contains("\r"):
		return false
	if not url.contains("/launch#ticket=") or url.contains("@"):
		return false
	if url.begins_with("https://"):
		return true
	if not (
		gateway_base_url.begins_with("http://localhost")
		or gateway_base_url.begins_with("http://127.0.0.1")
	):
		return false
	if not url.begins_with("http://"):
		return false
	var authority := url.trim_prefix("http://").get_slice("/", 0).to_lower()
	var host := authority.get_slice(":", 0)
	return host in ["localhost", "127.0.0.1"] or host.ends_with(".localhost")


func update_account_details(display_name: String, current_password: String, new_password: String) -> Dictionary:
	if session_token == "":
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var payload: Dictionary = {
		"displayName": display_name,
	}
	if new_password.strip_edges() != "":
		payload["currentPassword"] = current_password
		payload["newPassword"] = new_password

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/auth/account",
		HTTPClient.METHOD_PUT,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, CONTENT_TYPE_HEADER, ACCEPT_HEADER, get_authorization_header()])),
		JSON.stringify(payload)
	)

	if not bool(response.get("success", false)):
		return response

	current_user = _dictionary_from_value(response.get("body", {}))
	if session_token != "":
		_save_session()

	return {
		"success": true,
		"user": current_user,
	}


func export_personal_data(current_password: String, locale: String) -> Dictionary:
	if session_token == "":
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/privacy/export",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, CONTENT_TYPE_HEADER, ACCEPT_HEADER, get_authorization_header()])),
		JSON.stringify({
			"currentPassword": current_password,
			"locale": locale,
		}),
		PRIVACY_REQUEST_TIMEOUT_SECONDS
	)
	if not bool(response.get("success", false)):
		return response
	return {
		"success": true,
		"document": _dictionary_from_value(response.get("body", {})),
	}


func delete_account(current_password: String, locale: String) -> Dictionary:
	if session_token == "":
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + "/privacy/delete",
		HTTPClient.METHOD_POST,
		_client_headers(PackedStringArray([USER_AGENT_HEADER, CONTENT_TYPE_HEADER, ACCEPT_HEADER, get_authorization_header()])),
		JSON.stringify({
			"currentPassword": current_password,
			"locale": locale,
			"confirmation": "DELETE",
		}),
		PRIVACY_REQUEST_TIMEOUT_SECONDS
	)
	if bool(response.get("success", false)):
		clear_session()
	return response


func clear_session() -> void:
	var chat_service: Object = get_node_or_null("/root/ChatRealtimeService")
	if chat_service != null and chat_service.has_method("disconnect_chat"):
		chat_service.call("disconnect_chat")

	var world_presence_service: Object = get_node_or_null("/root/WorldPresenceService")
	if world_presence_service != null and world_presence_service.has_method("disconnect_presence"):
		world_presence_service.call("disconnect_presence")

	var trade_realtime_service: Object = get_node_or_null("/root/TradeRealtimeService")
	if trade_realtime_service != null and trade_realtime_service.has_method("clear_active_trade"):
		trade_realtime_service.call("clear_active_trade")
	var trade_service: Object = get_node_or_null("/root/TradeService")
	if trade_service != null and trade_service.has_method("clear_capabilities"):
		trade_service.call("clear_capabilities")
	var pvp_realtime_service: Object = get_node_or_null("/root/PvpBattleRealtimeService")
	if pvp_realtime_service != null and pvp_realtime_service.has_method("disconnect_room"):
		pvp_realtime_service.call("disconnect_room")

	session_token = ""
	expires_at = ""
	current_user.clear()
	session_type = "player"
	impersonated_by_user_id = 0
	account_switch_pending = false
	_reset_account_runtime_state()
	_clear_session_file()


func get_display_name() -> String:
	return str(current_user.get("displayName", current_user.get("username", "")))


func apply_current_user(value: Dictionary) -> void:
	current_user = value.duplicate(true)
	if session_token != "":
		_save_session()


func get_user_id_text() -> String:
	return get_user_id_text_from(current_user)


func get_user_id_text_from(user: Dictionary) -> String:
	for key: String in ["id", "userId", "user_id"]:
		var value: Variant = user.get(key, "")
		var user_id_text: String = str(value).strip_edges()
		if user_id_text != "":
			if user_id_text.is_valid_int():
				return str(int(user_id_text))
			if user_id_text.is_valid_float():
				return str(int(float(user_id_text)))
			return user_id_text
	return ""


func get_created_at_text() -> String:
	for key: String in ["createdAt", "created_at"]:
		var created_at_text: String = str(current_user.get(key, "")).strip_edges()
		if created_at_text != "":
			return created_at_text
	return ""


func get_gender() -> String:
	var gender_text: String = str(current_user.get("gender", "male")).strip_edges().to_lower()
	if gender_text == "female":
		return "female"
	return "male"


func _apply_auth_response(body: Dictionary) -> void:
	session_token = str(body.get("token", ""))
	expires_at = str(body.get("expiresAt", ""))
	current_user = _dictionary_from_value(body.get("user", {}))
	session_type = str(body.get("sessionType", "player")).strip_edges().to_lower()
	if session_type == "":
		session_type = "player"
	var impersonator_id: Variant = body.get("impersonatedByUserId", null)
	impersonated_by_user_id = 0 if impersonator_id == null else int(impersonator_id)


func finish_account_switch() -> void:
	account_switch_pending = false


func _reset_account_runtime_state() -> void:
	ThievingService.clear_state()
	PlayerSave.reset_account_state()
	GameState.reset_gameplay_runtime_state()
	StoryService.reset_story()
	PlayerHotbarService.clear_cached_state()
	PlayerActionService.clear_cached_state()
	WorldTransitionService.clear_cache()
	FieldMoveService.update_owned_charms_from_inventory([])
	PokedexService.invalidate_owned_species_cache()
	var trade_workspace: Object = get_node_or_null("/root/TradeWorkspace")
	if trade_workspace != null and trade_workspace.has_method("clear_account_state"):
		trade_workspace.call("clear_account_state")
	var lending_workspace: Object = get_node_or_null("/root/LendingWorkspace")
	if lending_workspace != null and lending_workspace.has_method("clear_account_state"):
		lending_workspace.call("clear_account_state")


func _refresh_trade_session() -> void:
	var trade_service: Object = get_node_or_null("/root/TradeService")
	if trade_service != null and trade_service.has_method("clear_capabilities"):
		trade_service.call("clear_capabilities")
	var realtime: Object = get_node_or_null("/root/TradeRealtimeService")
	if realtime != null and realtime.has_method("restore_active_trade_and_connect"):
		realtime.call("restore_active_trade_and_connect")


func _request_json(
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: String,
	timeout_seconds: float = REQUEST_TIMEOUT_SECONDS
) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
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

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
		}

	var parsed_body: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _client_headers(headers: PackedStringArray) -> PackedStringArray:
	return ClientBuild.append_http_header(headers)


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _save_session() -> void:
	if session_token == "" or is_impersonating():
		return

	var file := FileAccess.open(SESSION_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("AuthService: could not save session.")
		return

	file.store_string(JSON.stringify({
		"token": session_token,
		"expiresAt": expires_at,
		"user": current_user,
	}))


func _load_session_file() -> Dictionary:
	if not FileAccess.file_exists(SESSION_FILE_PATH):
		return {}

	var file := FileAccess.open(SESSION_FILE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed_body: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_body) != TYPE_DICTIONARY:
		return {}

	return _dictionary_from_value(parsed_body)


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _clear_session_file() -> void:
	if FileAccess.file_exists(SESSION_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE_PATH))


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
