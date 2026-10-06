extends "res://scripts/services/inventory_service.gd"

var response_body: Dictionary = {}
var request_count := 0
func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
	request_count += 1
	return {"success": true, "status": 200, "body": JSON.parse_string(JSON.stringify(response_body))}
