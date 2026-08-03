extends Node

class_name NpcMetadataServiceNode

const NPC_METADATA_ENDPOINT := "/npcs/%s"

var npc_metadata_cache: Dictionary = {}


func get_npc_metadata(npc_id: String) -> Dictionary:
	var normalized_npc_id := npc_id.strip_edges()
	if normalized_npc_id.is_empty():
		return {
			"success": false,
			"error": "Missing npc_id",
			"metadata": {},
		}

	var locale := _get_http_locale()
	var cache_key := _get_cache_key(locale, normalized_npc_id)
	if npc_metadata_cache.has(cache_key):
		return npc_metadata_cache[cache_key]

	var response := await _fetch_npc_metadata(normalized_npc_id, locale)
	if not response.get("success", false):
		return response

	var normalized_metadata := _normalize_npc_metadata(normalized_npc_id, response.get("metadata", {}))
	var result := {
		"success": true,
		"metadata": normalized_metadata,
	}
	npc_metadata_cache[cache_key] = result
	return result


func clear_cache() -> void:
	npc_metadata_cache.clear()


func _fetch_npc_metadata(npc_id: String, locale: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + NPC_METADATA_ENDPOINT % npc_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var error := request.request(url, GatewayApiConfig.get_accept_headers(locale))
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "NPC metadata request failed to start",
			"code": error,
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var response_code := int(result[1])
	var body: PackedByteArray = result[3]
	var response_text := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": "NPC metadata request failed with status %s" % response_code,
			"raw": response_text,
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": response_code,
			"error": "NPC metadata response was not valid JSON",
			"raw": response_text,
		}

	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("npc") and parsed_dictionary["npc"] is Dictionary:
		return {
			"success": true,
			"metadata": parsed_dictionary["npc"],
		}

	return {
		"success": false,
		"status": response_code,
		"error": "NPC metadata response did not include npc metadata",
		"raw": response_text,
	}


func _normalize_npc_metadata(npc_id: String, metadata: Dictionary) -> Dictionary:
	var npc_metadata := metadata.duplicate(true)
	npc_metadata["id"] = str(npc_metadata.get("id", npc_id))
	npc_metadata["dialogueId"] = str(npc_metadata.get("dialogueId", npc_metadata.get("dialogue_id", "")))
	npc_metadata["type"] = str(npc_metadata.get("type", ""))
	npc_metadata["name"] = str(npc_metadata.get("name", ""))
	npc_metadata["dialogue"] = _get_string_array(npc_metadata.get("dialogue", []))
	npc_metadata["blockedDialogueId"] = str(npc_metadata.get("blockedDialogueId", npc_metadata.get("blocked_dialogue_id", "")))
	npc_metadata["storyBlockedDialogueId"] = str(npc_metadata.get("storyBlockedDialogueId", npc_metadata.get("story_blocked_dialogue_id", "")))
	npc_metadata["staffBlockedDialogueId"] = str(npc_metadata.get("staffBlockedDialogueId", npc_metadata.get("staff_blocked_dialogue_id", "")))
	npc_metadata["allowedDialogueId"] = str(npc_metadata.get("allowedDialogueId", npc_metadata.get("allowed_dialogue_id", "")))
	npc_metadata["blockedDialogue"] = _get_string_array(npc_metadata.get("blockedDialogue", []))
	npc_metadata["storyBlockedDialogue"] = _get_string_array(npc_metadata.get("storyBlockedDialogue", []))
	npc_metadata["allowedDialogue"] = _get_string_array(npc_metadata.get("allowedDialogue", []))
	npc_metadata["successDialogueId"] = str(npc_metadata.get("successDialogueId", npc_metadata.get("success_dialogue_id", "")))
	npc_metadata["alreadyHealedDialogueId"] = str(npc_metadata.get("alreadyHealedDialogueId", npc_metadata.get("already_healed_dialogue_id", "")))
	npc_metadata["noPartyDialogueId"] = str(npc_metadata.get("noPartyDialogueId", npc_metadata.get("no_party_dialogue_id", "")))
	npc_metadata["failureDialogueId"] = str(npc_metadata.get("failureDialogueId", npc_metadata.get("failure_dialogue_id", "")))
	npc_metadata["openingDialogueId"] = str(npc_metadata.get("openingDialogueId", npc_metadata.get("opening_dialogue_id", "")))
	npc_metadata["alreadyReceivedDialogueId"] = str(npc_metadata.get("alreadyReceivedDialogueId", npc_metadata.get("already_received_dialogue_id", "")))
	npc_metadata["rewardId"] = str(npc_metadata.get("rewardId", npc_metadata.get("reward_id", "")))
	npc_metadata["rewardItemId"] = str(npc_metadata.get("rewardItemId", npc_metadata.get("reward_item_id", "")))
	npc_metadata["lockedDialogueId"] = str(npc_metadata.get("lockedDialogueId", npc_metadata.get("locked_dialogue_id", "")))
	npc_metadata["successDialogue"] = _get_string_array(npc_metadata.get("successDialogue", []))
	npc_metadata["alreadyHealedDialogue"] = _get_string_array(npc_metadata.get("alreadyHealedDialogue", []))
	npc_metadata["noPartyDialogue"] = _get_string_array(npc_metadata.get("noPartyDialogue", []))
	npc_metadata["failureDialogue"] = _get_string_array(npc_metadata.get("failureDialogue", []))
	npc_metadata["openingDialogue"] = _get_string_array(npc_metadata.get("openingDialogue", []))
	npc_metadata["healedSystemMessage"] = str(npc_metadata.get("healedSystemMessage", ""))
	npc_metadata["marketId"] = str(npc_metadata.get("marketId", npc_metadata.get("market_id", "")))
	npc_metadata["marketMode"] = str(npc_metadata.get("marketMode", npc_metadata.get("market_mode", "")))
	npc_metadata["requiresPartyPokemon"] = bool(npc_metadata.get("requiresPartyPokemon", false))
	npc_metadata["requiredQuestId"] = str(npc_metadata.get("requiredQuestId", npc_metadata.get("required_quest_id", "")))
	npc_metadata["requiredQuestStepId"] = str(npc_metadata.get("requiredQuestStepId", npc_metadata.get("required_quest_step_id", "")))
	npc_metadata["requiredQuestStatus"] = str(npc_metadata.get("requiredQuestStatus", npc_metadata.get("required_quest_status", "completed")))
	npc_metadata["offeredQuestRequiredQuestId"] = str(npc_metadata.get("offeredQuestRequiredQuestId", ""))
	npc_metadata["offeredQuestRequiredQuestStepId"] = str(npc_metadata.get("offeredQuestRequiredQuestStepId", ""))
	npc_metadata["offeredQuestRequiredQuestStatus"] = str(npc_metadata.get("offeredQuestRequiredQuestStatus", "completed"))
	return npc_metadata


func _get_http_locale() -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("get_http_locale"):
		return str(localization_manager.call("get_http_locale"))
	return "en"


func _get_cache_key(locale: String, npc_id: String) -> String:
	return "%s:%s" % [locale, npc_id]


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
