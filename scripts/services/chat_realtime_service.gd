extends Node

class_name ChatRealtimeServiceNode

signal message_received(message: Dictionary)
signal private_message_received(message: Dictionary)
signal mail_received(mail_id: int)
signal friend_request_received(request: Dictionary)
signal authorized_teleport_received(state: Dictionary, reason: String)
signal connection_changed(connected: bool)
signal session_invalid(reason: String)

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
	if connecting:
		return
	if not AuthService.is_authenticated():
		return

	should_reconnect = true
	connecting = true
	session_invalid_handled = false
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	_connect_chat_async.call_deferred()


func _connect_chat_async() -> void:
	var base_url: String = await GatewayApiConfig.get_base_url()
	if not AuthService.is_authenticated():
		connecting = false
		return

	var websocket_url: String = _to_websocket_url(base_url) + "/ws/chat?token=%s" % AuthService.session_token.uri_encode()
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
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	websocket = WebSocketPeer.new()
	session_invalid_handled = false
	reconnect_timer = 0.0
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	if connected:
		connected = false
		connection_changed.emit(false)


func send_chat_message(text: String, channel: String = "global", pokemon_attachments: Array = []) -> bool:
	var cleaned_text: String = text.strip_edges()
	if cleaned_text.is_empty() and pokemon_attachments.is_empty():
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
	var error: Error = websocket.send_text(JSON.stringify(payload))
	return error == OK


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
