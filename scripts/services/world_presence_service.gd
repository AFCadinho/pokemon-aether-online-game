extends Node

class_name WorldPresenceServiceNode

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")

signal snapshot_received(players: Array)
signal player_update_received(player_state: Dictionary)
signal player_left_received(user_id: int)
signal connection_changed(connected: bool)
signal session_invalid(reason: String)

const RECONNECT_DELAY_SECONDS := 3.0
const SESSION_CHECK_INTERVAL_SECONDS := 10.0
const SESSION_INVALID_CLOSE_CODE := 1008
const DEBUG_PLAYER_UPDATE_PAYLOADS := false
const PLAYER_UPDATE_LOG_PATH := "user://world_presence_player_update.log"

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
	websocket = WebSocketPeer.new()
	session_invalid_handled = false
	reconnect_timer = 0.0
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	if connected:
		connected = false
		connection_changed.emit(false)


func update_position(state: Dictionary) -> bool:
	var appearance_value: Variant = state.get("appearance", {})
	var appearance: Dictionary = appearance_value if appearance_value is Dictionary else {}
	var presence_body: String = CharacterAppearanceService.get_presence_body_base_id(str(appearance.get("body", "")))
	var appearance_payload: Dictionary = _build_appearance_payload(appearance)
	appearance_payload["body"] = presence_body
	var movement_payload: Dictionary = _build_movement_payload(state.get("movement", {}), appearance_payload, presence_body, appearance)
	var payload := {
		"type": "position",
		"mapId": str(state.get("mapId", "")),
		"mapScenePath": state.get("mapScenePath", null),
		"gender": str(state.get("gender", "male")),
		"position": state.get("position", {}),
		"facingDirection": str(state.get("facingDirection", "down")),
		"movement": movement_payload,
		"follower": state.get("follower", {}),
		"appearance": appearance_payload,
		"roles": state.get("roles", []),
		"selectedRoleBadge": str(state.get("selectedRoleBadge", "")),
		"appearanceBody": presence_body,
		"appearanceHair": str(appearance.get("hair", "")),
		"appearanceHairStyleIndex": int(appearance.get("hair_style_index", 0)),
		"appearanceHeadgear": str(appearance.get("headgear", "")),
		"appearanceFacegear": str(appearance.get("facegear", "")),
		"appearanceTop": str(appearance.get("top", "")),
		"appearanceBottom": str(appearance.get("bottom", "")),
		"appearanceShoes": str(appearance.get("shoes", "")),
		"appearanceHairColor": str(appearance.get("hair_color", "")),
		"appearanceSkinTone": str(appearance.get("skin_tone", "")),
		"appearanceEyeColor": str(appearance.get("eye_color", "")),
		"body": presence_body,
		"hair": str(appearance.get("hair", "")),
		"hair_style_index": int(appearance.get("hair_style_index", 0)),
		"hairStyleIndex": int(appearance.get("hair_style_index", 0)),
		"headgear": str(appearance.get("headgear", "")),
		"facegear": str(appearance.get("facegear", "")),
		"top": str(appearance.get("top", "")),
		"bottom": str(appearance.get("bottom", "")),
		"shoes": str(appearance.get("shoes", "")),
		"hair_color": str(appearance.get("hair_color", "")),
		"hairColor": str(appearance.get("hair_color", "")),
		"skin_tone": str(appearance.get("skin_tone", "")),
		"skinTone": str(appearance.get("skin_tone", "")),
		"eye_color": str(appearance.get("eye_color", "")),
		"eyeColor": str(appearance.get("eye_color", "")),
	}
	last_position_payload = payload
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_presence()
		return false

	return _send_payload(payload)


func _build_appearance_payload(appearance: Dictionary) -> Dictionary:
	var payload: Dictionary = appearance.duplicate()
	payload["hairStyleIndex"] = int(appearance.get("hair_style_index", 0))
	payload["hairColor"] = str(appearance.get("hair_color", ""))
	payload["skinTone"] = str(appearance.get("skin_tone", ""))
	payload["eyeColor"] = str(appearance.get("eye_color", ""))
	return payload


func _build_movement_payload(movement_value: Variant, appearance_payload: Dictionary, presence_body: String, appearance: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	if movement_value is Dictionary:
		var movement_dictionary: Dictionary = movement_value as Dictionary
		payload = movement_dictionary.duplicate()
	payload["appearance"] = appearance_payload
	payload["appearanceBody"] = presence_body
	payload["appearanceHair"] = str(appearance.get("hair", ""))
	payload["appearanceHairStyleIndex"] = int(appearance.get("hair_style_index", 0))
	payload["appearanceHeadgear"] = str(appearance.get("headgear", ""))
	payload["appearanceFacegear"] = str(appearance.get("facegear", ""))
	payload["appearanceTop"] = str(appearance.get("top", ""))
	payload["appearanceBottom"] = str(appearance.get("bottom", ""))
	payload["appearanceShoes"] = str(appearance.get("shoes", ""))
	payload["appearanceHairColor"] = str(appearance.get("hair_color", ""))
	payload["appearanceSkinTone"] = str(appearance.get("skin_tone", ""))
	payload["appearanceEyeColor"] = str(appearance.get("eye_color", ""))
	payload["body"] = presence_body
	payload["hair"] = str(appearance.get("hair", ""))
	payload["hair_color"] = str(appearance.get("hair_color", ""))
	payload["hairColor"] = str(appearance.get("hair_color", ""))
	payload["eye_color"] = str(appearance.get("eye_color", ""))
	payload["eyeColor"] = str(appearance.get("eye_color", ""))
	payload["headgear"] = str(appearance.get("headgear", ""))
	payload["top"] = str(appearance.get("top", ""))
	return payload


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
				_debug_log_player_update(message)
				player_update_received.emit(message)
			"player_left":
				player_left_received.emit(int(message.get("userId", 0)))


func _debug_log_player_update(message: Dictionary) -> void:
	if not DEBUG_PLAYER_UPDATE_PAYLOADS:
		return

	var log_line := "[WorldPresenceService player_update] %s" % JSON.stringify(message)
	print(log_line)

	var file := FileAccess.open(PLAYER_UPDATE_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(PLAYER_UPDATE_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WorldPresenceService: could not write %s" % PLAYER_UPDATE_LOG_PATH)
		return

	file.seek_end()
	file.store_line(log_line)


func _to_websocket_url(base_url: String) -> String:
	if base_url.begins_with("https://"):
		return "wss://" + base_url.trim_prefix("https://").rstrip("/")
	if base_url.begins_with("http://"):
		return "ws://" + base_url.trim_prefix("http://").rstrip("/")
	return base_url.rstrip("/")
