extends "res://scripts/services/auth_service.gd"

func _session_file_path() -> String:
	return OS.get_environment("POKEAETHER_REMEMBER_ME_TEST_DIR").path_join("auth_session.json")
func _reset_account_runtime_state() -> void: pass
func _refresh_trade_session() -> void: pass
func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String, _timeout_seconds: float = REQUEST_TIMEOUT_SECONDS, _candidate_retry: bool = true) -> Dictionary:
	await get_tree().process_frame
	return {"success": true, "body": {
		"token": "synthetic-disk-restart", "expiresAt": "2099-01-01T00:00:00Z",
		"user": {"id": 999, "username": "disk-fixture", "displayName": "Disk Fixture"},
		"rememberMe": true, "sessionType": "player",
	}}
