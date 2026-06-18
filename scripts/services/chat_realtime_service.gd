extends Node

class_name ChatRealtimeServiceNode

signal message_received(message: Dictionary)
signal connection_changed(connected: bool)

const RECONNECT_DELAY_SECONDS := 4.0
const MAX_MESSAGE_LENGTH := 300

var websocket: WebSocketPeer = WebSocketPeer.new()
var connected: bool = false
var connecting: bool = false
var should_reconnect: bool = false
var reconnect_timer: float = 0.0


func _process(delta: float) -> void:
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.poll()
		_process_packets()

	var ready_state: int = websocket.get_ready_state()
	var is_connected: bool = ready_state == WebSocketPeer.STATE_OPEN
	if connected != is_connected:
		connected = is_connected
		connection_changed.emit(connected)

	if ready_state == WebSocketPeer.STATE_OPEN:
		connecting = false
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
	if connected:
		connected = false
		connection_changed.emit(false)


func send_chat_message(text: String) -> bool:
	var cleaned_text: String = text.strip_edges()
	if cleaned_text.is_empty():
		return true
	if cleaned_text.length() > MAX_MESSAGE_LENGTH:
		cleaned_text = cleaned_text.substr(0, MAX_MESSAGE_LENGTH)

	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_chat()
		return false

	var payload: Dictionary = {
		"type": "chat",
		"text": cleaned_text,
	}
	var error: Error = websocket.send_text(JSON.stringify(payload))
	return error == OK


func _process_packets() -> void:
	while websocket.get_available_packet_count() > 0:
		var packet: PackedByteArray = websocket.get_packet()
		var parsed_body: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(parsed_body) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = parsed_body
		message_received.emit(message)


func _to_websocket_url(base_url: String) -> String:
	if base_url.begins_with("https://"):
		return "wss://" + base_url.trim_prefix("https://").rstrip("/")
	if base_url.begins_with("http://"):
		return "ws://" + base_url.trim_prefix("http://").rstrip("/")
	return base_url.rstrip("/")
