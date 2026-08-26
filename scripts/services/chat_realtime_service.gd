extends Node

class_name ChatRealtimeServiceNode

const ClientBuild := preload("res://scripts/services/client_build.gd")
signal message_received(message: Dictionary)
signal private_message_received(message: Dictionary)
signal mail_received(mail_id: int)
signal friend_request_received(request: Dictionary)
signal authorized_teleport_received(state: Dictionary, reason: String)
signal connection_changed(connected: bool)
signal session_invalid(reason: String)
signal translation_state_changed(available: bool, allowed: bool, enabled: bool)
signal translation_warning(message: String)
signal ai_translation_received(message_id: String, translated_text: String)
signal ai_translation_failed(message_id: String, message: String)
signal pm_translation_state_changed(peer_user_id: int, language: String, allowed: bool)
signal pm_translation_warning(peer_user_id: int, message: String)

const RECONNECT_DELAY_SECONDS := 4.0
const SESSION_CHECK_INTERVAL_SECONDS := 10.0
const SESSION_INVALID_CLOSE_CODE := 1008
const MAX_MESSAGE_LENGTH := 300

var websocket: WebSocketPeer = WebSocketPeer.new()
var connected: bool = false
var connecting: bool = false
var should_reconnect: bool = false
var reconnect_timer: float = 0.0
var session_check_timer: float = SESSION_CHECK_INTERVAL_SECONDS
var session_invalid_handled: bool = false
var connection_attempt_generation := 0
var translation_mode_requested := false
var translation_mode_available := false
var ai_translation_available := false
var translation_mode_allowed := false
var translation_mode_enabled := false
var pm_translation_languages: Array[String] = []


func _process(delta: float) -> void:
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.poll()
		_process_packets()

	var ready_state: int = websocket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_CLOSED:
		_handle_closed_socket()

	var is_connected: bool = ready_state == WebSocketPeer.STATE_OPEN
	if connected != is_connected:
		connected = is_connected
		connection_changed.emit(connected)
		if connected:
			_send_translation_mode_request()
		else:
			translation_mode_enabled = false

	if ready_state == WebSocketPeer.STATE_OPEN:
		connecting = false
		session_invalid_handled = false
		session_check_timer -= delta
		if session_check_timer <= 0.0:
			session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
			_send_session_check()
		return

	if ready_state == WebSocketPeer.STATE_CONNECTING:
		return

	connecting = false
	if not should_reconnect or not AuthService.is_authenticated():
		return

	reconnect_timer -= delta
	if reconnect_timer <= 0.0:
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connect_chat()


func connect_chat() -> void:
	if not AuthService.is_authenticated():
		return

	should_reconnect = true
	var ready_state := websocket.get_ready_state()
	if connecting or ready_state != WebSocketPeer.STATE_CLOSED:
		return
	connecting = true
	session_invalid_handled = false
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	connection_attempt_generation += 1
	_connect_chat_async.call_deferred(connection_attempt_generation)


func _connect_chat_async(attempt_generation: int) -> void:
	var base_url: String = await GatewayApiConfig.get_base_url()
	if attempt_generation != connection_attempt_generation:
		return
	if not AuthService.is_authenticated():
		connecting = false
		return
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		connecting = websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING
		return

	var websocket_url: String = ClientBuild.append_websocket_query(
		_to_websocket_url(base_url) + "/ws/chat?token=%s" % AuthService.session_token.uri_encode()
	)
	var error: Error = websocket.connect_to_url(websocket_url)
	if error != OK:
		connecting = false
		connected = false
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connection_changed.emit(false)
		push_warning("ChatRealtimeService: could not connect websocket: %s" % error_string(error))


func disconnect_chat() -> void:
	should_reconnect = false
	connecting = false
	connection_attempt_generation += 1
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	websocket = WebSocketPeer.new()
	session_invalid_handled = false
	reconnect_timer = 0.0
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	if connected:
		connected = false
		connection_changed.emit(false)


func send_chat_message(
	text: String,
	channel: String = "global",
	pokemon_attachments: Array = [],
	shiny_hunt_share_id: String = ""
) -> bool:
	var cleaned_text: String = text.strip_edges()
	if cleaned_text.is_empty() and pokemon_attachments.is_empty() and shiny_hunt_share_id.is_empty():
		return true
	if cleaned_text.length() > MAX_MESSAGE_LENGTH:
		cleaned_text = cleaned_text.substr(0, MAX_MESSAGE_LENGTH)

	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_chat()
		return false

	var payload: Dictionary = {
		"type": "chat",
		"channel": channel,
		"text": cleaned_text,
	}
	if not pokemon_attachments.is_empty():
		payload["pokemonAttachments"] = pokemon_attachments
	if not shiny_hunt_share_id.is_empty():
		payload["shinyHuntShareId"] = shiny_hunt_share_id
	var error: Error = websocket.send_text(JSON.stringify(payload))
	return error == OK


func set_translation_mode_requested(enabled: bool) -> void:
	translation_mode_requested = enabled
	_send_translation_mode_request()


func request_ai_translation(message_id: String) -> bool:
	var normalized_message_id := message_id.strip_edges()
	if (
		not translation_mode_enabled
		or not ai_translation_available
		or normalized_message_id.length() != 36
		or websocket.get_ready_state() != WebSocketPeer.STATE_OPEN
	):
		return false
	return websocket.send_text(JSON.stringify({
		"type": "chat_translation.ai_request",
		"messageId": normalized_message_id,
	})) == OK


func set_private_message_translation_language(peer_user_id: int, language: String) -> bool:
	var normalized_language := language.strip_edges().to_lower()
	if (
		not translation_mode_enabled
		or peer_user_id <= 0
		or (normalized_language != "" and not pm_translation_languages.has(normalized_language))
		or websocket.get_ready_state() != WebSocketPeer.STATE_OPEN
	):
		return false
	return websocket.send_text(JSON.stringify({
		"type": "chat_translation.pm_set",
		"peerUserId": peer_user_id,
		"language": normalized_language,
	})) == OK


func _send_translation_mode_request() -> void:
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var payload: Dictionary = {
		"type": "chat_translation.set",
		"enabled": translation_mode_requested,
	}
	var error := websocket.send_text(JSON.stringify(payload))
	if error != OK:
		translation_warning.emit("Translation mode could not be updated.")


func _send_session_check() -> void:
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var payload: Dictionary = {
		"type": "ping",
	}
	var error: Error = websocket.send_text(JSON.stringify(payload))
	if error != OK:
		push_warning("ChatRealtimeService: could not send session check: %s" % error_string(error))


func _handle_closed_socket() -> void:
	if session_invalid_handled:
		return

	var close_code: int = websocket.get_close_code()
	if close_code != SESSION_INVALID_CLOSE_CODE:
		return
	if not AuthService.is_authenticated():
		return

	session_invalid_handled = true
	should_reconnect = false
	connecting = false
	session_invalid.emit("Your session is no longer valid.")


func _process_packets() -> void:
	while websocket.get_available_packet_count() > 0:
		var packet: PackedByteArray = websocket.get_packet()
		var parsed_body: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(parsed_body) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = parsed_body
		var message_type: String = str(message.get("type", "")).to_lower().strip_edges()
		if message_type == "chat_translation.state":
			translation_mode_available = bool(message.get("available", false))
			ai_translation_available = bool(message.get("aiAvailable", false))
			translation_mode_allowed = bool(message.get("allowed", false))
			translation_mode_enabled = bool(message.get("enabled", false))
			pm_translation_languages.clear()
			var raw_pm_languages: Variant = message.get("pmLanguages", [])
			if raw_pm_languages is Array:
				for language_value: Variant in raw_pm_languages:
					var language := str(language_value).strip_edges().to_lower()
					if language != "" and not pm_translation_languages.has(language):
						pm_translation_languages.append(language)
			if not translation_mode_enabled and translation_mode_requested:
				translation_mode_requested = false
			translation_state_changed.emit(
				translation_mode_available,
				translation_mode_allowed,
				translation_mode_enabled
			)
			continue
		if message_type == "chat_translation.ai_result":
			ai_translation_received.emit(
				str(message.get("messageId", "")).strip_edges(),
				str(message.get("translatedText", "")).strip_edges()
			)
			continue
		if message_type == "chat_translation.ai_error":
			ai_translation_failed.emit(
				str(message.get("messageId", "")).strip_edges(),
				str(message.get("message", "AI translation is unavailable."))
			)
			continue
		if message_type == "chat_translation.pm_state":
			pm_translation_state_changed.emit(
				int(message.get("peerUserId", 0)),
				str(message.get("language", "")).strip_edges().to_lower(),
				bool(message.get("allowed", false))
			)
			continue
		if message_type == "chat_translation.pm_warning":
			pm_translation_warning.emit(
				int(message.get("peerUserId", 0)),
				str(message.get("message", "Private-message translation is unavailable."))
			)
			continue
		if message_type == "chat_translation.warning":
			translation_warning.emit(str(message.get("message", "Translation was unavailable.")))
			continue
		if message_type == "private_message.received":
			private_message_received.emit(message)
			continue
		if message_type == "mail.received":
			var mail_id: int = int(message.get("mailId", message.get("mail_id", -1)))
			if mail_id > 0:
				mail_received.emit(mail_id)
			continue
		if message_type == "friend_request.received":
			friend_request_received.emit(_dictionary_from_value(message.get("request", {})))
			continue
		if message_type == "world.teleport.authorized":
			authorized_teleport_received.emit(
				_dictionary_from_value(message.get("state", {})),
				str(message.get("reason", ""))
			)
			continue
		message_received.emit(message)


func _to_websocket_url(base_url: String) -> String:
	if base_url.begins_with("https://"):
		return "wss://" + base_url.trim_prefix("https://").rstrip("/")
	if base_url.begins_with("http://"):
		return "ws://" + base_url.trim_prefix("http://").rstrip("/")
	return base_url.rstrip("/")


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary
