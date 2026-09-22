extends Node
@onready var root := get_tree().root
const Replies = preload("res://scripts/services/service_json_response.gd")
class ActionStub extends "res://scripts/services/player_action_service.gd":
	func _request_json(_endpoint: String, _method: HTTPClient.Method, _body: String) -> Dictionary:
		return Replies.decode(HTTPRequest.RESULT_SUCCESS, 200, "<html>unavailable</html>".to_utf8_buffer())
class HotbarStub extends "res://scripts/services/player_hotbar_service.gd":
	func _request_json(_method: HTTPClient.Method, _body: String) -> Dictionary:
		return Replies.decode(HTTPRequest.RESULT_SUCCESS, 200, "".to_utf8_buffer())
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	for transport in [HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE]:
		for text in ["", "not-json", '{"actions":[]}']:
			var reply := Replies.decode(transport, 0, text.to_utf8_buffer())
			assert(not reply.success and reply.requestResult == transport)
			assert(not reply.error.is_empty())
	for text in ["", "  ", "<html>private-marker</html>", '{"broken":', "null", "[]", "true", "42", '"text"']:
		var reply := Replies.decode(HTTPRequest.RESULT_SUCCESS, 200, text.to_utf8_buffer())
		assert(not reply.success and reply.diagnosticCode == "invalid_json_response")
		assert(not JSON.stringify(reply).contains("private-marker"))
	var good := Replies.decode(HTTPRequest.RESULT_SUCCESS, 200, '{"slots":[{"slot":1}],"actions":[]}'.to_utf8_buffer())
	assert(good.success and good.body.slots.size() == 1)
	assert(Replies.decode(HTTPRequest.RESULT_SUCCESS, 200, "{}".to_utf8_buffer()).success)
	for status in [401, 403, 429, 502, 503]:
		var reply := Replies.decode(HTTPRequest.RESULT_SUCCESS, status, "<html>private-marker</html>".to_utf8_buffer())
		assert(not reply.success and reply.status == status and not reply.error.is_empty())
		assert(not JSON.stringify(reply).contains("private-marker"))
	var denied := Replies.decode(HTTPRequest.RESULT_SUCCESS, 403, '{"detail":{"code":"action_forbidden"}}'.to_utf8_buffer())
	assert(not denied.success and denied.errorCode == "action_forbidden")
	assert(denied.body.detail.code == "action_forbidden")
	assert(Replies.decode(HTTPRequest.RESULT_SUCCESS, 204, PackedByteArray(), true).success)
	assert(not Replies.decode(HTTPRequest.RESULT_SUCCESS, 204, PackedByteArray()).success)
	var actions := ActionStub.new()
	root.add_child(actions)
	actions.cached_actions = [{"id":"example-action"}]
	assert(not (await actions.load_statuses()).success)
	assert(actions.cached_actions == [{"id":"example-action"}])
	var hotbar := HotbarStub.new()
	root.add_child(hotbar)
	hotbar.cached_slots = [{"slot":1,"entryId":"example-action"}]
	assert(not (await hotbar.load_hotbar()).success)
	assert(hotbar.cached_slots == [{"slot":1,"entryId":"example-action"}])
	actions.free()
	hotbar.free()
	print("SERVICE_JSON_RESPONSE_OK: transport, invalid replies, HTTP errors, valid objects, no-content, cache preservation")
	get_tree().quit()
