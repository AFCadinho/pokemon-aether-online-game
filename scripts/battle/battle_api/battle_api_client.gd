extends Node

const FORMAT_ID = "gen9nationaldex"

func create_triggered_wild_battle(
	request_node: HTTPRequest,
	player: Dictionary,
	area_id: String,
	encounter_type: String = "grass",
	origin: Dictionary = {}
) -> Dictionary:
	var payload := {
		"player": player,
		"areaId": area_id,
		"encounterType": encounter_type,
		"formatId": FORMAT_ID,
	}
	if not origin.is_empty():
		payload["origin"] = origin.duplicate(true)
	return await send_post_request(
		request_node,
		"/battle/wild-encounter",
		payload
	)

func create_dev_wild_battle(
	request_node: HTTPRequest,
	player: Dictionary,
	pokemon: Dictionary,
	origin: Dictionary = {}
) -> Dictionary:
	var payload := {
		"player": player,
		"pokemon": pokemon,
		"formatId": FORMAT_ID,
	}
	if not origin.is_empty():
		payload["origin"] = origin.duplicate(true)
	return await send_post_request(
		request_node,
		"/battle/dev/wild",
		payload
	)

func create_trainer_battle(request_node: HTTPRequest, player: Dictionary, trainer_id: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/trainer",
		{
			"player": player,
			"trainerId": trainer_id,
			"formatId": FORMAT_ID,
		}
	)

func create_pvp_room(request_node: HTTPRequest, player: Dictionary) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/pvp/rooms",
		{
			"player": player,
			"formatId": FORMAT_ID,
		}
	)

func get_pvp_room(request_node: HTTPRequest, room_code: String, player_id: String = "p1") -> Dictionary:
	return await send_get_request(
		request_node,
		"/battle/pvp/rooms/%s?playerId=%s" % [
			room_code.strip_edges().uri_encode(),
			player_id.strip_edges().uri_encode()
		]
	)

func join_pvp_room(request_node: HTTPRequest, room_code: String, player: Dictionary) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/pvp/rooms/%s/join" % room_code.strip_edges().uri_encode(),
		{
			"player": player,
			"formatId": FORMAT_ID,
		}
	)

func get_pvp_queues(request_node: HTTPRequest) -> Dictionary:
	return await send_get_request(request_node, "/account/pvp/queues")

func join_pvp_queue(request_node: HTTPRequest, queue_id: String, player: Dictionary) -> Dictionary:
	return await send_post_request(
		request_node,
		"/account/pvp/queues/%s/join" % queue_id.strip_edges().uri_encode(),
		{
			"player": player,
		}
	)

func validate_pvp_queue_team(request_node: HTTPRequest, queue_id: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/account/pvp/queues/%s/team-validation" % queue_id.strip_edges().uri_encode(),
		{}
	)

func leave_pvp_queue(request_node: HTTPRequest, queue_id: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/account/pvp/queues/%s/leave" % queue_id.strip_edges().uri_encode(),
		{}
	)

func get_pvp_queue_status(request_node: HTTPRequest) -> Dictionary:
	return await send_get_request(request_node, "/account/pvp/queues/status/me")

func get_pvp_leaderboard(
	request_node: HTTPRequest,
	limit: int = 50,
	offset: int = 0,
	format_key: String = "",
	scope: String = "all_time"
) -> Dictionary:
	var query := "/account/pvp/leaderboard?limit=%d&offset=%d" % [
		max(1, limit),
		max(0, offset),
	]
	var normalized_format_key := format_key.strip_edges()
	if normalized_format_key != "":
		query += "&formatKey=%s" % normalized_format_key.uri_encode()
	var normalized_scope := scope.strip_edges()
	if normalized_scope != "":
		query += "&scope=%s" % normalized_scope.uri_encode()
	return await send_get_request(
		request_node,
		query
	)

func get_pvp_match_history(request_node: HTTPRequest, limit: int = 20, offset: int = 0, format_key: String = "") -> Dictionary:
	var query := "/account/pvp/matches/history/me?limit=%d&offset=%d" % [
		max(1, limit),
		max(0, offset),
	]
	var normalized_format_key := format_key.strip_edges()
	if normalized_format_key != "":
		query += "&formatKey=%s" % normalized_format_key.uri_encode()
	return await send_get_request(
		request_node,
		query
	)

func get_pvp_ranked_banlists(request_node: HTTPRequest, format_key: String = "") -> Dictionary:
	var query := "/account/pvp/ranked/banlists"
	var normalized_format_key := format_key.strip_edges()
	if normalized_format_key != "":
		query += "?formatKey=%s" % normalized_format_key.uri_encode()
	return await send_get_request(request_node, query)

func get_active_pvp_match(request_node: HTTPRequest) -> Dictionary:
	return await send_get_request(request_node, "/account/pvp/matches/active")

func start_pvp_match_battle(request_node: HTTPRequest, match_id: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/pvp/matches/%s/start-battle" % match_id.strip_edges().uri_encode(),
		{}
	)

func choose_lead(request_node: HTTPRequest, battle_id: String, player_id: String, slot: int, since_event_seq := -1) -> Dictionary:
	var body = {
		"playerId": player_id,
		"slot": slot
	}
	
	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/" + battle_id + "/lead", since_event_seq),
		body
	)

func send_npc_lead(
	request_node: HTTPRequest,
	battle_id: String,
	player_id: String,
	strategy: String = "basic",
	since_event_seq := -1
) -> Dictionary:
	var body := {
		"playerId": player_id,
		"strategy": strategy
	}

	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/npc/lead" % battle_id, since_event_seq),
		body
	)

func send_choice(
	request_node: HTTPRequest,
	battle_id: String,
	player_id: String,
	choice_type: String,
	slot: int,
	mega := false,
	since_event_seq := -1
) -> Dictionary:
	var body := {
		"playerId": player_id,
		"type": choice_type,
		"slot": slot
	}
	if mega:
		body["mega"] = true
	
	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/choice" % battle_id, since_event_seq),
		body
	)

func send_npc_choice(
	request_node: HTTPRequest,
	battle_id: String,
	player_id: String,
	strategy: String = "basic",
	since_event_seq := -1
) -> Dictionary:
	var body := {
		"playerId": player_id,
		"strategy": strategy
	}

	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/npc/choice" % battle_id, since_event_seq),
		body
	)

func send_pass_turn(
	request_node: HTTPRequest,
	battle_id: String,
	pass_player_id: String = "p1",
	player_id: String = "p2",
	strategy: String = "basic",
	since_event_seq := -1
) -> Dictionary:
	var body := {
		"passPlayerId": pass_player_id,
		"playerId": player_id,
		"strategy": strategy
	}

	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/pass-turn" % battle_id, since_event_seq),
		body
	)

func _append_since_event_seq_query(path: String, since_event_seq: int) -> String:
	if since_event_seq < 0:
		return path

	var separator := "&" if path.contains("?") else "?"
	return "%s%ssinceEventSeq=%d" % [path, separator, since_event_seq]

func get_pokemon_info(request_node: HTTPRequest, battle_id: String, viewer_id: String, ident: String) -> Dictionary:
	var query: String = "?viewerId=%s&ident=%s" % [
		viewer_id.uri_encode(),
		ident.uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/battle/%s/pokemon-info%s" % [battle_id, query]
	)

# Backend first pass supports direction "own-to-opponent". Defender assumptions
# are user-provided calc inputs and are echoed by the backend as assumptions.
func calculate_battle_damage(
	request_node: HTTPRequest,
	battle_id: String,
	viewer_id: String = "p1",
	direction: String = "own-to-opponent",
	defender_assumptions: Dictionary = {}
) -> Dictionary:
	var normalized_battle_id := battle_id.strip_edges()
	if normalized_battle_id == "":
		return {
			"success": false,
			"error": "battleId is required",
			"code": "invalid_battle_id",
		}

	var payload := _build_damage_calc_payload(viewer_id, direction, defender_assumptions)
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/damage-calc" % normalized_battle_id.uri_encode(),
		payload
	)
	return _normalize_damage_calc_response(response)

func send_get_request(request_node: HTTPRequest, path: String) -> Dictionary:
	var api_base_url: String = await GatewayApiConfig.get_base_url()

	var error: int = request_node.request(
		api_base_url + path,
		GatewayApiConfig.get_accept_headers(),
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
	var api_base_url: String = await GatewayApiConfig.get_base_url()
	
	var error: int = request_node.request(
		api_base_url + path,
		GatewayApiConfig.get_json_headers(),
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
			"error": _get_invalid_json_error_message(response_code, response_text),
			"raw": response_text
		}
	var response: Dictionary = parsed as Dictionary
	response["status"] = response_code
	if not response.has("error") and response.has("detail"):
		response["error"] = str(response["detail"])
	return response

func _get_invalid_json_error_message(response_code: int, response_text: String) -> String:
	var message := "Invalid JSON response"
	if response_code > 0:
		message += " (status %s)" % response_code

	var response_excerpt := response_text.strip_edges().replace("\n", " ")
	if response_excerpt.length() > 160:
		response_excerpt = response_excerpt.substr(0, 160) + "..."
	if response_excerpt != "":
		message += ": %s" % response_excerpt

	return message

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

func _build_damage_calc_payload(viewer_id: String, direction: String, defender_assumptions: Dictionary) -> Dictionary:
	var payload := {
		"viewerId": viewer_id.strip_edges(),
		"direction": direction.strip_edges(),
		"defender": {
			"side": "opponent",
			"slot": "active",
			"assumptions": _normalize_damage_calc_assumptions(defender_assumptions),
		},
	}
	return payload

func _normalize_damage_calc_assumptions(defender_assumptions: Dictionary) -> Dictionary:
	var assumptions := {}
	if defender_assumptions.has("item"):
		assumptions["item"] = defender_assumptions.get("item")
	if defender_assumptions.has("ability"):
		assumptions["ability"] = defender_assumptions.get("ability")
	if defender_assumptions.has("nature"):
		assumptions["nature"] = str(defender_assumptions.get("nature", "Hardy")).strip_edges()
	if defender_assumptions.has("evs"):
		assumptions["evs"] = _normalize_damage_calc_stat_table(defender_assumptions.get("evs"))
	if defender_assumptions.has("ivs"):
		assumptions["ivs"] = _normalize_damage_calc_stat_table(defender_assumptions.get("ivs"))
	return assumptions

func _normalize_damage_calc_stat_table(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}

	var source: Dictionary = value as Dictionary
	var result := {}
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if not source.has(key):
			continue
		var stat_value: Variant = source.get(key)
		if typeof(stat_value) == TYPE_INT or typeof(stat_value) == TYPE_FLOAT:
			result[key] = int(stat_value)
		elif typeof(stat_value) == TYPE_STRING and str(stat_value).strip_edges().is_valid_int():
			result[key] = int(str(stat_value).strip_edges())
	return result

func _normalize_damage_calc_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": str(response.get("error", "Damage calculator request failed")),
			"code": response.get("code", response.get("status", "")),
			"raw": response.get("raw", ""),
			"detail": response.get("detail", null),
		}

	if not (response.get("attacker") is Dictionary):
		return _make_malformed_damage_calc_response(response, "attacker")
	if not (response.get("defender") is Dictionary):
		return _make_malformed_damage_calc_response(response, "defender")
	if not (response.get("results") is Array):
		return _make_malformed_damage_calc_response(response, "results")

	var normalized := {
		"success": true,
		"status": int(response.get("status", 200)),
		"battleId": str(response.get("battleId", "")),
		"turn": int(response.get("turn", -1)),
		"direction": str(response.get("direction", "")),
		"attacker": response.get("attacker", {}),
		"defender": response.get("defender", {}),
		"results": response.get("results", []),
		"warnings": _as_array(response.get("warnings", [])),
		"emptyReason": str(response.get("emptyReason", "")),
	}

	if response.has("formatId"):
		normalized["formatId"] = response.get("formatId")
	if response.has("field"):
		normalized["field"] = response.get("field")
	return normalized

func _make_malformed_damage_calc_response(response: Dictionary, missing_field: String) -> Dictionary:
	return {
		"success": false,
		"status": int(response.get("status", 0)),
		"error": "Malformed damage calculator response: missing %s" % missing_field,
		"code": "malformed_response",
		"raw": response,
	}

func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []
