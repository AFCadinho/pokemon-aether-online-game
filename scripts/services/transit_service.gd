extends Node

class_name TransitServiceNode

const TRANSIT_ENDPOINT := "/game/transit"
const REQUEST_TIMEOUT_SECONDS := 8.0

var pending_request_ids: Dictionary = {}


func _transit_endpoint() -> String:
	return TRANSIT_ENDPOINT


func load_network() -> Dictionary:
	# Beacons request this during map startup; begin the timeout after rendering.
	await GatewayApiConfig.wait_for_metadata_request_frame()
	return await _request_json(_transit_endpoint(), HTTPClient.METHOD_GET, "")


func attune(destination_id: String, beacon_position: Vector2) -> Dictionary:
	var position_save := await _save_current_player_position()
	if not bool(position_save.get("success", false)):
		return position_save
	return await _request_json(
		_transit_endpoint() + "/attune",
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"destinationId": destination_id,
			"beaconPosition": {
				"x": beacon_position.x,
				"y": beacon_position.y,
			},
		})
	)


func set_anchor(destination_id: String, beacon_position: Vector2, anchor_slot: int = 1) -> Dictionary:
	var position_save := await _save_current_player_position()
	if not bool(position_save.get("success", false)):
		return position_save
	return await _request_json(
		_transit_endpoint() + "/anchor",
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"destinationId": destination_id,
			"anchorSlot": anchor_slot,
			"beaconPosition": {
				"x": beacon_position.x,
				"y": beacon_position.y,
			},
		})
	)


func travel(destination_id: String) -> Dictionary:
	if OS.has_feature("web") and not WebAssetModuleService.scene_for_map(destination_id).is_empty():
		var assets := await WebAssetModuleService.ensure_scene_available(WebAssetModuleService.scene_for_map(destination_id))
		if not bool(assets.get("success", false)):
			return assets
	var request_id := str(pending_request_ids.get(destination_id, ""))
	if request_id.is_empty():
		request_id = "transit-%s-%s" % [Time.get_ticks_usec(), randi()]
		pending_request_ids[destination_id] = request_id
	var result := await _request_json(
		_transit_endpoint() + "/travel",
		HTTPClient.METHOD_POST,
		JSON.stringify({"requestId": request_id, "destinationId": destination_id})
	)
	if bool(result.get("success", false)):
		pending_request_ids.erase(destination_id)
	return result


func _save_current_player_position() -> Dictionary:
	var world := GameState.get_world()
	if world == null or not world.has_method("save_current_player_state_now"):
		return {
			"success": false,
			"error": "World is not ready.",
		}
	var result_value: Variant = await world.call("save_current_player_state_now")
	if result_value is Dictionary:
		return result_value as Dictionary
	return {
		"success": false,
		"error": "Invalid position save response.",
	}


func _request_json(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var headers := GatewayApiConfig.get_accept_headers() if method == HTTPClient.METHOD_GET else GatewayApiConfig.get_json_headers()
	var start_error := request.request(base_url + path, headers, method, body)
	if start_error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(start_error)}
	var completed: Array = await request.request_completed
	request.queue_free()
	return preload("res://scripts/services/service_json_response.gd").decode(
		int(completed[0]), int(completed[1]), completed[3]
	)
