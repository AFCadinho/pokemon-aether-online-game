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
	
	return await send_post_request(request_node, "/create_wild_battle", body)

func create_battle(request_node: HTTPRequest, player: Dictionary, opponent: Dictionary) -> Dictionary:
	var body := create_battle_body(player, opponent)
	
	return await send_post_request(request_node, "/create_battle", body)

func choose_lead(request_node: HTTPRequest, battle_id: String, player_id: String, slot: int) -> Dictionary:
	var body = {
		"playerId": player_id,
		"slot": slot
	}
	
	return await send_post_request(request_node, "/battles/" + battle_id + "/lead", body)

func send_post_request(request_node: HTTPRequest, path: String, body: Dictionary) -> Dictionary:
	var api_base_url = await BattleApiConfig.get_base_url()
	
	var error := request_node.request(
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
		
	var result = await request_node.request_completed
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text)
	
	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"success": false,
			"status": response_code, 
			"error": "Invalid JSON response",
			"raw": response_text
		}
	parsed["status"] = response_code
	return parsed
