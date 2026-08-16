extends Node

const FORMAT_ID = "gen9nationaldex"
const CALCDEX_SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const CALCDEX_MATCHUP := preload("res://scripts/battle/battle_calcdex_matchup.gd")
const CALCDEX_CANDIDATES := preload("res://scripts/battle/battle_calcdex_candidates.gd")
const CALCDEX_INFERENCE := preload("res://scripts/battle/battle_calcdex_inference.gd")

func create_triggered_wild_battle(
	request_node: HTTPRequest,
	player: Dictionary,
	area_id: String,
	encounter_type: String = "grass",
	origin: Dictionary = {},
	debug_time_of_day: String = ""
) -> Dictionary:
	var payload := {
		"player": player,
		"areaId": area_id,
		"encounterType": encounter_type,
		"formatId": FORMAT_ID,
	}
	if not origin.is_empty():
		payload["origin"] = origin.duplicate(true)
	if debug_time_of_day in ["day", "night"]:
		payload["debugTimeOfDay"] = debug_time_of_day
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

func create_trainer_battle(
	request_node: HTTPRequest,
	player: Dictionary,
	trainer_id: String,
	is_rematch := false
) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/trainer",
		{
			"player": player,
			"trainerId": trainer_id,
			"formatId": FORMAT_ID,
			"isRematch": is_rematch,
		}
	)

func create_pvp_room(
	request_node: HTTPRequest,
	player: Dictionary,
	allow_spectators: bool = false,
	max_spectators: int = 8
) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/pvp/rooms",
		{
			"player": player,
			"formatId": FORMAT_ID,
			"allowSpectators": allow_spectators,
			"maxSpectators": clampi(max_spectators, 1, 32),
		}
	)

func get_pvp_room(request_node: HTTPRequest, room_code: String) -> Dictionary:
	return await send_get_request(
		request_node,
		"/battle/pvp/rooms/%s" % room_code.strip_edges().uri_encode()
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

func cancel_pvp_room(request_node: HTTPRequest, room_code: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/battle/pvp/rooms/%s/cancel" % room_code.strip_edges().uri_encode(),
		{}
	)

func spectate_pvp_room(request_node: HTTPRequest, room_code: String) -> Dictionary:
	return await send_get_request(
		request_node,
		"/battle/pvp/rooms/%s/spectate" % room_code.strip_edges().uri_encode()
	)

func get_pvp_queues(request_node: HTTPRequest) -> Dictionary:
	return await send_get_request(request_node, "/account/pvp/queues")

func join_pvp_queue(request_node: HTTPRequest, queue_id: String, player: Dictionary) -> Dictionary:
	return await send_post_request(
		request_node,
		"/account/pvp/queues/%s/join" % queue_id.strip_edges().uri_encode(),
		{
			"player": player,
			"metadata": {"clientCapabilities": {
				"timerContractVersions": [1],
				"decisionContractVersions": [1],
				"battleCommandContractVersions": [1],
			}},
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

func get_pvp_queue_availability(request_node: HTTPRequest, queue_id: String) -> Dictionary:
	return await send_get_request(
		request_node,
		"/account/pvp/queues/%s/availability" % queue_id.strip_edges().uri_encode()
	)

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
	since_event_seq := -1,
	z_move := false
) -> Dictionary:
	var body := {
		"playerId": player_id,
		"type": choice_type,
		"slot": slot
	}
	if mega:
		body["mega"] = true
	if z_move:
		body["zMove"] = true
	
	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/choice" % battle_id, since_event_seq),
		body
	)

func send_choice_and_resolve(
	request_node: HTTPRequest,
	battle_id: String,
	player_id: String,
	choice_type: String,
	slot: int,
	mega := false,
	strategy := "basic",
	npc_player_id := "p2",
	since_event_seq := -1,
	z_move := false
) -> Dictionary:
	var body := {
		"playerId": player_id,
		"type": choice_type,
		"slot": slot,
		"strategy": strategy,
		"npcPlayerId": npc_player_id
	}
	if mega:
		body["mega"] = true
	if z_move:
		body["zMove"] = true

	return await send_post_request(
		request_node,
		_append_since_event_seq_query("/battle/%s/choice-and-resolve" % battle_id, since_event_seq),
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

func get_pokemon_info(request_node: HTTPRequest, battle_id: String, ident: String) -> Dictionary:
	var query: String = "?ident=%s" % ident.uri_encode()
	return await send_get_request(
		request_node,
		"/battle/%s/pokemon-info%s" % [battle_id, query]
	)

# Backend first pass supports direction "own-to-opponent". Defender assumptions
# are user-provided calc inputs and are echoed by the backend as assumptions.
func calculate_battle_damage(
	request_node: HTTPRequest,
	battle_id: String,
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

	var payload := _build_damage_calc_payload(direction, defender_assumptions)
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/damage-calc" % normalized_battle_id.uri_encode(),
		payload
	)
	return _normalize_damage_calc_response(response)

func get_calcdex_snapshot(
	request_node: HTTPRequest,
	battle_id: String,
	last_projection_revision: Dictionary
) -> Dictionary:
	var normalized_battle_id := battle_id.strip_edges()
	if normalized_battle_id == "" or not CALCDEX_SNAPSHOT.is_valid_projection_revision(last_projection_revision):
		return {
			"success": false,
			"code": "invalid_calcdex_request",
			"error": "A valid battle and projection revision are required.",
		}
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/calcdex/v1/snapshot" % normalized_battle_id.uri_encode(),
		{
			"schemaVersion": CALCDEX_SNAPSHOT.SCHEMA_VERSION,
			"lastProjectionRevision": last_projection_revision.duplicate(true),
		}
	)
	return CALCDEX_SNAPSHOT.normalize_response(response, last_projection_revision)

func calculate_calcdex_matchup(
	request_node: HTTPRequest,
	battle_id: String,
	last_projection_revision: Dictionary,
	direction: String,
	attacker_ref: String,
	defender_ref: String,
	opponent_scenario: Dictionary = {},
	field_scenario: Dictionary = {},
	species_scenario: Dictionary = {},
	move_scenarios: Array = [],
	viewer_scenario: Dictionary = {},
	battle_state_scenario: Dictionary = {}
) -> Dictionary:
	var normalized_battle_id := battle_id.strip_edges()
	if normalized_battle_id == "" or not CALCDEX_SNAPSHOT.is_valid_projection_revision(last_projection_revision):
		return {"success": false, "code": "invalid_calcdex_request", "error": "A valid battle revision is required."}
	var payload := {
		"schemaVersion": CALCDEX_MATCHUP.SCHEMA_VERSION,
		"lastProjectionRevision": last_projection_revision.duplicate(true),
		"direction": direction,
		"attackerRef": attacker_ref,
		"defenderRef": defender_ref,
		"viewerScenario": {
			"boosts": _normalize_damage_calc_boost_table(viewer_scenario.get("boosts", {})),
		},
		"opponentScenario": _normalize_damage_calc_assumptions(opponent_scenario),
		"fieldScenario": field_scenario.duplicate(true),
		"speciesScenario": _normalize_calcdex_species_scenario(species_scenario),
		"moveScenarios": move_scenarios.duplicate(true),
	}
	var viewer_state: Dictionary = battle_state_scenario.get("viewer", {}) as Dictionary if battle_state_scenario.get("viewer", {}) is Dictionary else {}
	var opponent_state: Dictionary = battle_state_scenario.get("opponent", {}) as Dictionary if battle_state_scenario.get("opponent", {}) is Dictionary else {}
	if viewer_state.has("status"):
		payload["viewerScenario"]["status"] = str(viewer_state.get("status", ""))
	if viewer_state.has("currentHp"):
		payload["viewerScenario"]["currentHp"] = maxi(0, int(viewer_state.get("currentHp", 0)))
	if viewer_scenario.has("ability"):
		payload["viewerScenario"]["ability"] = str(viewer_scenario.get("ability", ""))
	if opponent_state.has("status"):
		payload["opponentScenario"]["status"] = str(opponent_state.get("status", ""))
	if opponent_state.has("currentHpPercent"):
		payload["opponentScenario"]["currentHpPercent"] = clampf(float(opponent_state.get("currentHpPercent", 0.0)), 0.0, 100.0)
	if opponent_scenario.get("assumedMoves") is Array:
		payload["opponentScenario"]["assumedMoves"] = (opponent_scenario.get("assumedMoves") as Array).duplicate(true)
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/calcdex/v1/matchup" % normalized_battle_id.uri_encode(),
		payload
	)
	return CALCDEX_MATCHUP.normalize_response(response, last_projection_revision)

func _normalize_calcdex_species_scenario(value: Dictionary) -> Dictionary:
	var result := {}
	for relation: String in ["viewer", "opponent"]:
		var species := str(value.get(relation, "")).strip_edges()
		if species != "" and species.length() <= 128:
			result[relation] = species
	return result

func calculate_calcdex_smart_matchup(
	request_node: HTTPRequest,
	battle_id: String,
	last_projection_revision: Dictionary,
	direction: String,
	attacker_ref: String,
	defender_ref: String,
	opponent_scenario: Dictionary = {},
	field_scenario: Dictionary = {},
	range_mode: String = "likely",
	pinned_candidate_id: String = ""
) -> Dictionary:
	var normalized_battle_id := battle_id.strip_edges()
	if normalized_battle_id == "" or not CALCDEX_SNAPSHOT.is_valid_projection_revision(last_projection_revision):
		return {"success": false, "code": "invalid_calcdex_request", "error": "A valid battle revision is required."}
	var scenario := _normalize_damage_calc_assumptions(opponent_scenario)
	if opponent_scenario.get("assumedMoves") is Array:
		scenario["assumedMoves"] = (opponent_scenario.get("assumedMoves") as Array).duplicate(true)
	var payload := {
		"schemaVersion": CALCDEX_CANDIDATES.SCHEMA_VERSION,
		"lastProjectionRevision": last_projection_revision.duplicate(true),
		"direction": direction,
		"attackerRef": attacker_ref,
		"defenderRef": defender_ref,
		"opponentScenario": scenario,
		"fieldScenario": field_scenario.duplicate(true),
		"rangeMode": range_mode,
	}
	if pinned_candidate_id.strip_edges() != "":
		payload["pinnedCandidateId"] = pinned_candidate_id.strip_edges()
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/calcdex/v1/smart-matchup" % normalized_battle_id.uri_encode(),
		payload
	)
	return CALCDEX_CANDIDATES.normalize_response(response, last_projection_revision)

func calculate_calcdex_inferred_matchup(
	request_node: HTTPRequest,
	battle_id: String,
	last_projection_revision: Dictionary,
	direction: String,
	attacker_ref: String,
	defender_ref: String,
	opponent_scenario: Dictionary = {},
	field_scenario: Dictionary = {},
	range_mode: String = "likely",
	pinned_candidate_id: String = ""
) -> Dictionary:
	var normalized_battle_id := battle_id.strip_edges()
	if normalized_battle_id == "" or not CALCDEX_SNAPSHOT.is_valid_projection_revision(last_projection_revision):
		return {"success": false, "code": "invalid_calcdex_request", "error": "A valid battle revision is required."}
	var scenario := _normalize_damage_calc_assumptions(opponent_scenario)
	if opponent_scenario.get("assumedMoves") is Array:
		scenario["assumedMoves"] = (opponent_scenario.get("assumedMoves") as Array).duplicate(true)
	var payload := {
		"schemaVersion": CALCDEX_CANDIDATES.SCHEMA_VERSION,
		"lastProjectionRevision": last_projection_revision.duplicate(true),
		"direction": direction,
		"attackerRef": attacker_ref,
		"defenderRef": defender_ref,
		"opponentScenario": scenario,
		"fieldScenario": field_scenario.duplicate(true),
		"rangeMode": range_mode,
		"inferenceMode": "public_observations",
	}
	if pinned_candidate_id.strip_edges() != "":
		payload["pinnedCandidateId"] = pinned_candidate_id.strip_edges()
	var response: Dictionary = await send_post_request(
		request_node,
		"/battle/%s/calcdex/v1/inferred-matchup" % normalized_battle_id.uri_encode(),
		payload
	)
	return CALCDEX_INFERENCE.normalize_response(response, last_projection_revision)

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
	if response_code < 200 or response_code >= 300 or not bool(response.get("success", true)):
		return BackendErrorLocalizationService.decorate(response)
	return response

func _get_invalid_json_error_message(response_code: int, response_text: String) -> String:
	return BackendErrorLocalizationService.message({
		"status": response_code,
		"diagnosticError": response_text,
	})

func _get_request_error_message(request_result: int) -> String:
	return BackendErrorLocalizationService.transport_message(request_result)

func _build_damage_calc_payload(direction: String, defender_assumptions: Dictionary) -> Dictionary:
	var payload := {
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
	var status := str(defender_assumptions.get("status", "")).strip_edges().to_lower()
	if status in ["brn", "par", "psn", "tox", "slp", "frz"]:
		assumptions["status"] = status
	if defender_assumptions.has("nature"):
		assumptions["nature"] = str(defender_assumptions.get("nature", "Hardy")).strip_edges()
	if defender_assumptions.has("evs"):
		assumptions["evs"] = _normalize_damage_calc_stat_table(defender_assumptions.get("evs"))
	if defender_assumptions.has("ivs"):
		assumptions["ivs"] = _normalize_damage_calc_stat_table(defender_assumptions.get("ivs"))
	if defender_assumptions.has("boosts"):
		assumptions["boosts"] = _normalize_damage_calc_boost_table(defender_assumptions.get("boosts"))
	if defender_assumptions.has("replaceMoves"):
		assumptions["replaceMoves"] = bool(defender_assumptions.get("replaceMoves", false))
	if defender_assumptions.has("exactStats"):
		assumptions["exactStats"] = bool(defender_assumptions.get("exactStats", false))
	return assumptions

func _normalize_damage_calc_boost_table(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value as Dictionary
	var result := {}
	for key: String in ["atk", "def", "spa", "spd", "spe"]:
		if not source.has(key):
			continue
		var stat_value: Variant = source.get(key)
		if typeof(stat_value) == TYPE_INT or typeof(stat_value) == TYPE_FLOAT:
			result[key] = clampi(int(stat_value), -6, 6)
		elif typeof(stat_value) == TYPE_STRING and str(stat_value).strip_edges().is_valid_int():
			result[key] = clampi(int(str(stat_value).strip_edges()), -6, 6)
	return result

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
	if not CALCDEX_SNAPSHOT.is_valid_mechanics_manifest(response.get("mechanicsManifest")):
		return _make_malformed_damage_calc_response(response, "mechanicsManifest")

	var normalized := {
		"success": true,
		"status": int(response.get("status", 200)),
		"battleId": str(response.get("battleId", "")),
		"turn": int(response.get("turn", -1)),
		"direction": str(response.get("direction", "")),
		"attacker": response.get("attacker", {}),
		"defender": response.get("defender", {}),
		"results": response.get("results", []),
		"mechanicsManifest": (response.get("mechanicsManifest") as Dictionary).duplicate(true),
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
