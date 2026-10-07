extends SceneTree

const VisualQueue := preload("res://scripts/world/remote_player_visual_queue.gd")
var failed := false
var applied: Dictionary = {}
var removed: Array[int] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	for child in root.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	_check_queue()
	await _check_realtime_boundary()
	print("remote_player_visual_queue_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _check_queue() -> void:
	var queue := VisualQueue.new()
	queue.player_state_ready.connect(func(state: Dictionary): applied[int(state.userId)] = state)
	queue.player_removal_ready.connect(func(user_id: int): removed.append(user_id); applied.erase(user_id))
	for index in range(1000):
		queue.queue_update({"userId": 1, "x": index})
	_expect(queue.pending.size() == 1 and queue.order.size() == 1, "movement bursts retain only the latest visual state per player")
	queue.queue_update({"userId": 2, "x": 3})
	queue.queue_removal(1)
	queue.drain(100000, 1)
	_expect(removed == [1] and not applied.has(1) and queue.pending.size() == 1, "leave cancels a pending spawn and one-operation limit is enforced")
	queue.drain()
	_expect(applied[2].x == 3 and queue.pending.is_empty(), "remaining updates drain on later frames")
	queue.queue_removal(2)
	queue.queue_update({"userId": 2, "x": 4})
	queue.drain()
	_expect(applied[2].x == 4, "rejoin supersedes a queued removal")
	queue.queue_update({"userId": 99})
	queue.replace_snapshot([{"userId": 3}], ["2"])
	queue.drain(100000, 10)
	_expect(not applied.has(2) and applied.has(3) and not applied.has(99), "replacement snapshots remove absent avatars and discard stale pending spawns")
	queue.queue_update({"userId": 5})
	queue.clear()
	queue.drain()
	_expect(not applied.has(5) and not queue.is_processing(), "map/account reset clears all pending visuals")
	applied.clear()
	for user_id in range(1, 81):
		queue.queue_update({"userId": user_id})
	for index in range(20):
		_expect(queue.drain(100000, 4) == 4, "frame cap remains effective through queue compaction")
	_expect(applied.size() == 80 and queue.order.is_empty(), "queue compaction neither duplicates nor drops players")
	queue.queue_update({"userId": 81})
	queue.queue_update({"userId": 82})
	_expect(queue.drain(0, 4) == 1 and queue.pending.size() == 1, "time budget stops before starting a second visual operation")
	queue.free()

func _check_realtime_boundary() -> void:
	# Real WebSocket packets exercise the production service and world signal
	# handlers; the expensive avatar renderer is replaced by a 5 ms callback.
	var service: Node = load("res://scripts/services/world_presence_service.gd").new()
	var world: Node = load("res://tests/fixtures/remote_player_queue_world_probe.gd").new()
	var player_node := CharacterBody2D.new()
	player_node.name = "Player"
	world.add_child(player_node)
	var flash: Node = load("res://scripts/world/field_move_flash_light.gd").new()
	flash.name = "FieldMoveFlashLight"
	var light := PointLight2D.new()
	light.name = "PointLight2D"
	flash.add_child(light)
	player_node.add_child(flash)
	var canvas := CanvasModulate.new()
	canvas.name = "WorldCanvasModulate"
	world.add_child(canvas)
	var day_night: Node = load("res://scripts/world/day_night_controller.gd").new()
	day_night.name = "DayNightController"
	day_night.canvas_modulate_path = NodePath("../WorldCanvasModulate")
	_add_unique(world, day_night)
	var battle_host := Control.new()
	battle_host.name = "BattleUIHost"
	_add_unique(world, battle_host)
	var transition: Node = load("res://scripts/ui/wild_encounter_transition.gd").new()
	transition.name = "WildEncounterTransition"
	_add_unique(world, transition)
	var weather: Node = load("res://scenes/world/weather/overworld_weather_controller.tscn").instantiate()
	weather.name = "WeatherController"
	world.add_child(weather)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	world.heavy_visuals = true
	service.roster_changed.connect(world._on_world_presence_roster_changed)
	service.roster_player_changed.connect(world._on_world_presence_roster_player_changed)
	service.roster_player_removed.connect(world._on_world_presence_roster_player_removed)
	var server := TCPServer.new()
	var port := 23000 + OS.get_process_id() % 10000
	var listening := false
	for offset in range(100):
		if server.listen(port + offset, "127.0.0.1") == OK:
			port += offset
			listening = true
			break
	_expect(listening, "fixture TCP server starts")
	var peer := WebSocketPeer.new()
	_expect(service.websocket.connect_to_url("ws://127.0.0.1:%d" % port) == OK, "fixture WebSocket connects")
	var accepted := false
	var deadline := Time.get_ticks_msec() + 3000
	while service.websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if not accepted and server.is_connection_available():
			peer.accept_stream(server.take_connection())
			accepted = true
		if accepted:
			peer.poll()
		service.websocket.poll()
		if Time.get_ticks_msec() > deadline:
			_expect(false, "WebSocket fixture handshake completes")
			break
		await process_frame
	var players: Array = []
	for user_id in range(1, 25):
		players.append({"userId": user_id, "mapId": "fixture"})
	service.latency.sent(Time.get_ticks_msec())
	peer.send_text(JSON.stringify({"type": "snapshot", "rosterRevision": 1, "players": players}))
	peer.send_text(JSON.stringify({"type": "pong"}))
	deadline = Time.get_ticks_msec() + 3000
	while service.latency.received_at < 0 and Time.get_ticks_msec() < deadline:
		peer.poll()
		service.websocket.poll()
		service._process_packets()
		if service.latency.received_at < 0:
			await process_frame
	_expect(service.get_current_map_players().size() == 24 and service.roster_revision == 1, "authoritative roster is immediately complete")
	_expect(world.applied.is_empty() and world.remote_player_visual_queue.pending.size() == 24, "network callbacks queue visuals without invoking the renderer")
	_expect(service.latency.received_at >= 0, "pong is measured while visual updates are still pending")
	var started := Time.get_ticks_usec()
	var processed: int = world.remote_player_visual_queue.drain()
	var duration := Time.get_ticks_usec() - started
	_expect(processed == 1 and world.applied.size() == 1, "heavy avatar callback cannot cause a full snapshot to render in one frame")
	print("remote_player_visual_queue_check: synthetic visual callback_us=%d pending=%d" % [duration, world.remote_player_visual_queue.pending.size()])
	service._apply_player_left_message({"rosterRevision": 2, "userId": 2})
	service._apply_player_update_message({"rosterRevision": 1, "userId": 2})
	_expect(not service.current_map_players.has("2"), "stale update cannot revive a departed authoritative player")
	world.heavy_visuals = false
	world.remote_player_visual_queue.drain(100000, 100)
	_expect(not world.applied.has(2) and world.removals.has(2), "pending visual removal wins over older movement")
	world._apply_remote_player_states([{"userId": 99}], false)
	world._clear_remote_players()
	_expect(world.remote_player_visual_queue.pending.is_empty(), "actual world map/account clear cancels queued visuals")
	service.websocket.close()
	peer.close()
	server.stop()
	world.free()
	service.free()

func _add_unique(world: Node, child: Node) -> void:
	world.add_child(child)
	child.owner = world
	child.unique_name_in_owner = true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
