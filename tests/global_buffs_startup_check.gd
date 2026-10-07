extends SceneTree

var failed := false
var auth: Node
var captured: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	for child in root.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	auth = root.get_node("AuthService")
	_account("buff-a", 1)
	await _check_transport()
	_check_hud()
	auth.current_user = {}
	auth.session_token = ""
	await process_frame
	await process_frame
	print("global_buffs_startup_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _body() -> Dictionary:
	var boosts: Array = []
	for boost_id: String in root.get_node("PlayerWalletService").GLOBAL_BOOST_ENDPOINTS:
		boosts.append({"id": boost_id, "current": 12, "goal": 100000, "active": false})
	return {"boosts": boosts, "heal": {"id": "global_heal", "available": true}}

func _probe() -> Node:
	var probe: Node = load("res://tests/fixtures/global_buffs_wallet_probe.gd").new()
	root.add_child(probe)
	return probe

func _check_transport() -> void:
	var probe := _probe()
	probe.responses = [{"success": true, "status": 200, "body": _body()}]
	var result: Dictionary = await probe.load_global_buffs()
	_expect(result.success and probe.requests.size() == 1 and probe.requests[0].ends_with("/game/global-buffs"), "new backends need one GET for all five boosts and heal")
	probe.free()
	for response: Dictionary in [{"success": false, "status": 401}, {"success": false, "status": 500}, {"success": false, "status": 503}, {"success": false, "status": 0}, {"success": true, "status": 200, "body": {"boosts": [], "heal": {}}}]:
		probe = _probe()
		probe.responses = [response]
		result = await probe.load_global_buffs()
		_expect(not result.success and probe.requests.size() == 1, "auth/server/transport/malformed replies do not fan out")
		probe.free()
	probe = _probe()
	probe.responses = [{"success": false, "status": 404}]
	for boost: Dictionary in _body().boosts:
		probe.responses.append({"success": true, "status": 200, "body": boost})
	probe.responses.append({"success": true, "status": 200, "body": _body().heal})
	probe.delayed = true
	_capture(probe)
	for index in range(7):
		_expect(probe.requests.size() == index + 1, "legacy fallback starts only one request at a time")
		probe.reply.emit()
	_expect(captured.success and captured.body.boosts.size() == 5 and captured.body.heal.id == "global_heal", "404 preserves all six older reads")
	probe.free()
	probe = _probe()
	probe.responses = [{"success": true, "status": 200, "body": _body()}]
	probe.delayed = true
	_capture(probe)
	_account("buff-b", 2)
	probe.reply.emit()
	_expect(not captured.success, "late snapshot cannot cross an account boundary")
	probe.free()
	_account("buff-a", 1)
	probe = _probe()
	probe.responses = [{"success": false, "status": 404}]
	probe.delayed = true
	_capture(probe)
	_account("buff-a-renewed", 1)
	probe.reply.emit()
	_expect(not captured.success and probe.requests.size() == 1, "changed session cannot start legacy requests")
	probe.free()
	_account("buff-a", 1)
	probe = _probe()
	probe.delayed_base = true
	_capture(probe)
	_account("buff-b", 2)
	probe.base_reply.emit()
	_expect(not captured.success and probe.requests.is_empty(), "changed account during base resolution sends no request")
	probe.free()
	_account("buff-a", 1)
	probe = _probe()
	auth.session_token = ""
	result = await probe.load_global_buffs()
	_expect(not result.success and probe.requests.is_empty(), "unauthenticated startup sends no requests")
	probe.free()
	_account("buff-a", 1)

func _check_hud() -> void:
	var hud: Node = load("res://tests/fixtures/global_buffs_hud_probe.gd").new()
	var revisions: Dictionary = hud.global_buff_state_revisions.duplicate()
	hud._apply_global_boost_state({"id": "global_exp", "current": 99}, "global_exp")
	hud._apply_global_heal_state({"id": "global_heal", "available": false})
	hud._apply_startup_global_buffs(_body(), revisions)
	_expect(hud.applied.global_exp.current == 99 and not hud.applied.global_heal.available, "newer boost/heal updates survive a late startup snapshot")
	_expect(hud.applied.size() == 6 and hud.applied.global_ev.current == 12, "unchanged boosts are still initialized by that snapshot")
	hud.free()

func _capture(probe: Node) -> void:
	captured = await probe.load_global_buffs()

func _account(token: String, user_id: int) -> void:
	auth.session_token = token
	auth.current_user = {"id": user_id}

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
