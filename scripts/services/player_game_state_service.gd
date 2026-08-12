extends Node

class_name PlayerGameStateServiceNode

const PLAYER_POSITION_ENDPOINT := "/game/player-position"
const PLAYER_TELEPORT_ACK_ENDPOINT := "/game/player-position/teleport-ack"
const PLAYER_RESPAWN_ENDPOINT := "/game/respawn"
const PLAYER_RESPAWN_POINT_ENDPOINT := "/game/respawn-point"
const PLAYER_ACTIVITY_ENDPOINT := "/game/player-activity"
const MAP_PLAYERS_ENDPOINT := "/game/map-players"
const PLAYER_PREFERENCES_ENDPOINT := "/game/preferences"
const PLAYER_PROFILE_ENDPOINT := "/game/profile"
const PLAYER_STORY_ENDPOINT := "/game/story"
const STORY_BOOTSTRAP_ENDPOINT := "/game/story/bootstrap"
const STORY_INTERACTION_ENDPOINT := "/game/story/interactions/%s"
const STORY_QUEST_ACCEPT_ENDPOINT := "/game/story/quests/%s/accept"
const DEV_STORY_CHECKPOINT_ENDPOINT := "/game/dev/progression/story-checkpoint"
const PUBLIC_TRAINER_CARD_ENDPOINT := "/game/trainers/%s/card"
const REQUEST_TIMEOUT_SECONDS := 8.0

var pending_side_quest_accept_request_ids: Dictionary = {}


func load_player_profile() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PROFILE_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var position: Dictionary = _dictionary_from_value(body.get("position", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	var preferences: Dictionary = _dictionary_from_value(body.get("preferences", {}))
	var wallet: Dictionary = _dictionary_from_value(body.get("wallet", {}))
	var stats: Dictionary = _dictionary_from_value(body.get("stats", {}))
	var badges: Dictionary = _dictionary_from_value(body.get("badges", {}))
	var story: Dictionary = _dictionary_from_value(body.get("story", {}))
	return {
		"success": true,
		"user": _dictionary_from_value(body.get("user", {})),
		"position": {
			"hasState": bool(position.get("hasState", false)),
			"state": _dictionary_from_value(position.get("state", {})),
		},
		"party": {
			"hasParty": bool(party.get("hasParty", false)),
			"party": _array_from_value(party.get("party", [])),
		},
		"preferences": _dictionary_from_value(preferences.get("preferences", {})),
		"wallet": _dictionary_from_value(wallet.get("wallet", {})),
		"stats": {
			"stats": _dictionary_from_value(stats.get("stats", {})),
		},
		"badges": badges,
		"story": story,
	}


func refresh_story() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_STORY_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var story: Dictionary = _dictionary_from_value(body.get("story", body))
	StoryService.apply_story(story)
	return {
		"success": true,
		"story": StoryService.get_story(),
	}


func bootstrap_story() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + STORY_BOOTSTRAP_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var story: Dictionary = _dictionary_from_value(response.get("body", {}))
	if not _is_valid_story_projection_body(story):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": "Story bootstrap response was invalid.",
		}

	StoryService.apply_story(story)
	return {
		"success": true,
		"story": StoryService.get_story(),
	}


func dev_set_story_checkpoint(checkpoint_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "status": 401, "error": "Not authenticated."}
	var normalized_checkpoint_id := checkpoint_id.strip_edges().to_lower()
	if normalized_checkpoint_id.is_empty():
		return {"success": false, "status": 0, "error": "Choose a story checkpoint."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_STORY_CHECKPOINT_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({"checkpointId": normalized_checkpoint_id})
	)
	if not bool(response.get("success", false)):
		return response
	var story: Dictionary = _dictionary_from_value(response.get("body", {}))
	if not _is_valid_story_projection_body(story):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": "Story checkpoint response was invalid.",
		}
	StoryService.apply_story(story)
	return {"success": true, "story": StoryService.get_story()}


func accept_side_quest(quest_id: String, expected_revision: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "status": 401, "error": "Not authenticated."}
	var normalized_quest_id := quest_id.strip_edges()
	if normalized_quest_id.is_empty() or expected_revision < 0:
		return {"success": false, "status": 0, "error": "Invalid side quest offer."}
	var request_key := "%s:%d" % [normalized_quest_id, expected_revision]
	var request_id := str(pending_side_quest_accept_request_ids.get(request_key, ""))
	if request_id.is_empty():
		request_id = _new_request_id()
		pending_side_quest_accept_request_ids[request_key] = request_id
	if request_id.is_empty():
		return {"success": false, "status": 0, "error": "Could not create quest request."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + (STORY_QUEST_ACCEPT_ENDPOINT % normalized_quest_id.uri_encode()),
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"requestId": request_id,
			"expectedRevision": expected_revision,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var story: Dictionary = _dictionary_from_value(response.get("body", {}))
	if (
		not _is_valid_story_projection_body(story)
		or int(story.get("revision", -1)) != expected_revision + 1
	):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": "Side quest acceptance response was invalid.",
		}
	pending_side_quest_accept_request_ids.erase(request_key)
	StoryService.apply_story(story)
	return {"success": true, "story": StoryService.get_story()}


func resolve_story_interaction(
	interaction_id: String,
	map_id: String,
	entity_id: String,
	trigger: String
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "status": 401, "error": "Not authenticated."}

	var normalized_interaction_id := interaction_id.strip_edges()
	if normalized_interaction_id == "":
		return {"success": false, "status": 0, "error": "Missing story interaction id."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var endpoint := (STORY_INTERACTION_ENDPOINT % normalized_interaction_id.uri_encode()) + "/resolve"
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"mapId": map_id.strip_edges(),
			"entityId": entity_id.strip_edges(),
			"trigger": trigger.strip_edges(),
		})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	if not _is_valid_story_resolve_body(body):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": "Story interaction resolve response was invalid.",
		}

	return {
		"success": true,
		"handled": bool(body.get("handled", false)),
		"interactionId": str(body.get("interactionId", "")),
		"revision": int(body.get("revision", 0)),
		"actions": _array_from_value(body.get("actions", [])).duplicate(true),
		"completionRequired": bool(body.get("completionRequired", false)),
	}


func complete_story_interaction(
	interaction_id: String,
	request_id: String,
	expected_revision: int,
	map_id: String,
	entity_id: String,
	trigger: String
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "status": 401, "error": "Not authenticated."}

	var normalized_interaction_id := interaction_id.strip_edges()
	var normalized_request_id := request_id.strip_edges()
	if normalized_interaction_id == "" or normalized_request_id == "":
		return {"success": false, "status": 0, "error": "Missing story completion identity."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var endpoint := (STORY_INTERACTION_ENDPOINT % normalized_interaction_id.uri_encode()) + "/complete"
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"requestId": normalized_request_id,
			"expectedRevision": expected_revision,
			"mapId": map_id.strip_edges(),
			"entityId": entity_id.strip_edges(),
			"trigger": trigger.strip_edges(),
		})
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	if not _is_valid_story_complete_body(body, normalized_request_id, expected_revision):
		return {
			"success": false,
			"status": int(response.get("status", 0)),
			"error": "Story interaction completion response was invalid.",
		}

	var story: Dictionary = _dictionary_from_value(body.get("story", {}))
	var result := body.duplicate(true)
	result["success"] = true
	result["story"] = story.duplicate(true)
	return result


func _is_valid_story_complete_body(
	body: Dictionary,
	expected_request_id: String,
	expected_revision: int
) -> bool:
	if expected_revision < 0:
		return false
	var response_request_id_value: Variant = body.get("requestId", null)
	if not (response_request_id_value is String):
		return false
	var response_request_id := str(response_request_id_value)
	if (
		response_request_id != expected_request_id
		or not _is_canonical_uuid(response_request_id)
	):
		return false
	var story: Dictionary = _dictionary_from_value(body.get("story", {}))
	if not _is_valid_story_projection_body(story):
		return false
	if int(story.get("revision", -1)) != expected_revision + 1:
		return false
	return (
		body.has("effects")
		and body.get("effects") is Array
		and (body.get("effects") as Array).is_empty()
	)


func _is_valid_story_projection_body(story: Dictionary) -> bool:
	return (
		not story.is_empty()
		and story.has("revision")
		and _is_nonnegative_integer(story.get("revision"))
		and story.has("quests")
		and story.get("quests") is Array
	)


func _is_canonical_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	for index: int in range(value.length()):
		var character := value.substr(index, 1)
		if index in [8, 13, 18, 23]:
			if character != "-":
				return false
			continue
		var is_digit := character >= "0" and character <= "9"
		var is_lower_hex := character >= "a" and character <= "f"
		if not (is_digit or is_lower_hex):
			return false
	return value.substr(14, 1) == "4" and value.substr(19, 1) in ["8", "9", "a", "b"]


func _new_request_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		value.substr(0, 8),
		value.substr(8, 4),
		value.substr(12, 4),
		value.substr(16, 4),
		value.substr(20, 12),
	]


func _is_valid_story_resolve_body(body: Dictionary) -> bool:
	if not body.has("handled") or typeof(body.get("handled")) != TYPE_BOOL:
		return false
	if not body.has("interactionId") or not (body.get("interactionId") is String):
		return false
	var interaction_id := str(body.get("interactionId", ""))
	if interaction_id == "" or interaction_id != interaction_id.strip_edges():
		return false
	if not body.has("revision") or not _is_nonnegative_integer(body.get("revision")):
		return false
	if not body.has("actions") or not (body.get("actions") is Array):
		return false
	if not body.has("completionRequired") or typeof(body.get("completionRequired")) != TYPE_BOOL:
		return false
	if not bool(body.get("handled", false)):
		return _array_from_value(body.get("actions", [])).is_empty() and not bool(
			body.get("completionRequired", false)
		)
	return true


func _is_nonnegative_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return (
		is_finite(numeric_value)
		and numeric_value >= 0.0
		and floor(numeric_value) == numeric_value
	)


func load_public_trainer_card(user_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	if user_id <= 0:
		return {"success": false, "error": "Invalid trainer."}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + (PUBLIC_TRAINER_CARD_ENDPOINT % user_id),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	return {
		"success": true,
		"card": _dictionary_from_value(response.get("body", {})),
	}


func load_player_position() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_POSITION_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func save_player_position(state: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_POSITION_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(state)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func acknowledge_player_teleport(teleport_revision: int, teleport_command_id: String = "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var payload := {"teleportRevision": teleport_revision}
	var normalized_command_id := teleport_command_id.strip_edges()
	if normalized_command_id != "":
		payload["teleportCommandId"] = normalized_command_id
	var response: Dictionary = await _request_json(
		base_url + PLAYER_TELEPORT_ACK_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func load_respawn_point() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_RESPAWN_POINT_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasRespawnPoint": bool(body.get("hasRespawnPoint", false)),
		"respawnPoint": _dictionary_from_value(body.get("respawnPoint", {})),
	}


func save_respawn_point(respawn_point: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_RESPAWN_POINT_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(respawn_point)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasRespawnPoint": bool(body.get("hasRespawnPoint", false)),
		"respawnPoint": _dictionary_from_value(body.get("respawnPoint", {})),
	}


func respawn_player() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_RESPAWN_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party_response: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"position": _dictionary_from_value(body.get("position", {})),
		"party": {
			"hasParty": bool(party_response.get("hasParty", false)),
			"party": _array_from_value(party_response.get("party", [])),
		},
	}


func save_player_activity_state(activity_state: String, activity_context: Dictionary = {}) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var payload := {
		"activityState": activity_state.strip_edges().to_lower(),
		"activityContext": activity_context,
	}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_ACTIVITY_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"hasState": bool(body.get("hasState", false)),
		"state": _dictionary_from_value(body.get("state", {})),
	}


func load_map_players() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAP_PLAYERS_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var players_value: Variant = body.get("players", [])
	var players: Array = players_value if players_value is Array else []
	return {
		"success": true,
		"players": players,
	}


func load_player_preferences() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PREFERENCES_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"preferences": _dictionary_from_value(body.get("preferences", {})),
	}


func save_player_preferences(preferences: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_PREFERENCES_ENDPOINT,
		HTTPClient.METHOD_PUT,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(preferences)
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"preferences": _dictionary_from_value(body.get("preferences", {})),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
