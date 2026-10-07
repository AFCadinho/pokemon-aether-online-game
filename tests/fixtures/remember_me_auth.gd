extends "res://scripts/services/auth_service.gd"

## Exercise session policy with synthetic HTTP responses and isolated storage.
var saved_session: Dictionary = {}
var response: Dictionary = {}
var last_payload: Dictionary = {}
var writes := 0


func _load_session_file() -> Dictionary:
	return saved_session.duplicate(true)


func _write_session_file(value: Dictionary) -> void:
	saved_session = value.duplicate(true)
	writes += 1


func _clear_session_file() -> void:
	saved_session.clear()


func _reset_account_runtime_state() -> void:
	pass


func _refresh_trade_session() -> void:
	pass


func _request_json(
	_url: String,
	_method: HTTPClient.Method,
	_headers: PackedStringArray,
	body: String,
	_timeout_seconds: float = REQUEST_TIMEOUT_SECONDS,
	_candidate_retry: bool = true
) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body) if body != "" else {}
	last_payload = parsed if parsed is Dictionary else {}
	await get_tree().process_frame
	return response.duplicate(true)
