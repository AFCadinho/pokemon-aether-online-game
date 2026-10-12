extends "res://scripts/services/inventory_service.gd"

var owned_items: Array = [{"itemId": "encounter-guard", "quantity": 2}]
var borrowed_items: Array = []
var loads := 0
var uses := 0
var fail_load := false
var fail_use := false
var after_load := Callable()

func _request_json(_url: String, method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
	await get_tree().process_frame
	if method == HTTPClient.METHOD_GET:
		loads += 1
		if after_load.is_valid():
			var callback := after_load
			after_load = Callable()
			callback.call()
		if fail_load:
			return {"success": false, "status": 0}
		return {"success": true, "body": {"items": owned_items.duplicate(true), "borrowedItems": borrowed_items}}
	uses += 1
	if fail_use:
		return {"success": false, "status": 409, "error": "Activation refused"}
	owned_items[0].quantity -= 1
	return {"success": true, "body": {
		"itemId": "encounter-guard", "repelSteps": null,
		"inventory": {"items": owned_items.duplicate(true)},
		"encounterGuard": {"active": true, "remaining": 3000, "serverTime": Time.get_unix_time_from_system() + 1000}
	}}
