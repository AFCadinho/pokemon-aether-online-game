extends SceneTree

const FUTURE_SELF := "kanto_rock_tunnel_future_self"

class MetadataFixture extends Node:
	var server := TCPServer.new()
	var connections: Array[Dictionary] = []
	var requests: Dictionary = {}

	func _process(_delta: float) -> void:
		while server.is_connection_available():
			connections.append({"peer": server.take_connection(), "buffer": "", "due": 0, "body": ""})
		for index: int in range(connections.size() - 1, -1, -1):
			var connection := connections[index]
			var peer: StreamPeerTCP = connection.peer
			peer.poll()
			if int(connection.due) > 0:
				if Time.get_ticks_msec() >= int(connection.due):
					peer.put_data(str(connection.body).to_utf8_buffer())
					connections.remove_at(index)
				continue
			var available := peer.get_available_bytes()
			if available > 0:
				connection.buffer += peer.get_data(available)[1].get_string_from_utf8()
			if not str(connection.buffer).contains("\r\n\r\n"):
				continue
			var id := str(connection.buffer).get_slice(" ", 1).get_file()
			requests[id] = int(requests.get(id, 0)) + 1
			if id == "timeout-once" and int(requests[id]) == 1:
				# Hold the first connection open without a response until the
				# actual production request deadline triggers the retry.
				connection.due = Time.get_ticks_msec() + 60000
				continue
			if id == "disconnect-always" or (id == "disconnect-once" and int(requests[id]) == 1):
				peer.disconnect_from_host()
				connections.remove_at(index)
				continue
			var body := JSON.stringify({"trainer": {
				"id": id, "name": "Mysterious Trainer",
				"introDialogueId": "kanto_rock_tunnel_future_self_challenge",
				"dialogue_before_battle": ["A valid challenge."],
			}})
			var status := "200 OK"
			if id == "missing":
				status = "404 Not Found"
				body = JSON.stringify({"detail": "Trainer not found"})
			elif id == "malformed":
				body = "invalid JSON"
			elif id == "missing-trainer":
				body = "{}"
			var headers := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, body.to_utf8_buffer().size()]
			peer.put_data(headers.to_utf8_buffer())
			if id == "kanto_rock_tunnel_future_self":
				# A valid HTTP 200 whose body arrives after the old three-second
				# deadline reproduces the reported pre-battle failure path.
				connection.body = body
				connection.due = Time.get_ticks_msec() + 4000
			else:
				peer.put_data(body.to_utf8_buffer())
				connections.remove_at(index)

	func _exit_tree() -> void:
		for connection: Dictionary in connections:
			(connection.peer as StreamPeerTCP).disconnect_from_host()
		connections.clear()
		server.stop()

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := MetadataFixture.new()
	if fixture.server.listen(0, "127.0.0.1") != OK:
		fixture.free()
		push_error("Trainer metadata fixture could not bind")
		quit(1)
		return
	root.add_child(fixture)
	var config := root.get_node("GatewayApiConfig")
	var original_url: String = config.cached_url
	config.cached_url = "http://127.0.0.1:%d" % fixture.server.get_local_port()
	var service := load("res://scripts/services/trainer_metadata_service.gd").new() as Node
	root.add_child(service)
	var response: Dictionary = await service.get_trainer_metadata(FUTURE_SELF)
	_check(bool(response.get("success", false)), "a valid trainer body arriving after four seconds is accepted")
	_check(response.get("metadata", {}).get("introDialogueId") == "kanto_rock_tunnel_future_self_challenge", "slow story encounter preserves its dialogue reference")
	_check(int(fixture.requests.get(FUTURE_SELF, 0)) == 1, "slow successful response does not need a retry")
	await service.get_trainer_metadata(FUTURE_SELF)
	_check(int(fixture.requests.get(FUTURE_SELF, 0)) == 1, "successful trainer metadata is cached")
	response = await service.get_trainer_metadata("disconnect-once")
	_check(bool(response.get("success", false)) and int(fixture.requests.get("disconnect-once", 0)) == 2, "a temporary connection failure retries once and recovers")
	response = await service.get_trainer_metadata("disconnect-always")
	_check(not bool(response.get("success", true)) and int(fixture.requests.get("disconnect-always", 0)) == 2, "persistent transport failure stops after two attempts")
	_check(int(response.get("code", HTTPRequest.RESULT_SUCCESS)) != HTTPRequest.RESULT_SUCCESS, "failed transport preserves its result instead of reporting invalid JSON")
	response = await service.get_trainer_metadata("timeout-once")
	_check(bool(response.get("success", false)) and int(fixture.requests.get("timeout-once", 0)) == 2, "a real request timeout retries once and recovers")
	for id: String in ["missing", "malformed", "missing-trainer"]:
		response = await service.get_trainer_metadata(id)
		_check(not bool(response.get("success", true)) and int(fixture.requests.get(id, 0)) == 1, id + " is rejected without a transport retry")
		_check(not service.trainer_metadata_cache.has(id), id + " is not cached as valid trainer metadata")
	service.queue_free()
	config.cached_url = original_url
	fixture.queue_free()
	await process_frame
	print("trainer_metadata_transport_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error(message)
