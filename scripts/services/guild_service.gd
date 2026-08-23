extends Node

class_name GuildServiceNode

signal membership_changed(membership: Dictionary)
signal guild_changed(guild: Dictionary)

const GUILDS_ENDPOINT := "/game/guilds"
const GUILD_HOME_ENDPOINT := "/game/guilds/me"
const GUILD_INVITATIONS_ENDPOINT := "/game/guild-invitations"
const GUILD_LOBBY_TELEPORT_ENDPOINT := "/game/guilds/me/lobby/teleport"
const AETHER_CLASH_CHAMPION_ENDPOINT := "/game/aether-clash/champion"
const REQUEST_TIMEOUT_SECONDS := 8.0

var pending_creation_request_id := ""
var current_membership: Dictionary = {}
var current_guild: Dictionary = {}
var membership_loaded := false


func load_directory() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var response := await _request_json(GUILDS_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	return _directory_result(response.get("body", {}))


func create_guild(
	guild_name: String,
	description: String,
	language: String,
	focus: String,
	recruitment: String
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if pending_creation_request_id == "":
		pending_creation_request_id = _new_request_id()
	var response := await _request_json(
		GUILDS_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"requestId": pending_creation_request_id,
			"name": guild_name.strip_edges(),
			"description": description.strip_edges(),
			"language": language,
			"focus": focus,
			"recruitment": recruitment,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	pending_creation_request_id = ""
	_set_current_membership(body.get("membership", {}))
	_set_current_guild(_normalize_guild(body.get("guild", {})))
	return {
		"success": true,
		"guild": _normalize_guild(body.get("guild", {})),
		"membership": _dictionary(body.get("membership", {})),
		"wallet": _dictionary(body.get("wallet", {})),
	}


func join_guild(guild_id: int) -> Dictionary:
	var response := await _authenticated_request(
		GUILDS_ENDPOINT + "/%d/join" % guild_id,
		HTTPClient.METHOD_POST,
		"{}"
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func apply_to_guild(guild_id: int) -> Dictionary:
	var response := await _authenticated_request(
		GUILDS_ENDPOINT + "/%d/applications" % guild_id,
		HTTPClient.METHOD_POST,
		"{}"
	)
	return response if not bool(response.get("success", false)) else {
		"success": true,
		"application": _dictionary(response.get("body", {})),
	}


func cancel_application(application_id: int) -> Dictionary:
	return await _application_action(
		"/game/guild-applications/%d/cancel" % application_id
	)


func load_home() -> Dictionary:
	var response := await _authenticated_request(GUILD_HOME_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)) and int(response.get("status", 0)) == 404:
		_set_current_membership({})
		_set_current_guild({})
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func teleport_to_lobby() -> Dictionary:
	var response := await _authenticated_request(
		GUILD_LOBBY_TELEPORT_ENDPOINT,
		HTTPClient.METHOD_POST,
		"{}"
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	var state := _dictionary(body.get("state", {}))
	if state.is_empty():
		return {"success": false, "error": "Guild Lobby teleport response was empty."}
	return {
		"success": true,
		"accepted": bool(body.get("accepted", false)),
		"cost": int(body.get("cost", 0)),
		"state": state,
	}


func load_aether_clash_champion() -> Dictionary:
	var response := await _authenticated_request(
		AETHER_CLASH_CHAMPION_ENDPOINT,
		HTTPClient.METHOD_GET,
		""
	)
	if not bool(response.get("success", false)):
		return response
	return normalize_aether_clash_champion(response.get("body", {}))


static func normalize_aether_clash_champion(value: Variant) -> Dictionary:
	var body := value as Dictionary if value is Dictionary else {}
	var guild_id_value: Variant = body.get("guildId")
	var won_at_value: Variant = body.get("wonAt")
	return {
		"success": true,
		"guildId": int(guild_id_value) if guild_id_value != null else 0,
		"guildName": str(body.get("guildName", "")).strip_edges(),
		"wonAt": str(won_at_value) if won_at_value != null else "",
	}


func load_invitations() -> Dictionary:
	var response := await _authenticated_request(
		GUILD_INVITATIONS_ENDPOINT,
		HTTPClient.METHOD_GET,
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"invitations": _array(body.get("invitations", [])).duplicate(true),
	}


func update_settings(
	description: String,
	language: String,
	focus: String,
	recruitment: String
) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/settings",
		HTTPClient.METHOD_PUT,
		JSON.stringify({
			"description": description.strip_edges(),
			"language": language,
			"focus": focus,
			"recruitment": recruitment,
		})
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func update_emblem(palette: Array[String], pixels: Array[int]) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/emblem",
		HTTPClient.METHOD_PUT,
		JSON.stringify({"palette": palette, "pixels": pixels})
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func apply_emblem_template(template_id: String) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/emblem-templates/%s/apply" % template_id.uri_encode(),
		HTTPClient.METHOD_POST,
		"{}"
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func invite_member(username: String) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/invitations",
		HTTPClient.METHOD_POST,
		JSON.stringify({"username": username.strip_edges().to_lower()})
	)
	return response if not bool(response.get("success", false)) else {
		"success": true,
		"invitation": _dictionary(response.get("body", {})),
	}


func accept_invitation(invitation_id: int) -> Dictionary:
	var response := await _authenticated_request(
		"/game/guild-invitations/%d/accept" % invitation_id,
		HTTPClient.METHOD_POST,
		"{}"
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func decline_invitation(invitation_id: int) -> Dictionary:
	return await _invitation_action("/game/guild-invitations/%d/decline" % invitation_id)


func cancel_invitation(invitation_id: int) -> Dictionary:
	return await _invitation_action(GUILD_HOME_ENDPOINT + "/invitations/%d/cancel" % invitation_id)


func accept_application(application_id: int) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/applications/%d/accept" % application_id,
		HTTPClient.METHOD_POST,
		"{}"
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func decline_application(application_id: int) -> Dictionary:
	return await _application_action(
		GUILD_HOME_ENDPOINT + "/applications/%d/decline" % application_id
	)


func abandon_pending_creation() -> void:
	pending_creation_request_id = ""


func _directory_result(value: Variant) -> Dictionary:
	var body := _dictionary(value)
	_set_current_membership(body.get("membership", {}))
	var normalized_guilds: Array[Dictionary] = []
	for guild_value: Variant in _array(body.get("guilds", [])):
		if guild_value is Dictionary:
			normalized_guilds.append(_normalize_guild(guild_value))
	var membership := _dictionary(body.get("membership", {}))
	_set_current_guild(_guild_with_id(normalized_guilds, int(membership.get("guildId", 0))))
	return {
		"success": true,
		"guilds": normalized_guilds,
		"membership": _dictionary(body.get("membership", {})),
		"incomingInvitations": _array(body.get("incomingInvitations", [])),
		"pendingApplications": _array(body.get("pendingApplications", [])),
	}


func _home_result(value: Variant) -> Dictionary:
	var body := _dictionary(value)
	_set_current_membership(body.get("membership", {}))
	_set_current_guild(_normalize_guild(body.get("guild", {})))
	return {
		"success": true,
		"guild": _normalize_guild(body.get("guild", {})),
		"membership": _dictionary(body.get("membership", {})),
		"members": _array(body.get("members", [])),
		"pendingInvitations": _array(body.get("pendingInvitations", [])),
		"pendingApplications": _array(body.get("pendingApplications", [])),
		"emblemTemplates": _array(body.get("emblemTemplates", [])),
	}


func _invitation_action(path: String) -> Dictionary:
	var response := await _authenticated_request(path, HTTPClient.METHOD_POST, "{}")
	return response if not bool(response.get("success", false)) else {
		"success": true,
		"invitation": _dictionary(response.get("body", {})),
	}


func _application_action(path: String) -> Dictionary:
	var response := await _authenticated_request(path, HTTPClient.METHOD_POST, "{}")
	return response if not bool(response.get("success", false)) else {
		"success": true,
		"application": _dictionary(response.get("body", {})),
	}


func can_invite_members() -> bool:
	return str(current_membership.get("role", "")).to_lower() in ["leader", "officer"]


func _set_current_membership(value: Variant) -> void:
	var membership := _dictionary(value).duplicate(true)
	var was_loaded := membership_loaded
	membership_loaded = true
	if current_membership == membership and was_loaded:
		return
	current_membership = membership
	membership_changed.emit(current_membership.duplicate(true))


func _set_current_guild(value: Variant) -> void:
	var guild := _dictionary(value).duplicate(true)
	if current_guild == guild:
		return
	current_guild = guild
	guild_changed.emit(current_guild.duplicate(true))


func _guild_with_id(guilds: Array[Dictionary], guild_id: int) -> Dictionary:
	if guild_id <= 0:
		return {}
	for guild: Dictionary in guilds:
		if int(guild.get("id", 0)) == guild_id:
			return guild
	return {}


func _authenticated_request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	return await _request_json(path, method, body)


func _normalize_guild(value: Variant) -> Dictionary:
	var guild := _dictionary(value).duplicate(true)
	guild["members"] = maxi(int(guild.get("memberCount", guild.get("members", 0))), 0)
	guild.erase("memberCount")
	return guild


func _request_json(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers := GatewayApiConfig.get_accept_headers() if method == HTTPClient.METHOD_GET else GatewayApiConfig.get_json_headers()
	var error := request.request(base_url + path, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var completed: Array = await request.request_completed
	request.queue_free()
	var request_result := int(completed[0])
	var response_code := int(completed[1])
	var response_text := (completed[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary(parsed)
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": _request_result_message(request_result)}
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _error_message(response_body, response_code),
			"body": response_body,
		}
	return {"success": true, "status": response_code, "body": response_body}


func _error_message(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)


func _new_request_id() -> String:
	return "guild-%s-%s" % [Time.get_ticks_usec(), randi()]


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
