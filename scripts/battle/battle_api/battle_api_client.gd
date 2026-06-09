extends Node

const JSON_HEADERS = ["Content-Type: application/json"]
const FORMAT_ID = "gen9nationaldex"

func create_battle_body(player: Dictionary, opponent: Dictionary) -> Dictionary:
	return {
		"formatId": FORMAT_ID,
		"p1": {
			"name": player["name"],
			"team": player["team"],
		},
		"p2": {
			"name": opponent["name"],
			"team": opponent["team"]
		}
	}

func create_wild_battle(request_node: HTTPRequest, player: Dictionary, opponent: Dictionary) -> Dictionary:
	var body := create_battle_body(player, opponent)
	
	return await send_post_request(request_node, "/battle/wild", body)

func create_battle(request_node: HTTPRequest, player: Dictionary, opponent: Dictionary) -> Dictionary:
	var body := create_battle_body(player, opponent)
	
	return await send_post_request(request_node, "/battle/create", body)

func choose_lead(request_node: HTTPRequest, battle_id: String, player_id: String, slot: int) -> Dictionary:
	var body = {
		"playerId": player_id,
		"slot": slot
	}
	
	return await send_post_request(request_node, "/battle/" + battle_id + "/lead", body)

func send_choice(request_node: HTTPRequest, battle_id: String, player_id: String, choice_type: String, slot: int) -> Dictionary:
	var body := {
		"playerId": player_id,
		"type": choice_type,
		"slot": slot
	}
	
	return await send_post_request(
		request_node,
		"/battle/%s/choice" % battle_id,
		body
	)

func parse_pokemon(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/pokemon/parse",
		{"text": text}
	)

func parse_team(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/team/parse",
		{"text": text}
	)

func get_pokemon_info(request_node: HTTPRequest, battle_id: String, viewer_id: String, ident: String) -> Dictionary:
	var query: String = "?viewerId=%s&ident=%s" % [
		viewer_id.uri_encode(),
		ident.uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/battle/%s/pokemon-info%s" % [battle_id, query]
	)

func get_pokemon_stats(request_node: HTTPRequest, species: String, level: int = 100) -> Dictionary:
	var query: String = "?species=%s&level=%s" % [
		species.uri_encode(),
		str(level).uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/pokemon/stats%s" % query
	)

func send_get_request(request_node: HTTPRequest, path: String) -> Dictionary:
	var api_base_url: String = await BattleApiConfig.get_base_url()

	var error: int = request_node.request(
		api_base_url + path,
		JSON_HEADERS,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		return {
			"success": false,
			"error": "Request failed to start",
			"code": error,
		}

	return await _read_json_response(request_node)

func send_post_request(request_node: HTTPRequest, path: String, body: Dictionary) -> Dictionary:
	var api_base_url: String = await BattleApiConfig.get_base_url()
	
	var error: int = request_node.request(
		api_base_url + path,
		JSON_HEADERS, 
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		return {
			"success": false,
			"error": "Request failed to start",
			"code": error,
		}

	return await _read_json_response(request_node)

func _read_json_response(request_node: HTTPRequest) -> Dictionary:
	var result: Array = await request_node.request_completed
	var request_result: int = int(result[0])
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var response_text: String = response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _get_request_error_message(request_result),
			"code": request_result,
			"raw": response_text
		}

	var parsed: Variant = JSON.parse_string(response_text)
	
	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"success": false,
			"status": response_code, 
			"error": "Invalid JSON response",
			"raw": response_text
		}
	var response: Dictionary = parsed as Dictionary
	response["status"] = response_code
	if not response.has("error") and response.has("detail"):
		response["error"] = str(response["detail"])
	return response

func _get_request_error_message(request_result: int) -> String:
	match request_result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to API gateway."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve API gateway."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "API gateway connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "API gateway TLS error."
		HTTPRequest.RESULT_TIMEOUT:
			return "API gateway request timed out."
		_:
			return "API gateway request failed."
