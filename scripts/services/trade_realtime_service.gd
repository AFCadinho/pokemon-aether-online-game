extends Node

class_name TradeRealtimeServiceNode

signal snapshot_received(trade: Dictionary)
signal event_received(event: Dictionary)
signal recovery_required(trade_id: String, after_seq: int)
signal connection_changed(connected: bool)
signal active_trade_changed(trade: Dictionary)
signal invitation_received(trade: Dictionary)
signal offer_update_received(event: Dictionary)

var active_trade_id := ""
var last_applied_event_seq := 0
var latest_revision := 0
var recovery_in_progress := false
var recovery_attempts := 0
var buffered_events: Array[Dictionary] = []
var trade_service_override: Object
const MAX_RECOVERY_ATTEMPTS := 3
const MAX_RECONNECT_ATTEMPTS := 3
const RECONNECT_DELAY_SECONDS := 2.0
const ACTIVE_TRADE_DISCOVERY_INTERVAL_SECONDS := 3.0
var websocket := WebSocketPeer.new()
var should_reconnect := false
var reconnect_attempts := 0
var reconnect_timer := 0.0
var socket_generation := 0
var connected := false
var connecting := false
var websocket_url := ""
var active_trade_snapshot: Dictionary = {}
var completion_refresh_attempts := 0
var active_trade_discovery_elapsed := 0.0
var active_trade_discovery_in_flight := false

func _process(delta: float) -> void:
	poll_trade_socket()
	_discover_active_trade_if_needed(delta)
	if should_reconnect and not connected and not connecting and active_trade_id != "" and websocket_url != "" and reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		reconnect_timer -= delta
		if reconnect_timer <= 0.0:
			connect_trade_socket(websocket_url)

func build_join_message() -> Dictionary:
	return {"v": 1, "type": "trade.join", "tradeId": active_trade_id, "lastEventSeq": last_applied_event_seq}

func handle_transport_message(message: Dictionary, generation: int) -> void:
	if generation != socket_generation or int(message.get("v", 0)) != 1:
		return
	match str(message.get("type", "")):
		"trade.snapshot": apply_snapshot(message.get("trade", {}))
		"trade.events":
			var events: Variant = message.get("events", [])
			if events is Array:
				for event: Variant in events:
					if event is Dictionary: apply_event(event)
		"trade.event": apply_event(message.get("event", {}))

func begin_reconnect() -> bool:
	if connecting or active_trade_id == "" or reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
		return false
	connecting = true
	should_reconnect = true
	reconnect_attempts += 1
	socket_generation += 1
	return true

func connect_trade_socket(websocket_url: String) -> Error:
	if not begin_reconnect():
		return ERR_ALREADY_IN_USE
	self.websocket_url = websocket_url
	websocket = WebSocketPeer.new()
	var error := websocket.connect_to_url(websocket_url)
	if error != OK:
		connecting = false
		reconnect_timer = RECONNECT_DELAY_SECONDS
	return error

func poll_trade_socket() -> void:
	websocket.poll()
	var generation := socket_generation
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN and not connected:
		var join := mark_socket_open(generation)
		if not join.is_empty(): websocket.send_text(JSON.stringify(join))
	while websocket.get_ready_state() == WebSocketPeer.STATE_OPEN and websocket.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(websocket.get_packet().get_string_from_utf8())
		if parsed is Dictionary: handle_transport_message(parsed, generation)
	if connected and websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		mark_socket_closed(generation)

func mark_socket_open(generation: int) -> Dictionary:
	if generation != socket_generation:
		return {}
	connecting = false
	connected = true
	reconnect_attempts = 0
	connection_changed.emit(true)
	return build_join_message()

func mark_socket_closed(generation: int) -> void:
	if generation != socket_generation:
		return
	connected = false
	connecting = false
	reconnect_timer = RECONNECT_DELAY_SECONDS
	connection_changed.emit(false)

func apply_snapshot(trade: Dictionary) -> void:
	var trade_id := str(trade.get("tradeId", "")).strip_edges()
	if trade_id == "":
		return
	var revision := maxi(int(trade.get("revision", 0)), 0)
	if trade_id != active_trade_id or revision > latest_revision or (revision == latest_revision and int(trade.get("lastEventSeq", 0)) >= last_applied_event_seq):
		active_trade_id = trade_id
		latest_revision = revision
		last_applied_event_seq = maxi(int(trade.get("lastEventSeq", 0)), 0)
		active_trade_snapshot = trade.duplicate(true)
		snapshot_received.emit(active_trade_snapshot.duplicate(true))
		active_trade_changed.emit(active_trade_snapshot.duplicate(true))
		if str(trade.get("status", "")) == "invited" and _is_recipient(trade):
			invitation_received.emit(active_trade_snapshot.duplicate(true))

func apply_event(event: Dictionary) -> void:
	if str(event.get("tradeId", "")).strip_edges() != active_trade_id:
		return
	var seq := int(event.get("eventSeq", 0))
	if seq <= last_applied_event_seq:
		return
	if recovery_in_progress:
		buffered_events.append(event.duplicate(true))
		return
	if seq != last_applied_event_seq + 1:
		if not recovery_in_progress:
			recovery_in_progress = true
			recovery_required.emit(active_trade_id, last_applied_event_seq)
			recover_from_rest.call_deferred()
		return
	last_applied_event_seq = seq
	latest_revision = maxi(latest_revision, int(event.get("revision", 0)))
	var event_type := str(event.get("type", ""))
	var next_status := str(_dictionary(event.get("payload", {})).get("status", ""))
	if next_status != "" and event_type != "trade.completed" and not active_trade_snapshot.is_empty():
		active_trade_snapshot["status"] = next_status
		active_trade_snapshot["revision"] = latest_revision
		active_trade_snapshot["lastEventSeq"] = last_applied_event_seq
		active_trade_changed.emit(active_trade_snapshot.duplicate(true))
	event_received.emit(event.duplicate(true))
	if event_type == "trade.offer_updated":
		offer_update_received.emit(event.duplicate(true))
		refresh_authoritative_snapshot.call_deferred()
	if event_type in ["trade.accepted", "trade.readiness_changed", "trade.locked", "trade.unlocked", "trade.reconnect_grace_started", "trade.reconnect_grace_cancelled"]:
		refresh_authoritative_snapshot.call_deferred()
	if event_type == "trade.participant_confirmed":
		refresh_authoritative_snapshot.call_deferred()
	if event_type == "trade.completed":
		refresh_completed_trade.call_deferred(active_trade_id)
	if event_type in ["trade.declined", "trade.cancelled", "trade.expired"]:
		stop_transport(true)

func apply_recovery(snapshot: Dictionary, events: Array) -> void:
	apply_snapshot(snapshot)
	recovery_in_progress = false
	for event_value: Variant in events:
		if event_value is Dictionary:
			apply_event(event_value)
	buffered_events.sort_custom(func(first, second): return int(first.get("eventSeq", 0)) < int(second.get("eventSeq", 0)))
	var pending := buffered_events.duplicate(true)
	buffered_events.clear()
	for event: Dictionary in pending:
		apply_event(event)

func clear_active_trade() -> void:
	stop_transport(false)


func stop_transport(preserve_snapshot := false) -> void:
	should_reconnect = false
	connecting = false
	connected = false
	socket_generation += 1
	websocket_url = ""
	active_trade_id = ""
	last_applied_event_seq = 0
	latest_revision = 0
	recovery_in_progress = false
	recovery_attempts = 0
	active_trade_discovery_elapsed = 0.0
	buffered_events.clear()
	if not preserve_snapshot:
		active_trade_snapshot.clear()


func restore_active_trade_and_connect() -> Dictionary:
	var trade_service := trade_service_override if trade_service_override != null else get_node_or_null("/root/TradeService")
	if trade_service == null:
		return {"success": false, "error": "Trade service unavailable."}
	if trade_service.has_method("load_capabilities"):
		await trade_service.call("load_capabilities", true)
	var result: Dictionary = await trade_service.call("load_active_trade")
	if not bool(result.get("success", false)):
		return result
	if not bool(result.get("hasActiveTrade", false)):
		clear_active_trade()
		return result
	apply_snapshot(_dictionary(result.get("trade", {})))
	var url := await _authenticated_websocket_url()
	if url != "":
		should_reconnect = true
		connect_trade_socket(url)
	return result


func _discover_active_trade_if_needed(delta: float) -> void:
	if active_trade_id != "" or active_trade_discovery_in_flight or not _is_authenticated():
		return
	active_trade_discovery_elapsed += delta
	if active_trade_discovery_elapsed < ACTIVE_TRADE_DISCOVERY_INTERVAL_SECONDS:
		return
	active_trade_discovery_elapsed = 0.0
	discover_active_trade.call_deferred()


func discover_active_trade() -> Dictionary:
	if active_trade_id != "" or active_trade_discovery_in_flight:
		return {"success": false, "error": "Trade discovery is not needed."}
	var trade_service := trade_service_override if trade_service_override != null else get_node_or_null("/root/TradeService")
	if trade_service == null:
		return {"success": false, "error": "Trade service unavailable."}
	active_trade_discovery_in_flight = true
	var result: Dictionary = await trade_service.call("load_active_trade")
	active_trade_discovery_in_flight = false
	if not bool(result.get("success", false)) or not bool(result.get("hasActiveTrade", false)):
		return result
	apply_snapshot(_dictionary(result.get("trade", {})))
	var url := await _authenticated_websocket_url()
	if url != "" and not connected and not connecting:
		should_reconnect = true
		connect_trade_socket(url)
	return result


func _authenticated_websocket_url() -> String:
	if not is_inside_tree():
		return ""
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	var auth := get_node_or_null("/root/AuthService")
	if gateway == null or auth == null:
		return ""
	var base_url: String = await gateway.call("get_base_url")
	var scheme := "wss://" if base_url.begins_with("https://") else "ws://"
	var host := base_url.trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
	return scheme + host + "/ws/trade?token=" + str(auth.get("session_token")).uri_encode()


func _is_authenticated() -> bool:
	if not is_inside_tree():
		return trade_service_override != null
	var auth := get_node_or_null("/root/AuthService")
	return auth != null and bool(auth.call("is_authenticated"))


func _is_recipient(trade: Dictionary) -> bool:
	if not is_inside_tree():
		return false
	var auth := get_node_or_null("/root/AuthService")
	if auth == null:
		return false
	var user_id := int(_dictionary(auth.get("current_user")).get("id", 0))
	for participant_value: Variant in trade.get("participants", []):
		var participant := _dictionary(participant_value)
		if int(participant.get("userId", 0)) == user_id:
			return str(participant.get("role", "")) == "recipient"
	return false


func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func recover_from_rest() -> void:
	if not recovery_in_progress or active_trade_id == "" or recovery_attempts >= MAX_RECOVERY_ATTEMPTS:
		return
	recovery_attempts += 1
	var trade_service := trade_service_override if trade_service_override != null else get_node_or_null("/root/TradeService")
	if trade_service == null:
		return
	var snapshot_result: Dictionary = await trade_service.call("load_trade", active_trade_id)
	if not bool(snapshot_result.get("success", false)):
		return
	var snapshot: Dictionary = snapshot_result.get("trade", {})
	if str(snapshot.get("tradeId", "")) != active_trade_id:
		return
	var boundary := maxi(int(snapshot.get("lastEventSeq", 0)), 0)
	var events_result: Dictionary = await trade_service.call("load_trade_events", active_trade_id, boundary, 100)
	if not bool(events_result.get("success", false)):
		return
	var page: Dictionary = events_result.get("events", {})
	var events_value: Variant = page.get("events", [])
	apply_recovery(snapshot, events_value if events_value is Array else [])


func refresh_authoritative_snapshot() -> void:
	if active_trade_id == "":
		return
	if trade_service_override == null and not is_inside_tree():
		return
	var trade_service := trade_service_override if trade_service_override != null else get_node_or_null("/root/TradeService")
	if trade_service == null:
		return
	var result: Dictionary = await trade_service.call("load_trade", active_trade_id)
	if bool(result.get("success", false)):
		apply_snapshot(_dictionary(result.get("trade", {})))


func refresh_completed_trade(trade_id: String) -> void:
	if trade_id == "":
		return
	var trade_service := trade_service_override if trade_service_override != null else get_node_or_null("/root/TradeService")
	if trade_service == null:
		return
	completion_refresh_attempts = 0
	while completion_refresh_attempts < MAX_RECOVERY_ATTEMPTS:
		completion_refresh_attempts += 1
		var result: Dictionary = await trade_service.call("load_trade", trade_id)
		if bool(result.get("success", false)):
			var snapshot := _dictionary(result.get("trade", {}))
			if str(snapshot.get("status", "")) == "completed":
				apply_snapshot(snapshot)
				stop_transport(true)
				return
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.5).timeout
