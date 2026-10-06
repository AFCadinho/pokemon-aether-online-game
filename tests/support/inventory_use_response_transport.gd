extends "res://scripts/services/inventory_service.gd"

var response_body: Dictionary = {}
var request_count := 0
var requests: Array[Dictionary] = []
var fail_next := false
func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
	request_count += 1
	requests.append({"headers": _headers, "body": _body})
	if fail_next:
		fail_next = false
		return {"success": false, "status": 0, "error": "Test network failure"}
	return {"success": true, "status": 200, "body": JSON.parse_string(JSON.stringify(response_body))}
