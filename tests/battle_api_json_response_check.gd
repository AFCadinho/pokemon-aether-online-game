extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var api := root.get_node("BattleApiClient")
	var request := HTTPRequest.new()
	root.add_child(request)
	for body: String in ["<html><body>Sign in</body></html>", "Internal Server Error", "", "{broken", "[]", "null"]:
		_complete.call_deferred(request, 502, body)
		var response: Dictionary = await api._read_json_response(request)
		_check(not bool(response.get("success", true)), "non-object or malformed response is rejected")
		_check(response.get("status") == 502 and response.get("raw") == body, "HTTP status and diagnostic body are preserved")
		_check(not str(response.get("error", "")).contains(body) if not body.is_empty() else not str(response.get("error", "")).is_empty(), "technical body is not shown as player text")
	_complete.call_deferred(request, 200, '{"success":true,"battleId":"boss-test"}')
	var success: Dictionary = await api._read_json_response(request)
	_check(success.get("success") == true and success.get("battleId") == "boss-test", "valid boss creation response is preserved")
	_complete.call_deferred(request, 409, '{"detail":{"code":"weekly_boss_completed"}}')
	var rejected: Dictionary = await api._read_json_response(request)
	_check(rejected.get("status") == 409 and rejected.get("detail", {}).get("code") == "weekly_boss_completed", "structured rejection keeps its status and code")
	_complete.call_deferred(request, 401, '{"detail":"unauthorized"}')
	var unauthorized: Dictionary = await api._read_json_response(request)
	_check(unauthorized.get("status") == 401, "authentication failure keeps its status")
	request.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _complete(request: HTTPRequest, status: int, body: String) -> void:
	request.request_completed.emit(HTTPRequest.RESULT_SUCCESS, status, PackedStringArray(), body.to_utf8_buffer())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error(message)
