extends "res://scripts/services/transit_service.gd"

var travel_succeeds := true
var travel_requests := 0
var locked_during_request := false


func _request_json(_path: String, method: HTTPClient.Method, _body: String) -> Dictionary:
	if method == HTTPClient.METHOD_GET:
		return {"success": true, "body": {
			"sourceRegionId": "kanto",
			"sourceMapId": "kanto_pallet_town",
			"wallet": {"money": 9999},
			"destinations": [{
				"destinationId": "kanto_pewter_city",
				"regionId": "kanto", "name": "Pewter City",
				"attuned": true, "fare": 200,
			}],
		}}
	travel_requests += 1
	locked_during_request = GameState.is_overworld_input_locked()
	await get_tree().process_frame
	return {"success": true, "body": {"state": {"mapId": "kanto_pewter_city"}}} \
		if travel_succeeds else {"success": false, "error": "Travel rejected"}
