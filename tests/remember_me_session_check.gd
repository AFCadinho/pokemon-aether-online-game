extends SceneTree

const TEST_USER := {"id": 999, "username": "remember-check", "displayName": "Remember Check"}
const TEST_EXPIRY := "2099-01-01T00:00:00Z"
var failures := 0
var auth: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	auth = load("res://tests/fixtures/remember_me_auth.gd").new()
	root.add_child(auth)
	await _check_login_preferences()
	await _check_legacy_restore()
	await _check_temporary_restore_failures()
	await _check_rejected_restore()
	await _check_impersonation()
	await _check_logout()
	auth.free()
	print("remember_me_session_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _login_response(remember: bool = true) -> Dictionary:
	return {"success": true, "body": {
		"token": "synthetic-remember-check", "expiresAt": TEST_EXPIRY,
		"user": TEST_USER.duplicate(true), "rememberMe": remember, "sessionType": "player",
	}}


func _saved_session() -> Dictionary:
	return {
		"token": "synthetic-remember-check", "expiresAt": TEST_EXPIRY,
		"user": TEST_USER.duplicate(true), "rememberMe": true,
	}


func _check_login_preferences() -> void:
	for remember in [true, false]:
		auth.response = _login_response(remember)
		var result: Dictionary = await auth.login("remember-check", "synthetic-password", remember)
		_check(result.success and auth.is_authenticated(), "Successful native login")
		_check(auth.last_payload.get("rememberMe") == remember, "Login submits the selected preference")
		_check(auth.remember_me_enabled == remember, "Login retains the selected preference")
		_check(auth.saved_session.is_empty() != remember, "Native login saves only when remembered")
		var updated := TEST_USER.duplicate(true)
		updated.displayName = "Changed profile"
		auth.apply_current_user(updated)
		_check(auth.saved_session.is_empty() != remember, "Profile refresh respects the preference")
		if remember:
			_check(auth.saved_session.user.displayName == updated.displayName, "Remembered profile refresh updates stored user")
			_check(auth.saved_session.get("rememberMe", false), "Native storage includes the preference")
		auth.response = {"success": true, "body": updated}
		result = await auth.update_account_details("Changed profile", "", "")
		_check(result.success and auth.saved_session.is_empty() != remember, "Account edits respect the preference")


func _check_legacy_restore() -> void:
	auth.clear_session()
	auth.saved_session = _saved_session()
	auth.saved_session.erase("rememberMe")
	auth.response = _login_response()
	var result: Dictionary = await auth.restore_saved_session()
	_check(result.success and auth.is_authenticated(), "Older native login files still restore")
	_check(auth.remember_me_enabled and auth.saved_session.get("rememberMe", false), "Older native files acquire the remember-me preference")


func _check_temporary_restore_failures() -> void:
	for status in [0, 408, 429, 500, 502, 503, 504]:
		auth.clear_session()
		auth.saved_session = _saved_session()
		var before: Dictionary = auth.saved_session.duplicate(true)
		var writes_before: int = auth.writes
		auth.response = {"success": false, "status": status, "error": "Synthetic temporary failure"}
		var result: Dictionary = await auth.restore_saved_session()
		_check(not result.success, "Temporary restore failure is returned (%d)" % status)
		_check(auth.saved_session == before and auth.writes == writes_before, "Temporary failure preserves storage unchanged (%d)" % status)
		_check(not auth.is_authenticated() and auth.session_token == "" and auth.expires_at == "", "Temporary failure leaves no active unverified session (%d)" % status)
		auth.response = _login_response()
		result = await auth.restore_saved_session()
		_check(result.success and auth.is_authenticated() and auth.remember_me_enabled, "Remembered login can be retried after recovery (%d)" % status)


func _check_rejected_restore() -> void:
	for status in [401, 403]:
		auth.saved_session = _saved_session()
		auth.response = {"success": false, "status": status, "error": "Synthetic authentication rejection"}
		var result: Dictionary = await auth.restore_saved_session()
		_check(not result.success and auth.saved_session.is_empty(), "Rejected login is removed (%d)" % status)
		_check(not auth.is_authenticated() and not auth.remember_me_enabled, "Rejected login resets the preference (%d)" % status)
	var result: Dictionary = await auth.restore_saved_session()
	_check(not result.success and not auth.is_authenticated(), "Missing saved login stays unauthenticated")


func _check_impersonation() -> void:
	for remember in [true, false]:
		auth.response = _login_response(remember)
		await auth.login("remember-check", "synthetic-password", remember)
		auth.response = _login_response()
		auth.response.body.sessionType = "impersonation"
		auth.response.body.impersonatedByUserId = 1
		var result: Dictionary = await auth.impersonate_with_token("synthetic-grant")
		_check(result.success and auth.is_impersonating() and auth.saved_session.is_empty(), "Impersonation is never saved")
		auth.apply_current_user(TEST_USER)
		_check(auth.saved_session.is_empty(), "Impersonated profile refresh remains unsaved")
		auth.response = _login_response(remember)
		result = await auth.stop_impersonating()
		_check(result.success and not auth.is_impersonating(), "Returning restores native staff identity")
		_check(auth.remember_me_enabled == remember and auth.saved_session.is_empty() != remember, "Returning restores the original preference")


func _check_logout() -> void:
	auth.response = _login_response()
	await auth.login("remember-check", "synthetic-password", true)
	auth.response = {"success": false, "status": 0, "error": "Synthetic offline logout"}
	await auth.logout()
	_check(auth.saved_session.is_empty() and not auth.is_authenticated() and not auth.remember_me_enabled, "Logout clears saved login even when offline")
	auth.apply_current_user(TEST_USER)
	_check(auth.saved_session.is_empty(), "Late profile update after logout cannot recreate storage")
	await auth.logout()
	_check(auth.saved_session.is_empty(), "Repeated logout remains cleared")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
