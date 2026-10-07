extends InventoryServiceNode

signal reply(request_id: int, response: Dictionary)
var requests := 0
var delayed := false
var body := {"items": [], "borrowedItems": [], "mountLicenseRegions": []}

func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
	requests += 1
	var request_id := requests
	if delayed:
		while true:
			var response: Array = await reply
			if int(response[0]) == request_id:
				return response[1]
	return {"success": true, "body": body.duplicate(true)}
