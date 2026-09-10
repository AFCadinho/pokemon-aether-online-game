extends SceneTree

var failed := false
var api: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	api = root.get_node("BattleApiClient")
	var config := root.get_node("GatewayApiConfig")
	var request := HTTPRequest.new()
	root.add_child(request)
	api._configure_request_timeout(request)
	_check(request.timeout == 15.0, "unbounded requests receive the battle deadline")
	request.timeout = 0.1
	api._configure_request_timeout(request)
	_check(is_equal_approx(request.timeout, 0.1), "explicit budgets are preserved")
	var server := TCPServer.new()
	_check(server.listen(0, "127.0.0.1") == OK, "local fixture listens")
	var original_url: String = config.cached_url
	config.cached_url = "http://127.0.0.1:%d" % server.get_local_port()
	# A real HTTPRequest against a peer that accepts and never answers must
	# return through the same API used by queue/start/recovery callers.
	var outcome := {"done": false, "response": {}}
	_request_silent_peer(request, outcome)
	var deadline := Time.get_ticks_msec() + 2000
	var peer: StreamPeerTCP
	while not outcome["done"] and Time.get_ticks_msec() < deadline:
		if peer == null and server.is_connection_available():
			peer = server.take_connection()
		await process_frame
	_check(outcome["done"], "silent upstream returns within its budget")
	_check(not bool(outcome["response"].get("success", true)), "timeout is an unsuccessful response")
	_check(outcome["response"].get("code") == HTTPRequest.RESULT_TIMEOUT, "timeout retains its transport code")
	if peer != null:
		peer.disconnect_from_host()
	server.stop()
	config.cached_url = original_url
	request.cancel_request()
	request.queue_free()
	var service := PvpBattleRealtimeServiceNode.new()
	service.should_reconnect = true
	service.connection_attempt_deadline_msec = 100
	_check(not service._process_connect_timeout(99), "connect attempt keeps its budget")
	_check(service._process_connect_timeout(100), "stalled setup enters reconnect")
	_check(service.should_reconnect and service.connection_attempt_deadline_msec == 0, "timeout retires attempt without abandoning battle")
	service.free()
	print("PASS battle_network_deadline_check" if not failed else "FAIL battle_network_deadline_check")
	quit(1 if failed else 0)

func _request_silent_peer(request: HTTPRequest, outcome: Dictionary) -> void:
	outcome["response"] = await api.send_get_request(request, "/synthetic-silent-peer")
	outcome["done"] = true

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
