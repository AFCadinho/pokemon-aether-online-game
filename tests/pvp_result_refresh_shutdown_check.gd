extends SceneTree

class SummaryFixture extends Node:
	var server := TCPServer.new()
	var peers: Array[StreamPeerTCP] = []
	var buffers: Array[String] = []
	var requests := 0
	var complete := false
	var request_times: Array[int] = []

	func _process(_delta: float) -> void:
		while server.is_connection_available():
			peers.append(server.take_connection())
			buffers.append("")
		for index in range(peers.size() - 1, -1, -1):
			var peer := peers[index]
			peer.poll()
			var available := peer.get_available_bytes()
			if available > 0:
				buffers[index] += peer.get_data(available)[1].get_string_from_utf8()
			if not buffers[index].contains("\r\n\r\n"):
				continue
			requests += 1
			request_times.append(Time.get_ticks_msec())
			var changes := [{"userId": 1, "ratingAfter": 1002, "ratingDelta": 2}] if complete and requests >= 2 else []
			var body := JSON.stringify({"success": true, "match": {"ratingChanges": changes, "result": {"rewardsReady": false}}})
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]).to_utf8_buffer())
			peers.remove_at(index)
			buffers.remove_at(index)

	func _exit_tree() -> void:
		for peer in peers:
			peer.disconnect_from_host()
		peers.clear()
		buffers.clear()
		server.stop()

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := SummaryFixture.new()
	if fixture.server.listen(0, "127.0.0.1") != OK:
		fixture.free()
		push_error("Local summary fixture could not bind")
		quit(1)
		return
	root.add_child(fixture)
	var config = root.get_node("GatewayApiConfig")
	var old_url: String = config.cached_url
	config.cached_url = "http://127.0.0.1:%d" % fixture.server.get_local_port()
	var auth = root.get_node("AuthService")
	var old_user: Dictionary = auth.current_user
	auth.current_user = {"id": 1}
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	battle._refresh_pvp_battle_rating("shutdown-fixture")
	var deadline := Time.get_ticks_msec() + 3000
	while fixture.requests < 1 and Time.get_ticks_msec() < deadline:
		await process_frame
	while Time.get_ticks_msec() < deadline and battle.get_node("PvpResultRefreshRetryTimer").is_stopped():
		await process_frame
	var retry: Timer = battle.get_node("PvpResultRefreshRetryTimer")
	_check(not retry.is_stopped(), "Pending summary waits on a battle-owned retry timer")
	_check(retry.one_shot and retry.process_mode == Node.PROCESS_MODE_ALWAYS and is_equal_approx(retry.wait_time, 0.5), "Normal half-second retry and paused-tree behavior are preserved")
	var retry_ref: WeakRef = weakref(retry)
	retry = null
	battle.queue_free()
	await process_frame
	await process_frame
	_check(retry_ref.get_ref() == null, "Closing a real battle destroys its pending result retry")
	fixture.requests = 0
	fixture.request_times.clear()
	fixture.complete = true
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	battle._refresh_pvp_battle_rating("shutdown-fixture")
	deadline = Time.get_ticks_msec() + 3000
	while not battle.pending_battle_end_result.has("ratingChange") and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	_check(int(battle.pending_battle_end_result.get("ratingChange", {}).get("ratingDelta", 0)) == 2, "Normal rating refresh still applies the eventual summary")
	_check(fixture.request_times.size() == 2 and fixture.request_times[1] - fixture.request_times[0] >= 490, "Summary retries are not accelerated")
	_check(battle.get_node_or_null("PvpResultRefreshRetryTimer") == null, "Successful refresh releases its retry timer")
	battle.queue_free()
	config.cached_url = old_url
	auth.current_user = old_user
	fixture.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
