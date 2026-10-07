extends ThievingServiceNode

signal reply(request_id: int, response: Dictionary)
var requests := 0

func _request_json(_endpoint: String, _method: HTTPClient.Method, _body: String) -> Dictionary:
	requests += 1
	var request_id := requests
	while true:
		var response: Array = await reply
		if int(response[0]) == request_id:
			return response[1]
	return {}
