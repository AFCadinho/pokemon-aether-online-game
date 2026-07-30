extends Node

class_name PvpBattleRealtimeServiceNode

const ClientBuild := preload("res://scripts/services/client_build.gd")
const BattleTimerProjectionClass = preload("res://scripts/battle/battle_timer_projection.gd")

signal connection_changed(connected: bool)
signal battle_update_received(message: Dictionary)
signal action_response_received(request_id: String, message: Dictionary)
signal room_joined(room_code: String, player_id: String, battle_id: String)
signal room_ready(room_code: String, battle_id: String)
signal session_invalid(reason: String)
signal timer_state_changed(timer_projection: RefCounted)

const RECONNECT_DELAY_SECONDS := 3.0
const CONNECTION_HEARTBEAT_SECONDS := 5.0
const CONNECTION_PONG_TIMEOUT_MSEC := 12000
const JOIN_ACK_TIMEOUT_MSEC := 10000
const SESSION_INVALID_CLOSE_CODE := 1008
const DEBUG_PVP_REALTIME := false
const WEBSOCKET_BUFFER_BYTES := 1024 * 1024
const WEBSOCKET_MAX_QUEUED_PACKETS := 4096
const ACTION_TIMEOUT_RECOVERY_UNAVAILABLE := "unavailable"
const ACTION_TIMEOUT_RECOVERY_TERMINAL := "terminal"
const ACTION_TIMEOUT_RECOVERY_ACCEPTED := "accepted"
const ACTION_TIMEOUT_RECOVERY_ADVANCED := "advanced"
const ACTION_TIMEOUT_RECOVERY_RETRY := "retry"

var websocket: WebSocketPeer = WebSocketPeer.new()
var connected := false
var connecting := false
var should_reconnect := false
var reconnect_timer := 0.0
var connection_heartbeat_timer := 0.0
var connection_attempt_generation := 0
var join_sent := false
var join_sent_at_msec := 0
var awaiting_pong := false
var ping_sent_at_msec := 0
var session_invalid_handled := false
var active_room_code := ""
var active_player_id := "p1"
var active_viewer_role := "participant"
var active_battle_id := ""
var active_match_id := ""
var request_counter := 0
var joined := false
var room_is_ready := false
var battle_event_latest_seq := 0
var last_battle_event_seq := 0
var last_spectator_event_seq := 0
var spectator_cursor_valid := false
var received_battle_event_count := 0
var timer_projection := BattleTimerProjectionClass.new()
var pending_render_ack_payload: Dictionary = {}

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
		if not joined:
			if not join_sent:
				_send_join()
			elif (
				join_sent_at_msec > 0
				and Time.get_ticks_msec() - join_sent_at_msec >= JOIN_ACK_TIMEOUT_MSEC
			):
				_restart_stalled_connection("PvP room join timed out.")
			return
		if awaiting_pong and Time.get_ticks_msec() - ping_sent_at_msec >= CONNECTION_PONG_TIMEOUT_MSEC:
			_restart_stalled_connection("PvP heartbeat timed out.")
			return
		connection_heartbeat_timer -= delta
		if connection_heartbeat_timer <= 0.0 and not awaiting_pong:
			var heartbeat_error := websocket.send_text(JSON.stringify({"type":"ping"}))
			if heartbeat_error != OK:
				_restart_stalled_connection("PvP heartbeat could not be sent.")
				return
			awaiting_pong = true
			ping_sent_at_msec = Time.get_ticks_msec()
			connection_heartbeat_timer = CONNECTION_HEARTBEAT_SECONDS
		return

	if ready_state == WebSocketPeer.STATE_CONNECTING:
		return

	connecting = false
	if not should_reconnect or not _is_authenticated() or active_room_code == "":
		return

	reconnect_timer -= delta
	if reconnect_timer <= 0.0:
		reconnect_timer = RECONNECT_DELAY_SECONDS
		connect_room(active_room_code, active_player_id, active_battle_id, active_match_id, active_viewer_role)


func connect_room(
	room_code: String,
	player_id: String,
	battle_id: String,
	match_id: String = "",
	viewer_role: String = "participant"
) -> void:
	if DEBUG_PVP_REALTIME:
		_log_realtime("connect_room called", "room_code=%s player_id=%s battle_id=%s match_id=%s" % [room_code, player_id, battle_id, match_id])
	var normalized_battle_id := battle_id.strip_edges()
	if active_battle_id != "" and normalized_battle_id != active_battle_id:
		battle_event_latest_seq = 0
		last_battle_event_seq = 0
		last_spectator_event_seq = 0
		spectator_cursor_valid = false
		received_battle_event_count = 0
		timer_projection.reset()
		pending_render_ack_payload.clear()
	active_room_code = room_code.strip_edges().to_upper()
	active_viewer_role = "spectator" if viewer_role.strip_edges().to_lower() == "spectator" else "participant"
	active_player_id = "p2" if player_id == "p2" else "p1"
	active_battle_id = normalized_battle_id
	active_match_id = match_id.strip_edges()
	joined = false
	join_sent = false
	join_sent_at_msec = 0
	connection_heartbeat_timer = 0.0
	awaiting_pong = false
	ping_sent_at_msec = 0
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
	connection_attempt_generation += 1
	_connect_room_async.call_deferred(connection_attempt_generation)


func _connect_room_async(attempt_generation: int) -> void:
	var base_url: String = await _get_gateway_base_url()
	if (
		attempt_generation != connection_attempt_generation
		or not _is_authenticated()
		or active_room_code == ""
	):
		if DEBUG_PVP_REALTIME:
			_log_realtime("connect_room_async aborted", "authenticated=%s room=%s" % [_is_authenticated(), active_room_code])
		if attempt_generation == connection_attempt_generation:
			connecting = false
		return

	websocket = WebSocketPeer.new()
	websocket.inbound_buffer_size = WEBSOCKET_BUFFER_BYTES
	websocket.outbound_buffer_size = WEBSOCKET_BUFFER_BYTES
	websocket.max_queued_packets = WEBSOCKET_MAX_QUEUED_PACKETS
	var websocket_url := ClientBuild.append_websocket_query(
		_to_websocket_url(base_url) + "/ws/pvp-battle?token=%s" % _session_token().uri_encode()
	)
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

func _send_join() -> void:
	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Sending join packet",
			"state=%s room=%s player=%s battle=%s" % [websocket.get_ready_state(), active_room_code, active_player_id, active_battle_id]
		)
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var payload := _build_join_payload()
	var error := websocket.send_text(JSON.stringify(payload))
	if error != OK:
		_restart_stalled_connection("PvP room join could not be sent.")
		return
	join_sent = true
	join_sent_at_msec = Time.get_ticks_msec()


func _build_join_payload() -> Dictionary:
	var payload := {
		"type": "join",
		"viewerRole": active_viewer_role,
		"roomCode": active_room_code,
		"playerId": active_player_id,
		"battleId": active_battle_id,
		"lastBattleEventSeq": last_battle_event_seq,
		"lastSpectatorEventSeq": last_spectator_event_seq,
		"spectatorCursorValid": spectator_cursor_valid,
		"timerContractVersions": [1],
		"decisionContractVersions": [1],
		"battleCommandContractVersions": [1],
	}
	if active_match_id != "":
		payload["matchId"] = active_match_id
	return payload


func seed_spectator_event_cursor(response: Dictionary) -> void:
	if active_viewer_role != "spectator" or not response.has("eventSeq"):
		return
	last_spectator_event_seq = max(
		last_spectator_event_seq,
		_nonnegative_int(response.get("eventSeq", 0))
	)
	spectator_cursor_valid = true


func disconnect_room() -> void:
	should_reconnect = false
	connecting = false
	connection_attempt_generation += 1
	joined = false
	join_sent = false
	join_sent_at_msec = 0
	connection_heartbeat_timer = 0.0
	awaiting_pong = false
	ping_sent_at_msec = 0
	room_is_ready = false
	active_room_code = ""
	active_player_id = "p1"
	active_viewer_role = "participant"
	active_battle_id = ""
	active_match_id = ""
	battle_event_latest_seq = 0
	last_battle_event_seq = 0
	last_spectator_event_seq = 0
	spectator_cursor_valid = false
	received_battle_event_count = 0
	timer_projection.reset()
	pending_render_ack_payload.clear()
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close()
	websocket = WebSocketPeer.new()
	if connected:
		connected = false
		connection_changed.emit(false)


func request_resync(reason: String = "PvP state resynchronization required.") -> void:
	if not should_reconnect or active_room_code == "":
		return
	_restart_stalled_connection(reason)


func send_action(action: String, battle_id: String, player_id: String, slot: int, mega := false, decision_id := "", decision_generation := 0, decision_kind := "", z_move := false) -> String:
	if active_viewer_role == "spectator":
		push_warning("PvpBattleRealtimeService: spectator action was blocked locally.")
		return ""
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if DEBUG_PVP_REALTIME:
			_log_realtime(
				"send_action blocked because socket is not open",
				"state=%s room=%s player=%s action=%s slot=%s" % [websocket.get_ready_state(), active_room_code, player_id, action, slot]
			)
		connect_room(active_room_code, active_player_id, active_battle_id, active_match_id, active_viewer_role)
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
	if z_move:
		payload["zMove"] = true
	if str(decision_id).strip_edges() != "":
		payload["decisionId"] = str(decision_id).strip_edges()
	if int(decision_generation) > 0:
		payload["decisionGeneration"] = int(decision_generation)
	var normalized_decision_kind := str(decision_kind).strip_edges().to_upper()
	if normalized_decision_kind in ["TEAM_PREVIEW", "MOVE_SELECTION", "FORCED_SWITCH"]:
		payload["decisionKind"] = normalized_decision_kind
	payload["idempotencyKey"] = request_id
	if DEBUG_PVP_REALTIME:
		_log_realtime(
			"Sending action packet",
			"request_id=%s type=%s action=%s battle_id=%s player=%s slot=%s mega=%s z_move=%s" % [request_id, payload.get("type", ""), payload.get("action", ""), payload.get("battleId", ""), payload.get("playerId", ""), slot, mega, z_move]
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
	if active_viewer_role == "spectator":
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
	pending_render_ack_payload = payload.duplicate(true)

	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN or not joined:
		if DEBUG_PVP_REALTIME:
			_log_realtime(
				"send_render_ack deferred until socket rejoins",
				"state=%s joined=%s room=%s player=%s battle=%s batch=%s lastRenderedSeq=%d" % [
					websocket.get_ready_state(),
					str(joined),
					active_room_code,
					player_id,
					battle_id,
					event_batch_id,
					last_rendered_seq,
				]
			)
		if websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED and not connecting:
			connect_room(active_room_code, active_player_id, active_battle_id, active_match_id, active_viewer_role)
		return false

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


func _send_pending_render_ack_after_join() -> void:
	if pending_render_ack_payload.is_empty():
		return
	if active_viewer_role == "spectator" or not joined:
		return
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	websocket.send_text(JSON.stringify(pending_render_ack_payload))


func _retire_pending_render_ack(event_batch_id: String) -> void:
	if event_batch_id.strip_edges() == "":
		return
	if str(pending_render_ack_payload.get("eventBatchId", "")).strip_edges() != event_batch_id.strip_edges():
		return

	pending_render_ack_payload.clear()


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
			join_sent = false
			join_sent_at_msec = 0
			connection_heartbeat_timer = 0.0
			awaiting_pong = false
			ping_sent_at_msec = 0
			room_is_ready = false
			active_room_code = str(message.get("roomCode", active_room_code)).strip_edges().to_upper()
			active_player_id = "p2" if str(message.get("playerId", active_player_id)) == "p2" else "p1"
			active_battle_id = str(message.get("battleId", active_battle_id)).strip_edges()
			active_match_id = str(message.get("matchId", active_match_id)).strip_edges()
			active_viewer_role = "spectator" if str(message.get("viewerRole", active_viewer_role)).to_lower() == "spectator" else "participant"
			room_joined.emit(active_room_code, active_player_id, active_battle_id)
			_send_pending_render_ack_after_join()
			continue
		if message_type == "pong":
			awaiting_pong = false
			ping_sent_at_msec = 0
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
			_apply_timer_projection_from_battle_response(message)
			battle_update_received.emit(message)
			_remember_spectator_event_cursor(message)
			if request_id != "":
				action_response_received.emit(request_id, message)
			continue
		if message_type == "pvp.render_batch":
			var request_id := str(message.get("requestId", ""))
			_apply_timer_projection_from_battle_response(message)
			battle_update_received.emit(message)
			_remember_spectator_event_cursor(message)
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
					timer_state_changed.emit(timer_projection)
			battle_update_received.emit(message)
			_remember_spectator_event_cursor(message)
			continue
		if message_type == "pvp.battle_events":
			_handle_battle_events_message(message)
			continue
		if message_type == "pvp.phase_update":
			_retire_pending_render_ack(str(message.get("eventBatchId", "")))
			battle_update_received.emit(message)
			continue
		if message_type == "pvp.resync_required":
			battle_update_received.emit(message)
			continue
		if message_type in ["pvp.forfeit", "pvp.match_ended", "pvp.match_settled"]:
			if active_viewer_role == "spectator":
				battle_update_received.emit(message)
			continue
		if message_type.begins_with("battle.timer_"):
			var timer_applied := _apply_timer_contract_message(message_type, message)
			if timer_applied:
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
			elif not joined:
				_handle_join_error(message)
			continue


func _apply_timer_projection_from_battle_response(message: Dictionary) -> bool:
	var response_value: Variant = message.get("response", {})
	if not (response_value is Dictionary):
		return false
	var timer_value: Variant = (response_value as Dictionary).get("timerState", {})
	if not (timer_value is Dictionary):
		return false
	if not timer_projection.apply_snapshot(timer_value as Dictionary):
		return false
	timer_state_changed.emit(timer_projection)
	return true


func _remember_spectator_event_cursor(message: Dictionary) -> void:
	if active_viewer_role != "spectator":
		return
	var response_value: Variant = message.get("response", {})
	if not (response_value is Dictionary):
		return
	last_spectator_event_seq = max(
		last_spectator_event_seq,
		_nonnegative_int((response_value as Dictionary).get("eventSeq", 0))
	)
	spectator_cursor_valid = true


func _apply_timer_contract_message(message_type: String, message: Dictionary) -> bool:
	if message_type == "battle.timer_sync":
		var sync_payload: Variant = message.get("payload", {})
		if sync_payload is Dictionary:
			return timer_projection.apply_snapshot(sync_payload as Dictionary)
		return false
	return timer_projection.apply_event(message)


static func should_apply_terminal_action_immediately(message: Dictionary, _local_player_id: String) -> bool:
	var response_value: Variant = message.get("response", {})
	if not (response_value is Dictionary):
		return false
	var response := response_value as Dictionary
	var match_end_value: Variant = response.get("pvpMatchEnd", {})
	var is_server_timeout_end := (
		str(response.get("pvpMatchEndEvent", "")).strip_edges().to_lower() == "pvp.timeout_forfeit"
		and match_end_value is Dictionary
		and bool((match_end_value as Dictionary).get("success", false))
	)
	if is_server_timeout_end:
		return true

	var message_action := str(message.get("action", "")).strip_edges().to_lower()
	var message_player_id := str(message.get("playerId", "")).strip_edges()
	if not (message_action in ["forfeit", "disconnect", "abandon"]) or message_player_id == "":
		return false

	# The action response and battle-update broadcast can race each other. Treat a
	# mechanically terminal response as idempotent terminal confirmation even when
	# it belongs to the local player; otherwise a late local legacy response is
	# merely queued after the request waiter times out and the forfeiter stays in
	# the battle. A bare `success` is insufficient proof that the battle ended.
	if not bool(response.get("success", false)):
		return false
	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary and bool((state_value as Dictionary).get("ended", false)):
		return true
	return match_end_value is Dictionary and bool((match_end_value as Dictionary).get("success", false))


static func should_defer_authoritative_terminal_until_render(
	mechanical_state_ended: bool,
	queue_is_rendering: bool,
	current_batch_id: String,
	has_pending_updates: bool,
	require_mechanical_state_ended := true
) -> bool:
	return (
		(require_mechanical_state_ended and not mechanical_state_ended)
		or queue_is_rendering
		or current_batch_id.strip_edges() != ""
		or has_pending_updates
	)


static func is_animation_free_authoritative_terminal_reason(end_reason: String) -> bool:
	return end_reason.strip_edges().to_lower() in ["timeout", "disconnect", "forfeit"]


static func classify_action_timeout_recovery(
	response: Dictionary,
	player_id: String,
	submitted_decision_id: String,
	submitted_decision_generation: int
) -> String:
	if not bool(response.get("success", false)):
		return ACTION_TIMEOUT_RECOVERY_UNAVAILABLE

	var state_value: Variant = response.get("state", {})
	var match_end_value: Variant = response.get("pvpMatchEnd", {})
	if (
		(state_value is Dictionary and bool((state_value as Dictionary).get("ended", false)))
		or (match_end_value is Dictionary and bool((match_end_value as Dictionary).get("success", false)))
		or str(response.get("phase", "")).strip_edges().to_lower() == "ended"
	):
		return ACTION_TIMEOUT_RECOVERY_TERMINAL

	var normalized_player_id := "p2" if player_id.strip_edges().to_lower() == "p2" else "p1"
	var requests_value: Variant = response.get("requests", {})
	if requests_value is Dictionary:
		var request_value: Variant = (requests_value as Dictionary).get(normalized_player_id, {})
		if request_value is Dictionary and bool((request_value as Dictionary).get("wait", false)):
			return ACTION_TIMEOUT_RECOVERY_ACCEPTED

	var decisions_value: Variant = response.get("decisions", {})
	if decisions_value is Dictionary:
		var decision_value: Variant = (decisions_value as Dictionary).get(normalized_player_id, {})
		if decision_value is Dictionary:
			var current_decision := decision_value as Dictionary
			var current_decision_id := str(current_decision.get("decisionId", "")).strip_edges()
			var current_generation := int(current_decision.get("decisionGeneration", 0))
			if submitted_decision_generation > 0 and current_generation > submitted_decision_generation:
				return ACTION_TIMEOUT_RECOVERY_ADVANCED
			if (
				submitted_decision_id.strip_edges() != ""
				and current_decision_id != ""
				and current_decision_id != submitted_decision_id.strip_edges()
			):
				return ACTION_TIMEOUT_RECOVERY_ADVANCED

	var phase := str(response.get("phase", "")).strip_edges().to_lower()
	if phase in ["rendering_events", "awaiting_force_switch"]:
		return ACTION_TIMEOUT_RECOVERY_ADVANCED
	return ACTION_TIMEOUT_RECOVERY_RETRY


static func is_unrequested_local_team_preview_lead(message: Dictionary, local_player_id: String) -> bool:
	# Human command responses are correlated by requestId and must remain available
	# to the action waiter. Server-selected timeout leads are broadcasts without one.
	return (
		str(message.get("requestId", "")).strip_edges() == ""
		and str(message.get("action", "")).strip_edges().to_lower() == "choose_lead"
		and str(message.get("playerId", "")).strip_edges() == local_player_id.strip_edges()
		and message.get("response", {}) is Dictionary
	)


static func is_unrequested_local_forced_switch(message: Dictionary, local_player_id: String) -> bool:
	# Human switch responses remain correlated with their action waiter. An
	# authoritative timeout switch is broadcast without a request id and must be
	# consumed even while the local party picker is still open.
	return (
		str(message.get("requestId", "")).strip_edges() == ""
		and str(message.get("action", "")).strip_edges().to_lower() == "choose_switch"
		and str(message.get("playerId", "")).strip_edges() == local_player_id.strip_edges()
		and message.get("response", {}) is Dictionary
	)


static func normalize_terminal_winner(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized.to_lower() in ["none", "null", "<null>", "nil"]:
		return ""
	return normalized


static func is_local_terminal_winner(
	winner_value: Variant,
	local_state_player_id: String,
	local_display_name: String
) -> bool:
	var winner := normalize_terminal_winner(winner_value)
	if winner == "":
		return false

	var normalized_winner := winner.to_lower()
	var normalized_local_side := local_state_player_id.strip_edges().to_lower()
	if normalized_winner in ["p1", "player 1", "player1"]:
		return normalized_local_side == "p1"
	if normalized_winner in ["p2", "player 2", "player2"]:
		return normalized_local_side == "p2"

	var normalized_local_name := local_display_name.strip_edges().to_lower()
	return normalized_local_name != "" and normalized_winner == normalized_local_name


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


func _restart_stalled_connection(reason: String) -> void:
	connection_attempt_generation += 1
	joined = false
	join_sent = false
	join_sent_at_msec = 0
	room_is_ready = false
	awaiting_pong = false
	ping_sent_at_msec = 0
	connection_heartbeat_timer = 0.0
	connecting = false
	reconnect_timer = RECONNECT_DELAY_SECONDS
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close(1013, reason.left(120))
	# A peer left in CLOSING can otherwise remain the active object forever and
	# prevent the reconnect loop from reaching its CLOSED-state branch.
	websocket = WebSocketPeer.new()
	if connected:
		connected = false
		connection_changed.emit(false)


func _handle_join_error(message: Dictionary) -> void:
	var code := str(message.get("code", "")).strip_edges().to_lower()
	var reason := str(message.get("error", "Unable to join the PvP battle room."))
	if code in [
		"pvp_identity_resolution_failed",
		"pvp_invalid_viewer_role",
		"pvp_room_already_joined",
		"pvp_spectator_identity_required",
		"pvp_spectator_not_allowed",
	]:
		should_reconnect = false
		connecting = false
		session_invalid.emit(reason)
		if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			websocket.close(SESSION_INVALID_CLOSE_CODE, reason)
		return
	_restart_stalled_connection(reason)


func _handle_battle_events_message(message: Dictionary) -> void:
	var latest_seq := _nonnegative_int(message.get("battleEventLatestSeq", battle_event_latest_seq), battle_event_latest_seq)
	var events_value: Variant = message.get("events", [])
	var valid_event_count := 0
	var pending_events: Dictionary = {}
	var terminal_message: Dictionary = {}
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
		var terminal_payload_value: Variant = event.get("payload", {})
		if str(event.get("type", "")) == "battle.ended" and terminal_payload_value is Dictionary:
			var terminal_payload := terminal_payload_value as Dictionary
			if is_infrastructure_no_contest_payload(terminal_payload):
				terminal_message = {
					"type": "pvp.infrastructure_no_contest",
					"roomCode": str(message.get("roomCode", active_room_code)),
					"battleId": str(message.get("battleId", active_battle_id)),
					"matchId": str(message.get("matchId", active_match_id)),
					"battleEventSeq": next_event_seq,
					"terminalResultId": str(terminal_payload.get("terminalResultId", "")),
					"terminalCategory": "INFRASTRUCTURE_NO_CONTEST",
					"endReason": "infrastructure_no_contest",
					"noContest": true,
					"noPenalty": true,
				}
			else:
				terminal_message = {
					"type": "pvp.authoritative_terminal",
					"roomCode": str(message.get("roomCode", active_room_code)),
					"battleId": str(message.get("battleId", active_battle_id)),
					"matchId": str(message.get("matchId", active_match_id)),
					"battleEventSeq": next_event_seq,
					"winnerSide": str(terminal_payload.get("winnerSide", "")),
					"loserSide": str(terminal_payload.get("loserSide", "")),
					"endReason": str(terminal_payload.get("endReason", terminal_payload.get("reason", "ended"))),
					"source": str(terminal_payload.get("source", "DURABLE_BATTLE_EVENT")),
				}
		last_battle_event_seq = next_event_seq
		next_event_seq += 1

	battle_event_latest_seq = max(battle_event_latest_seq, latest_seq)
	# latestSeq describes the remote head, not locally applied domain order.
	received_battle_event_count += valid_event_count
	if valid_event_count > 0:
		timer_state_changed.emit(timer_projection)
	if not terminal_message.is_empty():
		battle_update_received.emit(terminal_message)
	if latest_seq > last_battle_event_seq:
		_restart_stalled_connection("Durable PvP event catch-up is required.")
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


func decision_for_action(player_id: String, battle_decision: Dictionary) -> Dictionary:
	if timer_projection.authority != BattleTimerProjection.BATTLE_BANK_V1_AUTHORITY:
		return battle_decision
	var timer_value: Variant = timer_projection.participants.get(player_id, {})
	if not (timer_value is Dictionary):
		return battle_decision
	var timer_decision := timer_value as Dictionary
	var timer_generation := int(timer_decision.get("decisionGeneration", 0))
	var battle_generation := int(battle_decision.get("decisionGeneration", 0))
	var timer_decision_id := str(timer_decision.get("decisionId", "")).strip_edges()
	var timer_decision_kind := str(timer_decision.get("decisionKind", "")).strip_edges()
	if timer_generation <= battle_generation or timer_decision_id == "" or timer_decision_kind == "":
		return battle_decision
	return {
		"decisionId": timer_decision_id,
		"decisionGeneration": timer_generation,
		"decisionKind": timer_decision_kind,
	}


static func is_infrastructure_no_contest_payload(payload: Dictionary) -> bool:
	return (
		str(payload.get("category", "")) == "INFRASTRUCTURE_NO_CONTEST"
		and str(payload.get("terminalResultId", "")).strip_edges() != ""
		and bool(payload.get("noContest", false))
		and bool(payload.get("noPenalty", false))
		and normalize_terminal_winner(payload.get("winner", "")) == ""
		and normalize_terminal_winner(payload.get("loser", "")) == ""
		and str(payload.get("endReason", "")) == "infrastructure_no_contest"
	)


static func is_infrastructure_no_contest_message(message: Dictionary) -> bool:
	return (
		str(message.get("type", "")).strip_edges().to_lower() == "pvp.infrastructure_no_contest"
		and str(message.get("terminalCategory", "")) == "INFRASTRUCTURE_NO_CONTEST"
		and str(message.get("terminalResultId", "")).strip_edges() != ""
		and bool(message.get("noContest", false))
		and bool(message.get("noPenalty", false))
		and str(message.get("endReason", "")) == "infrastructure_no_contest"
	)


static func is_infrastructure_no_contest_result(result: Dictionary) -> bool:
	return (
		str(result.get("terminalCategory", result.get("category", ""))) == "INFRASTRUCTURE_NO_CONTEST"
		and str(result.get("terminalResultId", "")).strip_edges() != ""
		and bool(result.get("noContest", false))
		and bool(result.get("noPenalty", false))
		and str(result.get("reason", result.get("endReason", ""))) == "infrastructure_no_contest"
	)


static func allows_gameplay_persistence_for_terminal(result: Dictionary) -> bool:
	return not is_infrastructure_no_contest_result(result)


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
