extends "res://scripts/battle/battle_api/battle_api_client.gd"

var replies: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var change_session := false

func send_post_request(_request_node: HTTPRequest, path: String, body: Dictionary, _expected_session: String = "") -> Dictionary:
	requests.append({"path": path, "body": body.duplicate(true)})
	await get_tree().process_frame
	if change_session:
		AuthService.session_token = "different-fixture-session"
	return replies.pop_front() if not replies.is_empty() else {"success": false, "status": 503}
