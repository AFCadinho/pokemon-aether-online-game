extends SceneTree

const StatusParser := preload("res://scripts/services/server_access_status_parser.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var open_status := StatusParser.parse({
		"available": true,
		"mode": "open",
		"message": "",
		"disconnectAt": null,
	})
	_check(bool(open_status.get("valid", false)), "open game-access status is valid")
	_check(bool(open_status.get("online", false)), "open game-access status allows login")
	_check(not bool(open_status.get("maintenance", true)), "open game-access status is not maintenance")

	var maintenance_status := StatusParser.parse({
		"available": false,
		"mode": "closed",
		"message": "Deploying a new world build.",
		"disconnectAt": "2026-08-26T08:30:00+00:00",
	})
	_check(bool(maintenance_status.get("valid", false)), "closed game-access status is valid")
	_check(not bool(maintenance_status.get("online", true)), "closed game-access status blocks login")
	_check(bool(maintenance_status.get("maintenance", false)), "closed game-access status reports maintenance")
	_check(
		maintenance_status.get("message") == "Deploying a new world build.",
		"maintenance status preserves the public player message"
	)

	var inconsistent_status := StatusParser.parse({
		"available": true,
		"mode": "closed",
		"message": "Must not be trusted.",
	})
	_check(not bool(inconsistent_status.get("valid", true)), "inconsistent game-access status fails closed")

	var login_source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(
		login_source.contains("await _refresh_server_health()"),
		"login retries the public status check after a maintenance-shaped failure"
	)
	_check(
		login_source.contains("login_button.disabled = is_loading or not server_online"),
		"login remains disabled while game access is unavailable"
	)

	if failed:
		quit(1)
		return
	print("PASS server_access_status_check")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL: %s" % message)
