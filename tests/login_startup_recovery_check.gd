extends SceneTree
var failures := 0
var login: Control

func _init() -> void: _run.call_deferred()
func _run() -> void:
	login = load("res://scenes/interface/login_screen.tscn").instantiate()
	login.set_script(load("res://tests/fixtures/login_startup_recovery_probe.gd"))
	root.add_child(login)
	var timer := Timer.new()
	login.add_child(timer)
	login.server_health_retry_timer = timer
	await _health_startup()
	await _restore_recovery()
	login.free()
	print("login_startup_recovery_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _health_startup() -> void:
	login.health_results = [{"online": false, "status": 0}, {"online": false, "status": 503}, {"online": true, "reachable": true}]
	await login._refresh_server_health()
	_check(login.server_status_translation_key == "ui.login.checking_server" and not login.server_access_notice_active, "First startup transport failure keeps checking")
	_check(login.server_health_retry_timer.time_left > 0 and login.server_health_retry_timer.time_left <= 1, "Startup failures schedule a short retry")
	await login._refresh_server_health()
	await login._refresh_server_health()
	_check(login.server_online and not login.statuses.has("ui.login.server_offline"), "Slow startup reaches online without an offline flash")
	login.health_results = [{"online": false, "status": 0}]
	await login._refresh_server_health()
	_check(login.server_status_translation_key == "ui.login.server_offline", "A later outage is shown normally")
	login.server_health_confirmed = false
	login.startup_health_failures = 0
	login.health_results = [{"online": false}, {"online": false}, {"online": false}]
	for _index in range(3): await login._refresh_server_health()
	_check(login.server_status_translation_key == "ui.login.server_offline", "Startup retry allowance is bounded")
	login.server_health_confirmed = false
	login.health_results = [{"online": false, "reachable": true, "maintenance": true}]
	await login._refresh_server_health()
	_check(login.server_status_translation_key == "ui.login.server_maintenance", "Confirmed maintenance remains visible immediately")

func _restore_recovery() -> void:
	login.restore_results = [{"success": false, "status": 0, "retryable": true}, {"success": true}]
	await login._restore_saved_session()
	_check(login.saved_session_restore_pending and not login.saved_session_restore_in_progress, "Transient restore failure stays pending")
	login.health_results = [{"online": true, "reachable": true}]
	await login._refresh_server_health()
	for _index in range(4): await process_frame
	_check(login.restore_requests == 2 and login.saved_cards == 1 and not login.saved_session_restore_pending, "Online recovery automatically shows the saved login")
	login.restore_results = [{"success": false, "status": 401}]
	await login._restore_saved_session()
	_check(not login.saved_session_restore_pending, "Rejected saved sessions are not retried")
	login.restore_results = [{"success": false, "error": "No saved session."}]
	await login._restore_saved_session()
	_check(not login.saved_session_restore_pending, "Missing saved login does not start a retry loop")
	login.defer_restore = true
	login.restore_results = [{"success": true}]
	var requests_before: int = login.restore_requests
	login._restore_saved_session()
	await login._restore_saved_session()
	_check(login.restore_requests == requests_before + 1, "Concurrent restore attempts are joined by the guard")
	login.finish_restore.emit()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
