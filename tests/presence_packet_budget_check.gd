extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var service_script := load("res://scripts/services/world_presence_service.gd") as Script
	var service: Node = service_script.new()
	var server := TCPServer.new()
	var port := 23000 + OS.get_process_id() % 10000
	var listening := false
	for offset in 100:
		if server.listen(port + offset, "127.0.0.1") == OK:
			port += offset
			listening = true
			break
	if not listening:
		push_error("Could not bind isolated loopback test port")
		quit(1)
		return
	var sender := WebSocketPeer.new()
	service.websocket.connect_to_url("ws://127.0.0.1:%s" % port)
	for _attempt in 200:
		service.websocket.poll()
		if server.is_connection_available():
			sender.accept_stream(server.take_connection())
		sender.poll()
		if service.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await create_timer(0.005).timeout
	_check(service.websocket.get_ready_state() == WebSocketPeer.STATE_OPEN, "local test websocket connects")
	for index in 100:
		sender.send_text(JSON.stringify({"type": "player_update", "rosterRevision": index + 1,
			"userId": index + 1, "position": {"x": index, "y": 32}}))
	for _attempt in 200:
		sender.poll()
		service.websocket.poll()
		if service.websocket.get_available_packet_count() == 100:
			break
		await create_timer(0.005).timeout
	_check(service.websocket.get_available_packet_count() == 100, "all synthetic packets reach the queue")
	service._process_packets()
	_check(service.current_map_players.size() > 0 and service.current_map_players.size() < 100, "burst is split across frame budgets")
	for _frame in 100:
		service._process_packets()
		if service.websocket.get_available_packet_count() == 0:
			break
	_check(service.current_map_players.size() == 100 and service.roster_revision == 100, "all updates remain ordered and no packets are dropped")
	var appearance := {"body": "Gen4_Base_v1", "hair_color": "#123456", "hair_style_index": 2}
	_check(service._build_appearance_payload(appearance) == appearance, "canonical appearance fields are retained")
	var movement := {"isMoving": true, "mountId": "lapras", "activityStyle": "surf"}
	_check(service._build_movement_payload(movement) == movement, "movement payload retains mount and activity")
	service.websocket.close()
	sender.close()
	server.stop()
	service.free()
	print("presence_packet_budget_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
