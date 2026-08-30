extends Node

class_name GuildServiceNode

signal membership_changed(membership: Dictionary)
signal guild_changed(guild: Dictionary)
signal notification_received(notification: Dictionary)

const GUILDS_ENDPOINT := "/game/guilds"
const GUILD_HOME_ENDPOINT := "/game/guilds/me"
const GUILD_BANK_ENDPOINT := "/game/guilds/me/bank"
const GUILD_INVITATIONS_ENDPOINT := "/game/guild-invitations"
const GUILD_NOTIFICATIONS_ENDPOINT := "/game/guild-notifications"
const GUILD_LOBBY_TELEPORT_ENDPOINT := "/game/guilds/me/lobby/teleport"
const AETHER_CLASH_CHAMPION_ENDPOINT := "/game/aether-clash/champion"
const AETHER_CLASH_CHALLENGES_ENDPOINT := "/game/aether-clash/challenges"
const AETHER_CLASH_PLAYER_CHALLENGES_ENDPOINT := "/game/aether-clash/player-challenges"
const AETHER_CLASH_PORTAL_SESSIONS_ENDPOINT := "/game/aether-clash/portal-sessions"
const AETHER_CLASH_SESSIONS_ENDPOINT := "/game/aether-clash/sessions"
const REQUEST_TIMEOUT_SECONDS := 8.0

var pending_creation_request_id := ""
var current_membership: Dictionary = {}
var current_guild: Dictionary = {}
var membership_loaded := false
var notification_poll_in_flight := false
var delivered_notification_ids: Dictionary = {}


func _ready() -> void:
	var timer := Timer.new()
	timer.name = "GuildNotificationPollTimer"
	timer.wait_time = 60.0
	timer.autostart = true
	timer.timeout.connect(_poll_notifications)
	add_child(timer)


func load_directory() -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var response := await _request_json(GUILDS_ENDPOINT, HTTPClient.METHOD_GET, "")
	if not bool(response.get("success", false)):
		return response
	_poll_notifications.call_deferred()
	return _directory_result(response.get("body", {}))


func deliver_notification(notification: Dictionary) -> void:
	var notification_id := int(notification.get("id", 0))
	if notification_id <= 0 or delivered_notification_ids.has(notification_id):
		return
	delivered_notification_ids[notification_id] = true
	notification_received.emit(notification.duplicate(true))
	await _acknowledge_notification(notification_id)


func _poll_notifications() -> void:
	if notification_poll_in_flight or not AuthService.is_authenticated():
		return
	notification_poll_in_flight = true
	var response := await _authenticated_request(
		GUILD_NOTIFICATIONS_ENDPOINT + "/pending?limit=20",
		HTTPClient.METHOD_GET,
		""
	)
	notification_poll_in_flight = false
	if not bool(response.get("success", false)):
		return
	var body := _dictionary(response.get("body", {}))
	for value: Variant in _array(body.get("notifications", [])):
		if value is Dictionary:
			await deliver_notification(value as Dictionary)


func _acknowledge_notification(notification_id: int) -> void:
	var response := await _authenticated_request(
		GUILD_NOTIFICATIONS_ENDPOINT + "/%d/ack" % notification_id,
		HTTPClient.METHOD_POST,
		"{}"
	)
	if not bool(response.get("success", false)):
		delivered_notification_ids.erase(notification_id)


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


func leave_guild() -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/leave",
		HTTPClient.METHOD_POST,
		"{}"
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	_set_current_membership({})
	_set_current_guild({})
	return {
		"success": true,
		"left": bool(body.get("left", false)),
		"guildId": int(body.get("guildId", 0)),
		"guildName": str(body.get("guildName", "")),
	}


func load_bank() -> Dictionary:
	var response := await _authenticated_request(GUILD_BANK_ENDPOINT, HTTPClient.METHOD_GET, "")
	return response if not bool(response.get("success", false)) else _bank_result(response.get("body", {}))


func load_history(before_id: int = 0, search: String = "", action: String = "", date_from: String = "", date_to: String = "") -> Dictionary:
	var path := GUILD_HOME_ENDPOINT + "/history?limit=50"
	if before_id > 0:
		path += "&beforeId=%d" % before_id
	if search.strip_edges() != "":
		path += "&search=%s" % search.strip_edges().uri_encode()
	if action.strip_edges() != "":
		path += "&action=%s" % action.strip_edges().uri_encode()
	if date_from.strip_edges() != "":
		path += "&dateFrom=%s" % date_from.strip_edges().uri_encode()
	if date_to.strip_edges() != "":
		path += "&dateTo=%s" % date_to.strip_edges().uri_encode()
	var response := await _authenticated_request(path, HTTPClient.METHOD_GET, "")
	return response if not bool(response.get("success", false)) else _log_result(response.get("body", {}))


func load_bank_log(category: String, before_id: int = 0, search: String = "", action: String = "", date_from: String = "", date_to: String = "") -> Dictionary:
	var normalized := category.strip_edges().to_lower()
	if not normalized in ["funds", "items", "pokemon", "resources"]:
		return {"success": false, "error": "Unknown Guild Bank log."}
	var path := GUILD_BANK_ENDPOINT + "/logs/%s?limit=50" % normalized
	if before_id > 0:
		path += "&beforeId=%d" % before_id
	if search.strip_edges() != "":
		path += "&search=%s" % search.strip_edges().uri_encode()
	if action.strip_edges() != "":
		path += "&action=%s" % action.strip_edges().uri_encode()
	if date_from.strip_edges() != "":
		path += "&dateFrom=%s" % date_from.strip_edges().uri_encode()
	if date_to.strip_edges() != "":
		path += "&dateTo=%s" % date_to.strip_edges().uri_encode()
	var response := await _authenticated_request(path, HTTPClient.METHOD_GET, "")
	return response if not bool(response.get("success", false)) else _log_result(response.get("body", {}))


func deposit_bank_money(amount: int) -> Dictionary:
	return await _bank_action("/money/deposit", {"amount": amount})


func withdraw_bank_money(amount: int) -> Dictionary:
	return await _bank_action("/money/withdraw", {"amount": amount})


func deposit_bank_item(item_id: String, quantity: int) -> Dictionary:
	return await _bank_action("/items/deposit", {"itemId": item_id, "quantity": quantity})


func withdraw_bank_item(item_id: String, quantity: int) -> Dictionary:
	return await _bank_action("/items/withdraw", {"itemId": item_id, "quantity": quantity})


func deposit_bank_resource(item_id: String, quantity: int) -> Dictionary:
	return await _bank_action("/resources/deposit", {"itemId": item_id, "quantity": quantity})


func withdraw_bank_resource(item_id: String, quantity: int) -> Dictionary:
	return await _bank_action("/resources/withdraw", {"itemId": item_id, "quantity": quantity})


func borrow_bank_item(item_id: String, quantity: int) -> Dictionary:
	return await _bank_action("/items/borrow", {
		"itemId": item_id,
		"quantity": quantity,
		"requestId": _new_request_id(),
	})


func deposit_bank_pokemon(pokemon_id: int) -> Dictionary:
	return await _bank_action("/pokemon/deposit", {"pokemonId": pokemon_id})


func withdraw_bank_pokemon(pokemon_id: int) -> Dictionary:
	return await _bank_action("/pokemon/withdraw", {"pokemonId": pokemon_id})


func borrow_bank_pokemon(pokemon_id: int) -> Dictionary:
	return await _bank_action("/pokemon/borrow", {
		"pokemonId": pokemon_id,
		"requestId": _new_request_id(),
	})


func return_bank_loan_asset(asset_id: String) -> Dictionary:
	return await _bank_action("/loans/return", {
		"assetId": asset_id,
		"requestId": _new_request_id(),
	})


func force_return_bank_loan_asset(asset_id: String) -> Dictionary:
	return await _bank_action("/loans/force-return", {
		"assetId": asset_id,
		"requestId": _new_request_id(),
	})


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


func load_aether_clash_challenges() -> Dictionary:
	var response := await _authenticated_request(
		AETHER_CLASH_CHALLENGES_ENDPOINT,
		HTTPClient.METHOD_GET,
		""
	)
	return (
		response
		if not bool(response.get("success", false))
		else _aether_clash_challenges_result(response.get("body", {}))
	)


func create_aether_clash_challenge(
	challenged_guild_id: int,
	spectator_access := "public"
) -> Dictionary:
	var response := await _authenticated_request(
		AETHER_CLASH_CHALLENGES_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"challengedGuildId": challenged_guild_id,
			"spectatorAccess": spectator_access,
		})
	)
	return _aether_clash_action_result(response)


func create_aether_clash_player_challenge(
	target_user_id: int,
	spectator_access := "public"
) -> Dictionary:
	if target_user_id <= 0:
		return {"success": false, "error": "Aether Clash target was missing."}
	var response := await _authenticated_request(
		AETHER_CLASH_PLAYER_CHALLENGES_ENDPOINT,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"targetUserId": target_user_id,
			"spectatorAccess": spectator_access,
		})
	)
	return _aether_clash_action_result(response)


func load_aether_clash_portal_sessions() -> Dictionary:
	var response := await _authenticated_request(
		AETHER_CLASH_PORTAL_SESSIONS_ENDPOINT,
		HTTPClient.METHOD_GET,
		""
	)
	if not bool(response.get("success", false)):
		return response
	var sessions: Array[Dictionary] = []
	var body := _dictionary(response.get("body", {}))
	for value: Variant in _array(body.get("sessions", [])):
		if not value is Dictionary:
			continue
		var item := (value as Dictionary).duplicate(true)
		item["session"] = _normalize_aether_clash_session(item.get("session", {}))
		sessions.append(item)
	return {"success": true, "sessions": sessions}


func enter_aether_clash_portal(challenge_id: String) -> Dictionary:
	var normalized_id := challenge_id.strip_edges()
	if normalized_id.is_empty():
		return {"success": false, "error": "Aether Clash session was missing."}
	var response := await _authenticated_request(
		AETHER_CLASH_PORTAL_SESSIONS_ENDPOINT + "/%s/enter" % normalized_id.uri_encode(),
		HTTPClient.METHOD_POST,
		"{}"
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"role": str(body.get("role", "spectator")),
		"session": _normalize_aether_clash_session(body.get("session", {})),
		"state": _dictionary(body.get("state", {})).duplicate(true),
	}


func load_aether_clash_arena_state(challenge_id: String) -> Dictionary:
	var normalized_id := challenge_id.strip_edges()
	if normalized_id.is_empty():
		return {"success": false, "error": "Aether Clash session was missing."}
	var response := await _authenticated_request(
		AETHER_CLASH_SESSIONS_ENDPOINT + "/%s/arena-state" % normalized_id.uri_encode(),
		HTTPClient.METHOD_GET,
		""
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"session": _normalize_aether_clash_session(body.get("session", {})),
		"viewerRole": str(body.get("viewerRole", "spectator")),
		"viewerSide": str(body.get("viewerSide", "")),
		"arenaPlayers": _array(body.get("arenaPlayers", [])).duplicate(true),
		"serverNow": str(body.get("serverNow", "")),
	}


func create_aether_clash_engagement(
	challenge_id: String,
	target_user_id: int,
	method: String = "player_contact"
) -> Dictionary:
	var normalized_id := challenge_id.strip_edges()
	var normalized_method := method.strip_edges().to_lower()
	if normalized_id.is_empty() or target_user_id <= 0:
		return {"success": false, "error": "Aether Clash engagement was missing."}
	if normalized_method not in ["player_contact", "projectile"]:
		normalized_method = "player_contact"
	var response := await _authenticated_request(
		AETHER_CLASH_SESSIONS_ENDPOINT + "/%s/engagements" % normalized_id.uri_encode(),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"targetUserId": target_user_id,
			"method": normalized_method,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var engagement := _dictionary(response.get("body", {})).duplicate(true)
	engagement["success"] = true
	return engagement


func leave_aether_clash_arena(challenge_id: String) -> Dictionary:
	var normalized_id := challenge_id.strip_edges()
	if normalized_id.is_empty():
		return {"success": false, "error": "Aether Clash session was missing."}
	var response := await _authenticated_request(
		AETHER_CLASH_SESSIONS_ENDPOINT + "/%s/leave" % normalized_id.uri_encode(),
		HTTPClient.METHOD_POST,
		"{}"
	)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary(response.get("body", {}))
	return {
		"success": true,
		"session": _normalize_aether_clash_session(body.get("session", {})),
		"state": _dictionary(body.get("state", {})).duplicate(true),
	}


func accept_aether_clash_challenge(challenge_id: String) -> Dictionary:
	return await _aether_clash_action(challenge_id, "accept")


func decline_aether_clash_challenge(challenge_id: String) -> Dictionary:
	return await _aether_clash_action(challenge_id, "decline")


func cancel_aether_clash_challenge(challenge_id: String) -> Dictionary:
	return await _aether_clash_action(challenge_id, "cancel")


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
	announcement: String,
	language: String,
	focus: String,
	recruitment: String,
	loan_duration_seconds: int = 3600,
	requirements: Array = []
) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/settings",
		HTTPClient.METHOD_PUT,
		JSON.stringify({
			"description": description.strip_edges(),
			"announcement": announcement.strip_edges(),
			"language": language,
			"focus": focus,
			"recruitment": recruitment,
			"loanDurationSeconds": loan_duration_seconds,
			"requirements": requirements,
		})
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func update_member_role(user_id: int, role: String) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/members/%d/role" % user_id,
		HTTPClient.METHOD_PUT,
		JSON.stringify({"role": role.strip_edges().to_lower()})
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func kick_member(user_id: int) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/members/%d" % user_id,
		HTTPClient.METHOD_DELETE,
		""
	)
	return response if not bool(response.get("success", false)) else _home_result(response.get("body", {}))


func update_member_bank_permissions(user_id: int, overrides: Dictionary) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_HOME_ENDPOINT + "/members/%d/bank-permissions" % user_id,
		HTTPClient.METHOD_PUT,
		JSON.stringify({"overrides": overrides})
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
		"announcement": str(body.get("announcement", "")),
		"incomingInvitations": _array(body.get("incomingInvitations", [])),
		"pendingApplications": _array(body.get("pendingApplications", [])),
		"applicationCooldowns": _array(body.get("applicationCooldowns", [])),
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
		"rankPermissions": _dictionary(body.get("rankPermissions", {})),
	}


func _aether_clash_challenges_result(value: Variant) -> Dictionary:
	var body := _dictionary(value)
	var incoming: Array[Dictionary] = []
	for challenge_value: Variant in _array(body.get("pendingIncoming", [])):
		if challenge_value is Dictionary:
			incoming.append(_normalize_aether_clash_session(challenge_value))
	var outgoing: Array[Dictionary] = []
	for challenge_value: Variant in _array(body.get("pendingOutgoing", [])):
		if challenge_value is Dictionary:
			outgoing.append(_normalize_aether_clash_session(challenge_value))
	var current_session := _normalize_aether_clash_session(body.get("currentSession", {}))
	var stats := _dictionary(body.get("duelStats", {})).duplicate(true)
	stats["wins"] = int(stats.get("wins", 0))
	stats["losses"] = int(stats.get("losses", 0))
	stats["noContests"] = int(stats.get("noContests", 0))
	stats["totalMatches"] = int(stats.get("totalMatches", 0))
	stats["decidedMatches"] = int(stats.get("decidedMatches", 0))
	stats["winRate"] = float(stats.get("winRate", 0.0))
	var history: Array[Dictionary] = []
	for history_value: Variant in _array(body.get("duelHistory", [])):
		if not history_value is Dictionary:
			continue
		var entry := (history_value as Dictionary).duplicate(true)
		entry["opponentGuild"] = _dictionary(entry.get("opponentGuild", {})).duplicate(true)
		entry["participantCounts"] = _dictionary(entry.get("participantCounts", {})).duplicate(true)
		entry["remainingCounts"] = _dictionary(entry.get("remainingCounts", {})).duplicate(true)
		history.append(entry)
	return {
		"success": true,
		"canManage": bool(body.get("canManage", false)),
		"pendingIncoming": incoming,
		"pendingOutgoing": outgoing,
		"currentSession": current_session,
		"duelStats": stats,
		"duelHistory": history,
	}


func _aether_clash_action(challenge_id: String, action: String) -> Dictionary:
	var normalized_id := challenge_id.strip_edges()
	if normalized_id == "":
		return {"success": false, "error": "Aether Clash challenge was missing."}
	var response := await _authenticated_request(
		AETHER_CLASH_CHALLENGES_ENDPOINT + "/%s/%s" % [normalized_id.uri_encode(), action],
		HTTPClient.METHOD_POST,
		"{}"
	)
	return _aether_clash_action_result(response)


func _aether_clash_action_result(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	return {
		"success": true,
		"challenge": _normalize_aether_clash_session(response.get("body", {})),
	}


func _normalize_aether_clash_session(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var challenge := (value as Dictionary).duplicate(true)
	challenge["challengerGuild"] = _dictionary(challenge.get("challengerGuild", {})).duplicate(true)
	challenge["challengedGuild"] = _dictionary(challenge.get("challengedGuild", {})).duplicate(true)
	return challenge


func _bank_action(path: String, payload: Dictionary) -> Dictionary:
	var response := await _authenticated_request(
		GUILD_BANK_ENDPOINT + path,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	return response if not bool(response.get("success", false)) else _bank_result(response.get("body", {}))


func _bank_result(value: Variant) -> Dictionary:
	var body := _dictionary(value)
	return {
		"success": true,
		"guildId": int(body.get("guildId", 0)),
		"itemCapacity": int(body.get("itemCapacity", 50)),
		"pokemonCapacity": int(body.get("pokemonCapacity", 30)),
		"access": _dictionary(body.get("access", {})).duplicate(true),
		"funds": _dictionary(body.get("funds", {})).duplicate(true),
		"loanUsage": _dictionary(body.get("loanUsage", {})).duplicate(true),
		"items": _array(body.get("items", [])).duplicate(true),
		"inventory": _array(body.get("inventory", [])).duplicate(true),
		"resources": _array(body.get("resources", [])).duplicate(true),
		"resourceInventory": _array(body.get("resourceInventory", [])).duplicate(true),
		"pokemon": _array(body.get("pokemon", [])).duplicate(true),
		"depositablePokemon": _array(body.get("depositablePokemon", [])).duplicate(true),
		"party": _array(_dictionary(body.get("party", {})).get("party", [])).duplicate(true),
		"loanDurationSeconds": int(body.get("loanDurationSeconds", 3600)),
		"borrowedItems": _array(body.get("borrowedItems", [])).duplicate(true),
	}


func _log_result(value: Variant) -> Dictionary:
	var body := _dictionary(value)
	var next_before_id: Variant = body.get("nextBeforeId")
	return {
		"success": true,
		"category": str(body.get("category", "")),
		"entries": _array(body.get("entries", [])).duplicate(true),
		"nextBeforeId": int(next_before_id) if next_before_id != null else 0,
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
	var permissions := _array(current_membership.get("permissions", []))
	return permissions.has("manage_members") or str(current_membership.get("role", "")).to_lower() in ["leader", "captain"]


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
