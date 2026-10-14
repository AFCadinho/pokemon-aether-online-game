extends "res://scripts/services/daycare_service.gd"

var events: Array[String] = []

func _request(_path: String, _method: HTTPClient.Method, _payload: Dictionary) -> Dictionary:
	events.append("catalog_requested")
	return {"success": true, "body": {}}
