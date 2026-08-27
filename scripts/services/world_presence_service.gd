extends Node

class_name WorldPresenceServiceNode

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const ClientBuild := preload("res://scripts/services/client_build.gd")

signal snapshot_received(players: Array)
signal player_update_received(player_state: Dictionary)
signal player_left_received(user_id: int)
signal roster_changed(players: Array, roster_revision: int)
signal roster_player_changed(player_state: Dictionary, roster_revision: int)
signal roster_player_removed(user_id: int, roster_revision: int)
signal weather_changed(weather_state: Dictionary)
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
var current_map_players: Dictionary = {}
var roster_revision := 0
var has_authoritative_roster_revision := false
var last_sent_map_id := ""
var current_weather_state: Dictionary = {}
var connection_attempt_id := 0


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
			_reset_roster()
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

	if connecting:
		return
	if not should_reconnect or not _is_authenticated():
		return

	reconnect_timer -= delta
	if reconnect_timer <= 0.0:
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connect_presence()


func connect_presence() -> void:
	if connecting:
		return
	if not _is_authenticated():
		return

	should_reconnect = true
	connecting = true
	connection_attempt_id += 1
	session_invalid_handled = false
	session_check_timer = SESSION_CHECK_INTERVAL_SECONDS
	_connect_presence_async.call_deferred(connection_attempt_id)


func _connect_presence_async(attempt_id: int) -> void:
	var gateway := _gateway_api_config()
	if gateway == null:
		connecting = false
		return
	var base_url: String = await gateway.call("get_base_url")
	if attempt_id != connection_attempt_id or not _is_authenticated():
		connecting = false
		return
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return

	var websocket_url := ClientBuild.append_websocket_query(
		_to_websocket_url(base_url) + "/ws/world-presence?token=%s" % _session_token().uri_encode()
	)
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
	connection_attempt_id += 1
	last_position_payload.clear()
	_reset_weather(last_sent_map_id)
	last_sent_map_id = ""
	_reset_roster()
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
	var map_id := str(state.get("mapId", "")).strip_edges()
	if map_id != last_sent_map_id:
		last_sent_map_id = map_id
		_reset_roster()
		_reset_weather(map_id)

	var appearance_value: Variant = state.get("appearance", {})
	var appearance: Dictionary = appearance_value if appearance_value is Dictionary else {}
	var presence_body: String = CharacterAppearanceService.get_presence_body_base_id(str(appearance.get("body", "")))
	var appearance_payload: Dictionary = _build_appearance_payload(appearance)
	appearance_payload["body"] = presence_body
	var movement_payload: Dictionary = _build_movement_payload(state.get("movement", {}), appearance_payload, presence_body, appearance)
	var payload := {
		"type": "position",
		"mapId": map_id,
		"mapScenePath": state.get("mapScenePath", null),
		"gender": str(state.get("gender", "male")),
		"position": state.get("position", {}),
		"facingDirection": str(state.get("facingDirection", "down")),
		"movement": movement_payload,
		"follower": state.get("follower", {}),
		"appearance": appearance_payload,
		"roles": state.get("roles", []),
		"selectedRoleBadge": str(state.get("selectedRoleBadge", "")),
		"activityState": str(state.get("activityState", "idle")),
		"aethernetEffect": state.get("aethernetEffect", {}),
		"appearanceBody": presence_body,
		"appearanceHair": str(appearance.get("hair", "")),
		"appearanceHairStyleIndex": int(appearance.get("hair_style_index", 0)),
		"appearanceHeadgear": str(appearance.get("headgear", "")),
		"appearanceFacialHair": str(appearance.get("facial_hair", "")),
		"appearanceFacegear": str(appearance.get("facegear", "")),
		"appearanceTop": str(appearance.get("top", "")),
		"appearanceBottom": str(appearance.get("bottom", "")),
		"appearanceShoes": str(appearance.get("shoes", "")),
		"appearanceHairColor": str(appearance.get("hair_color", "")),
		"appearanceSkinTone": str(appearance.get("skin_tone", "")),
		"appearanceEyeColor": str(appearance.get("eye_color", "")),
		"appearanceFacegearColor": str(appearance.get("facegear_color", "")),
		"appearanceFacialHairColor": str(appearance.get("facial_hair_color", "")),
		"appearanceTopColor": str(appearance.get("top_color", "")),
		"appearanceBottomColor": str(appearance.get("bottom_color", "")),
		"appearanceShoesColor": str(appearance.get("shoes_color", "")),
		"body": presence_body,
		"hair": str(appearance.get("hair", "")),
		"hair_style_index": int(appearance.get("hair_style_index", 0)),
		"hairStyleIndex": int(appearance.get("hair_style_index", 0)),
		"headgear": str(appearance.get("headgear", "")),
		"facial_hair": str(appearance.get("facial_hair", "")),
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
		"facegear_color": str(appearance.get("facegear_color", "")),
		"facegearColor": str(appearance.get("facegear_color", "")),
		"facial_hair_color": str(appearance.get("facial_hair_color", "")),
		"facialHairColor": str(appearance.get("facial_hair_color", "")),
		"top_color": str(appearance.get("top_color", "")),
		"topColor": str(appearance.get("top_color", "")),
		"bottom_color": str(appearance.get("bottom_color", "")),
		"bottomColor": str(appearance.get("bottom_color", "")),
		"shoes_color": str(appearance.get("shoes_color", "")),
		"shoesColor": str(appearance.get("shoes_color", "")),
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
	payload["facegearColor"] = str(appearance.get("facegear_color", ""))
	payload["facialHairColor"] = str(appearance.get("facial_hair_color", ""))
	payload["topColor"] = str(appearance.get("top_color", ""))
	payload["bottomColor"] = str(appearance.get("bottom_color", ""))
	payload["shoesColor"] = str(appearance.get("shoes_color", ""))
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
	payload["appearanceFacialHair"] = str(appearance.get("facial_hair", ""))
	payload["appearanceFacegear"] = str(appearance.get("facegear", ""))
	payload["appearanceTop"] = str(appearance.get("top", ""))
	payload["appearanceBottom"] = str(appearance.get("bottom", ""))
	payload["appearanceShoes"] = str(appearance.get("shoes", ""))
	payload["appearanceHairColor"] = str(appearance.get("hair_color", ""))
	payload["appearanceSkinTone"] = str(appearance.get("skin_tone", ""))
	payload["appearanceEyeColor"] = str(appearance.get("eye_color", ""))
	payload["appearanceFacegearColor"] = str(appearance.get("facegear_color", ""))
	payload["appearanceFacialHairColor"] = str(appearance.get("facial_hair_color", ""))
	payload["appearanceTopColor"] = str(appearance.get("top_color", ""))
	payload["appearanceBottomColor"] = str(appearance.get("bottom_color", ""))
	payload["appearanceShoesColor"] = str(appearance.get("shoes_color", ""))
	payload["body"] = presence_body
	payload["hair"] = str(appearance.get("hair", ""))
	payload["hair_color"] = str(appearance.get("hair_color", ""))
	payload["hairColor"] = str(appearance.get("hair_color", ""))
	payload["eye_color"] = str(appearance.get("eye_color", ""))
	payload["eyeColor"] = str(appearance.get("eye_color", ""))
	payload["headgear"] = str(appearance.get("headgear", ""))
	payload["facial_hair"] = str(appearance.get("facial_hair", ""))
	payload["facegear"] = str(appearance.get("facegear", ""))
	payload["top"] = str(appearance.get("top", ""))
	payload["facegear_color"] = str(appearance.get("facegear_color", ""))
	payload["facegearColor"] = str(appearance.get("facegear_color", ""))
	payload["facial_hair_color"] = str(appearance.get("facial_hair_color", ""))
	payload["facialHairColor"] = str(appearance.get("facial_hair_color", ""))
	payload["top_color"] = str(appearance.get("top_color", ""))
	payload["topColor"] = str(appearance.get("top_color", ""))
	payload["bottom_color"] = str(appearance.get("bottom_color", ""))
	payload["bottomColor"] = str(appearance.get("bottom_color", ""))
	payload["shoes_color"] = str(appearance.get("shoes_color", ""))
	payload["shoesColor"] = str(appearance.get("shoes_color", ""))
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
	if not _is_authenticated():
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
				_apply_snapshot_message(message)
			"weather_update":
				_apply_weather_state(message)
			"player_update":
				_debug_log_player_update(message)
				_apply_player_update_message(message)
			"player_left":
				_apply_player_left_message(message)


func get_current_map_players() -> Array:
	var players: Array = []
	var user_ids: Array = current_map_players.keys()
	user_ids.sort()
	for user_id: Variant in user_ids:
		var player_state: Dictionary = _dictionary_from_value(current_map_players.get(user_id, {}))
		if not player_state.is_empty():
			players.append(player_state.duplicate(true))
	return players


func _apply_snapshot_message(message: Dictionary) -> void:
	_apply_weather_state(message.get("weather", {}))
	var incoming_revision := _incoming_roster_revision(message)
	if not _should_apply_roster_revision(incoming_revision):
		return

	current_map_players.clear()
	var players_value: Variant = message.get("players", [])
	var players: Array = players_value if players_value is Array else []
	for player_value: Variant in players:
		var player_state := _dictionary_from_value(player_value)
		var user_id := int(player_state.get("userId", 0))
		if user_id > 0:
			current_map_players[str(user_id)] = player_state.duplicate(true)
	_apply_roster_revision(incoming_revision)
	var roster := get_current_map_players()
	roster_changed.emit(roster, roster_revision)
	snapshot_received.emit(roster)


func _apply_weather_state(weather_value: Variant) -> void:
	if not weather_value is Dictionary:
		return
	var weather_state: Dictionary = weather_value as Dictionary
	var map_id := str(weather_state.get("mapId", "")).strip_edges()
	if map_id == "" or (last_sent_map_id != "" and map_id != last_sent_map_id):
		return
	var weather := str(weather_state.get("weather", "clear")).strip_edges().to_lower()
	if weather not in ["clear", "rain", "snow"]:
		weather = "clear"
	current_weather_state = weather_state.duplicate(true)
	current_weather_state["mapId"] = map_id
	current_weather_state["weather"] = weather
	weather_changed.emit(current_weather_state.duplicate(true))


func _apply_player_update_message(message: Dictionary) -> void:
	var incoming_revision := _incoming_roster_revision(message)
	if not _should_apply_roster_revision(incoming_revision):
		return

	var user_id := int(message.get("userId", 0))
	if user_id <= 0:
		return
	var player_state: Dictionary = message.duplicate(true)
	player_state.erase("type")
	player_state.erase("rosterRevision")
	current_map_players[str(user_id)] = player_state
	_apply_roster_revision(incoming_revision)
	var snapshot: Dictionary = player_state.duplicate(true)
	roster_player_changed.emit(snapshot, roster_revision)
	player_update_received.emit(message.duplicate(true))


func _apply_player_left_message(message: Dictionary) -> void:
	var incoming_revision := _incoming_roster_revision(message)
	if not _should_apply_roster_revision(incoming_revision):
		return

	var user_id := int(message.get("userId", 0))
	if user_id <= 0:
		return
	current_map_players.erase(str(user_id))
	_apply_roster_revision(incoming_revision)
	roster_player_removed.emit(user_id, roster_revision)
	player_left_received.emit(user_id)


func _incoming_roster_revision(message: Dictionary) -> int:
	if not message.has("rosterRevision"):
		return -1
	return maxi(int(message.get("rosterRevision", 0)), 0)


func _should_apply_roster_revision(incoming_revision: int) -> bool:
	if incoming_revision < 0:
		return not has_authoritative_roster_revision
	return not has_authoritative_roster_revision or incoming_revision > roster_revision


func _apply_roster_revision(incoming_revision: int) -> void:
	if incoming_revision < 0:
		return
	has_authoritative_roster_revision = true
	roster_revision = incoming_revision


func _reset_roster() -> void:
	var had_players := not current_map_players.is_empty()
	current_map_players.clear()
	roster_revision = 0
	has_authoritative_roster_revision = false
	if had_players:
		roster_changed.emit([], roster_revision)


func _reset_weather(map_id: String) -> void:
	current_weather_state.clear()
	var normalized_map_id := map_id.strip_edges()
	if normalized_map_id != "":
		weather_changed.emit({"mapId": normalized_map_id, "weather": "clear", "source": "pending"})


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


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _is_authenticated() -> bool:
	if not is_inside_tree():
		return false
	var auth_service := get_node_or_null("/root/AuthService")
	return auth_service != null and auth_service.has_method("is_authenticated") and bool(auth_service.call("is_authenticated"))


func _session_token() -> String:
	if not is_inside_tree():
		return ""
	var auth_service := get_node_or_null("/root/AuthService")
	return str(auth_service.get("session_token")) if auth_service != null else ""


func _gateway_api_config() -> Object:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GatewayApiConfig")
