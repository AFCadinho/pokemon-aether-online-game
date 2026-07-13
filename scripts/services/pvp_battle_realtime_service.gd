extends Node

class_name PvpBattleRealtimeServiceNode

const BattleTimerProjectionClass = preload("res://scripts/battle/battle_timer_projection.gd")

signal connection_changed(connected: bool)
signal battle_update_received(message: Dictionary)
signal action_response_received(request_id: String, message: Dictionary)
signal room_joined(room_code: String, player_id: String, battle_id: String)
signal room_ready(room_code: String, battle_id: String)
signal session_invalid(reason: String)
signal timer_state_changed(timer_projection: RefCounted)

const RECONNECT_DELAY_SECONDS := 3.0
const SESSION_INVALID_CLOSE_CODE := 1008
const DEBUG_PVP_REALTIME := false

var websocket: WebSocketPeer = WebSocketPeer.new()
var connected := false
var connecting := false
var should_reconnect := false
var reconnect_timer := 0.0
var session_invalid_handled := false
var active_room_code := ""
var active_player_id := "p1"
var active_battle_id := ""
var active_match_id := ""
var request_counter := 0
var joined := false
var room_is_ready := false
var battle_event_latest_seq := 0
var last_battle_event_seq := 0
var received_battle_event_count := 0
var timer_projection := BattleTimerProjectionClass.new()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and websocket.get_ready_state() == WebSocketPeer.STATE_OPEN and joined:
		websocket.send_text(JSON.stringify({"type":"timer_sync","timerContractVersions":[1]}))


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

	if ready_state == WebSocketPeer.STATE_OPEN:
		connecting = false
		session_invalid_handled = false
		return

	if ready_state == WebSocketPeer.STATE_CONNECTING:
		return

	connecting = false
	if not should_reconnect or not _is_authenticated() or active_room_code == "":
		return

	reconnect_timer -= delta
	if reconnect_timer <= 0.0:
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connect_room(active_room_code, active_player_id, active_battle_id, active_match_id)


func connect_room(room_code: String, player_id: String, battle_id: String, match_id: String = "") -> void:
	if DEBUG_PVP_REALTIME:
		_log_realtime("connect_room called", "room_code=%s player_id=%s battle_id=%s match_id=%s" % [room_code, player_id, battle_id, match_id])
	var normalized_battle_id := battle_id.strip_edges()
	if active_battle_id != "" and normalized_battle_id != active_battle_id:
		battle_event_latest_seq = 0
		last_battle_event_seq = 0
		received_battle_event_count = 0
		timer_projection.reset()
	active_room_code = room_code.strip_edges().to_upper()
	active_player_id = "p2" if player_id == "p2" else "p1"
	active_battle_id = normalized_battle_id
	active_match_id = match_id.strip_edges()
	joined = false
	room_is_ready = false
	if active_room_code == "" or not _is_authenticated():
		if DEBUG_PVP_REALTIME:
			_log_realtime(
				"connect_room aborted",
				"active_room_code=%s authenticated=%s" % [active_room_code, _is_authenticated()]
			)
		return
	if connecting:
		if DEBUG_PVP_REALTIME:
			_log_realtime("connect_room ignored because already connecting", "room_code=%s" % active_room_code)
		return

	should_reconnect = true
	connecting = true
	session_invalid_handled = false
	_connect_room_async.call_deferred()


func _connect_room_async() -> void:
	var base_url: String = await _get_gateway_base_url()
	if not _is_authenticated() or active_room_code == "":
		if DEBUG_PVP_REALTIME:
			_log_realtime("connect_room_async aborted", "authenticated=%s room=%s" % [_is_authenticated(), active_room_code])
		connecting = false
		return

	websocket = WebSocketPeer.new()
	var websocket_url := _to_websocket_url(base_url) + "/ws/pvp-battle?token=%s" % _session_token().uri_encode()
	if DEBUG_PVP_REALTIME:
		_log_realtime("Connecting websocket", "url=%s" % websocket_url)
	var error := websocket.connect_to_url(websocket_url)
	if error != OK:
		connecting = false
		connected = false
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connection_changed.emit(false)
		push_warning("PvpBattleRealtimeService: could not connect websocket: %s" % error_string(error))
		return

	_send_join_when_open.call_deferred()


func _send_join_when_open() -> void:
	if DEBUG_PVP_REALTIME:
		_log_realtime("Waiting for websocket open to send join", "room=%s player=%s" % [active_room_code, active_player_id])
	var open_deadline_msec := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < open_deadline_msec:
		websocket.poll()
		if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_send_join()
			return
		if websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			return
		await get_tree().process_frame


func _send_join() -> void:
	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Sending join packet",
			"state=%s room=%s player=%s battle=%s" % [websocket.get_ready_state(), active_room_code, active_player_id, active_battle_id]
		)
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var payload := _build_join_payload()
	websocket.send_text(JSON.stringify(payload))


func _build_join_payload() -> Dictionary:
	var payload := {
		"type": "join",
		"roomCode": active_room_code,
		"playerId": active_player_id,
		"battleId": active_battle_id,
		"lastBattleEventSeq": last_battle_event_seq,
		"timerContractVersions": [1],
		"decisionContractVersions": [1],
		"battleCommandContractVersions": [1],
	}
	if active_match_id != "":
		payload["matchId"] = active_match_id
	return payload


func disconnect_room() -> void:
	should_reconnect = false
	connecting = false
	joined = false
	room_is_ready = false
	active_room_code = ""
	active_player_id = "p1"
	active_battle_id = ""
	active_match_id = ""
	battle_event_latest_seq = 0
	last_battle_event_seq = 0
	received_battle_event_count = 0
	timer_projection.reset()
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	websocket = WebSocketPeer.new()
	if connected:
		connected = false
		connection_changed.emit(false)


func send_action(action: String, battle_id: String, player_id: String, slot: int, mega := false, decision_id := "", decision_generation := 0) -> String:
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if DEBUG_PVP_REALTIME:
			_log_realtime(
				"send_action blocked because socket is not open",
				"state=%s room=%s player=%s action=%s slot=%s" % [websocket.get_ready_state(), active_room_code, player_id, action, slot]
			)
		connect_room(active_room_code, active_player_id, active_battle_id, active_match_id)
		return ""

	request_counter += 1
	var request_id := "%s_%s" % [Time.get_ticks_usec(), request_counter]
	var payload := {
		"type": "action",
		"requestId": request_id,
		"action": action,
		"battleId": battle_id,
		"playerId": "p2" if player_id == "p2" else "p1",
		"slot": slot,
	}
	if mega:
		payload["mega"] = true
	if str(decision_id).strip_edges() != "":
		payload["decisionId"] = str(decision_id).strip_edges()
	if int(decision_generation) > 0:
		payload["decisionGeneration"] = int(decision_generation)
	payload["idempotencyKey"] = request_id
	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Sending action packet",
			"request_id=%s type=%s action=%s battle_id=%s player=%s slot=%s mega=%s" % [request_id, payload.get("type", ""), payload.get("action", ""), payload.get("battleId", ""), payload.get("playerId", ""), slot, mega]
		)

	var error := websocket.send_text(JSON.stringify(payload))
	if DEBUG_PVP_REALTIME:
		_log_realtime("send_action result", "request_id=%s error=%s" % [request_id, error])
	return request_id if error == OK else ""


func send_render_ack(
	battle_id: String,
	player_id: String,
	event_batch_id: String,
	batch_seq: int,
	last_rendered_seq: int,
	turn := -1,
	phase := ""
) -> bool:
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if DEBUG_PVP_REALTIME:
			_log_realtime(
				"send_render_ack blocked because socket is not open",
				"state=%s room=%s player=%s battle=%s batch=%s lastRenderedSeq=%d" % [
					websocket.get_ready_state(),
					active_room_code,
					player_id,
					battle_id,
					event_batch_id,
					last_rendered_seq,
				]
			)
		connect_room(active_room_code, active_player_id, active_battle_id, active_match_id)
		return false

	var normalized_player_id := "p2" if player_id == "p2" else "p1"
	var payload := {
		"type": "render_ack",
		"battleId": battle_id,
		"roomCode": active_room_code,
		"playerId": normalized_player_id,
		"eventBatchId": event_batch_id,
		"batchSeq": batch_seq,
		"lastRenderedSeq": last_rendered_seq,
	}
	if turn >= 0:
		payload["turn"] = turn
	if phase.strip_edges() != "":
		payload["phase"] = phase.strip_edges()

	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Sending render ACK",
			"battle=%s player=%s batch=%s batchSeq=%d lastRenderedSeq=%d turn=%d phase=%s" % [
				battle_id,
				normalized_player_id,
				event_batch_id,
				batch_seq,
				last_rendered_seq,
				turn,
				phase,
			]
		)

	var error := websocket.send_text(JSON.stringify(payload))
	if DEBUG_PVP_REALTIME:
		_log_realtime("send_render_ack result", "batch=%s error=%s" % [event_batch_id, error])
	return error == OK


func _process_packets() -> void:
	while websocket.get_available_packet_count() > 0:
		var packet := websocket.get_packet()
		var parsed_body: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not (parsed_body is Dictionary):
			continue

		var message: Dictionary = parsed_body as Dictionary
		var message_type := str(message.get("type", "")).strip_edges().to_lower()
		if DEBUG_PVP_REALTIME:
			_log_realtime("Incoming packet", "type=%s request=%s battle=%s player=%s action=%s room=%s" % [message_type, str(message.get("requestId", "")), str(message.get("battleId", "")), str(message.get("playerId", "")), str(message.get("action", "")), str(message.get("roomCode", ""))])
		if message_type == "pvp.joined":
			joined = true
			room_is_ready = false
			active_room_code = str(message.get("roomCode", active_room_code)).strip_edges().to_upper()
			active_player_id = "p2" if str(message.get("playerId", active_player_id)) == "p2" else "p1"
			active_battle_id = str(message.get("battleId", active_battle_id)).strip_edges()
			active_match_id = str(message.get("matchId", active_match_id)).strip_edges()
			room_joined.emit(active_room_code, active_player_id, active_battle_id)
			continue
		if message_type == "pvp.room_ready":
			var message_room := str(message.get("roomCode", active_room_code)).strip_edges().to_upper()
			var message_battle := str(message.get("battleId", active_battle_id)).strip_edges()
			if message_room == active_room_code and (active_battle_id == "" or message_battle == active_battle_id):
				room_is_ready = true
				room_ready.emit(message_room, message_battle)
			continue
		if message_type == "pvp.battle_update":
			var request_id := str(message.get("requestId", ""))
			battle_update_received.emit(message)
			if request_id != "":
				action_response_received.emit(request_id, message)
			continue
		if message_type == "pvp.render_batch":
			var request_id := str(message.get("requestId", ""))
			battle_update_received.emit(message)
			if request_id != "":
				action_response_received.emit(request_id, message)
			continue
		if message_type == "pvp.snapshot":
			var response_value: Variant = message.get("response", {})
			if response_value is Dictionary:
				var operational_value: Variant = (response_value as Dictionary).get("operationalState", {})
				if operational_value is Dictionary:
					timer_projection.apply_operational_state(operational_value as Dictionary)
				var timer_value: Variant = (response_value as Dictionary).get("timerState", {})
				if timer_value is Dictionary and timer_projection.apply_snapshot(timer_value as Dictionary):
					last_battle_event_seq = max(last_battle_event_seq, timer_projection.battle_event_seq)
					timer_state_changed.emit(timer_projection)
			battle_update_received.emit(message)
			continue
		if message_type == "pvp.battle_events":
			_handle_battle_events_message(message)
			continue
		if message_type == "pvp.phase_update":
			battle_update_received.emit(message)
			continue
		if message_type.begins_with("battle.timer_"):
			if timer_projection.apply_event(message):
				timer_state_changed.emit(timer_projection)
			continue
		if message_type == "pvp.opponent_disconnected" or message_type == "pvp.opponent_reconnected" or message_type == "pvp.reconnect_grace_started":
			battle_update_received.emit(message)
			continue
		if message_type == "pvp.error":
			var request_id := str(message.get("requestId", ""))
			if request_id != "":
				action_response_received.emit(request_id, message)
				battle_update_received.emit({
					"type": "pvp.battle_update",
					"requestId": request_id,
					"roomCode": active_room_code,
					"playerId": active_player_id,
					"action": "error",
					"response": {
						"success": false,
						"error": str(message.get("error", "PvP realtime error.")),
					},
				})
			continue


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
	session_invalid.emit("Your PvP battle session is no longer valid.")


func _handle_battle_events_message(message: Dictionary) -> void:
	var latest_seq := _nonnegative_int(message.get("battleEventLatestSeq", battle_event_latest_seq), battle_event_latest_seq)
	var events_value: Variant = message.get("events", [])
	var valid_event_count := 0
	var pending_events: Dictionary = {}
	if events_value is Array:
		for event_value in events_value:
			if not (event_value is Dictionary):
				continue
			var event := event_value as Dictionary
			var event_seq := _nonnegative_int(event.get("battleEventSeq", -1), -1)
			if event_seq < 0:
				continue
			if event_seq <= last_battle_event_seq:
				continue
			if pending_events.has(event_seq):
				continue
			pending_events[event_seq] = event

	var next_event_seq := last_battle_event_seq + 1
	while pending_events.has(next_event_seq):
		var event: Dictionary = pending_events[next_event_seq] as Dictionary
		valid_event_count += 1
		if str(event.get("type", "")).begins_with("battle.timer_"):
			timer_projection.apply_event(event)
		else:
			timer_projection.mark_event_applied(next_event_seq)
		last_battle_event_seq = next_event_seq
		next_event_seq += 1

	battle_event_latest_seq = max(battle_event_latest_seq, latest_seq)
	# latestSeq describes the remote head, not locally applied domain order.
	received_battle_event_count += valid_event_count
	if valid_event_count > 0:
		timer_state_changed.emit(timer_projection)
	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Received battle event stream update",
			"battle=%s after=%d latest=%d validEvents=%d totalEvents=%d" % [
				str(message.get("battleId", active_battle_id)),
				_nonnegative_int(message.get("afterBattleEventSeq", 0), 0),
				battle_event_latest_seq,
				valid_event_count,
				received_battle_event_count,
			]
		)


func _to_websocket_url(base_url: String) -> String:
	if base_url.begins_with("https://"):
		return "wss://" + base_url.trim_prefix("https://").rstrip("/")
	if base_url.begins_with("http://"):
		return "ws://" + base_url.trim_prefix("http://").rstrip("/")
	return base_url.rstrip("/")


func _nonnegative_int(value: Variant, fallback: int = 0) -> int:
	var parsed := fallback
	match typeof(value):
		TYPE_INT:
			parsed = int(value)
		TYPE_FLOAT:
			parsed = int(value)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_int():
				parsed = int(text)
	return max(parsed, 0) if parsed >= 0 else fallback


func _is_authenticated() -> bool:
	if not is_inside_tree():
		return false
	var auth_service := get_node_or_null("/root/AuthService")
	if auth_service == null or not auth_service.has_method("is_authenticated"):
		return false
	return bool(auth_service.call("is_authenticated"))


func _session_token() -> String:
	if not is_inside_tree():
		return ""
	var auth_service := get_node_or_null("/root/AuthService")
	if auth_service == null:
		return ""
	return str(auth_service.get("session_token"))


func _get_gateway_base_url() -> String:
	if not is_inside_tree():
		return ""
	var gateway_config := get_node_or_null("/root/GatewayApiConfig")
	if gateway_config != null and gateway_config.has_method("get_base_url"):
		return str(await gateway_config.call("get_base_url"))
	return ""


func _log_realtime(message: String, details: String = "") -> void:
	if not DEBUG_PVP_REALTIME:
		return
	if details == "":
		print("[PvpRealtimeService] %s" % message)
	else:
		print("[PvpRealtimeService] %s | %s" % [message, details])
