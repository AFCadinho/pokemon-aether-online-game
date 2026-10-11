extends "res://scripts/services/guild_service.gd"

var wire_body := ""
var wire_path := ""
var wire_method := HTTPClient.METHOD_GET

func _authenticated_request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	wire_body = body
	wire_path = path
	wire_method = method
	return {"success": true, "body": {}}
