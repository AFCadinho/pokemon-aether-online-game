extends Node

class_name WorldPresenceServiceNode

signal snapshot_received(players: Array)
signal player_update_received(player_state: Dictionary)
signal player_left_received(user_id: int)
signal connection_changed(connected: bool)
signal session_invalid(reason: String)

const RECONNECT_DELAY_SECONDS := 3.0
const SESSION_CHECK_INTERVAL_SECONDS := 10.0
const SESSION_INVALID_CLOSE_CODE := 1008

var websocket: WebSocketPeer = WebSocketPeer.new()
var connected := false
var connecting := false
var should_reconnect := false
var reconnect_timer := 0.0
var session_check_timer := SESSION_CHECK_INTERVAL_SECONDS
var session_invalid_handled := false
var last_position_payload: Dictionary = {}


func _process(delta: float) -> void:
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.poll()
		_process_packets()

	var ready_state := websocket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_CLOSED:
		_handle_closed_socket()

	var is_connected := ready_state == WebSocketPeer.STATE_OPEN
	if connected != is_connected:
		connected = is_connected
		connection_changed.emit(connected)
		if connected and not last_position_payload.is_empty():
			_send_payload(last_position_payload)

	if ready_state == WebSocketPeer.STATE_OPEN:
		connecting = false
		session_invalid_handled = false
		session_check_timer -= delta
		if session_check_timer <= 0.0:
			session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
			_send_payload({"type": "ping"})
		return

	if ready_state == WebSocketPeer.STATE_CONNECTING:
		return

	connecting = false
	if not should_reconnect or not AuthService.is_authenticated():
		return

	reconnect_timer -= delta
	if reconnect_timer <= 0.0:
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connect_presence()


func connect_presence() -> void:
	if connecting:
		return
	if not AuthService.is_authenticated():
		return

	should_reconnect = true
	connecting = true
	session_invalid_handled = false
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	_connect_presence_async.call_deferred()


func _connect_presence_async() -> void:
	var base_url: String = await GatewayApiConfig.get_base_url()
	if not AuthService.is_authenticated():
		connecting = false
		return

	var websocket_url := _to_websocket_url(base_url) + "/ws/world-presence?token=%s" % AuthService.session_token.uri_encode()
	var error := websocket.connect_to_url(websocket_url)
	if error != OK:
		connecting = false
		connected = false
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connection_changed.emit(false)
		push_warning("WorldPresenceService: could not connect websocket: %s" % error_string(error))


func disconnect_presence() -> void:
	should_reconnect = false
	connecting = false
	last_position_payload.clear()
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	if connected:
		connected = false
		connection_changed.emit(false)


func update_position(state: Dictionary) -> bool:
	var payload := {
		"type": "position",
		"mapId": str(state.get("mapId", "")),
		"mapScenePath": state.get("mapScenePath", null),
		"position": state.get("position", {}),
		"facingDirection": str(state.get("facingDirection", "down")),
		"movement": state.get("movement", {}),
		"follower": state.get("follower", {}),
		"appearance": state.get("appearance", {}),
		"roles": state.get("roles", []),
	}
	last_position_payload = payload
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_presence()
		return false

	return _send_payload(payload)


func _send_payload(payload: Dictionary) -> bool:
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false

	var error := websocket.send_text(JSON.stringify(payload))
	return error == OK


func _handle_closed_socket() -> void:
	if session_invalid_handled:
		return

	var close_code := websocket.get_close_code()
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
		var packet := websocket.get_packet()
		var parsed_body: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(parsed_body) != TYPE_DICTIONARY:
			continue

		var message: Dictionary = parsed_body
		match str(message.get("type", "")):
			"snapshot":
				var players_value: Variant = message.get("players", [])
				var players: Array = players_value if players_value is Array else []
				snapshot_received.emit(players)
			"player_update":
				player_update_received.emit(message)
			"player_left":
				player_left_received.emit(int(message.get("userId", 0)))


func _to_websocket_url(base_url: String) -> String:
	if base_url.begins_with("https://"):
		return "wss://" + base_url.trim_prefix("https://").rstrip("/")
	if base_url.begins_with("http://"):
		return "ws://" + base_url.trim_prefix("http://").rstrip("/")
	return base_url.rstrip("/")
