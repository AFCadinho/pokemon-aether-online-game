extends Node

class_name NpcMetadataServiceNode

const NPC_METADATA_ENDPOINT := "/npcs/%s"

var npc_metadata_cache: Dictionary = {}


func get_npc_metadata(npc_id: String) -> Dictionary:
	if npc_metadata_cache.has(npc_id):
		return npc_metadata_cache[npc_id]

	var response := await _fetch_npc_metadata(npc_id)
	if not response.get("success", false):
		return response

	var normalized_metadata := _normalize_npc_metadata(npc_id, response.get("metadata", {}))
	var result := {
		"success": true,
		"metadata": normalized_metadata,
	}
	npc_metadata_cache[npc_id] = result
	return result


func clear_cache() -> void:
	npc_metadata_cache.clear()


func _fetch_npc_metadata(npc_id: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + NPC_METADATA_ENDPOINT % npc_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var error := request.request(url, GatewayApiConfig.get_accept_headers())
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
	npc_metadata["staffBlockedDialogueId"] = str(npc_metadata.get("staffBlockedDialogueId", npc_metadata.get("staff_blocked_dialogue_id", "")))
	npc_metadata["allowedDialogueId"] = str(npc_metadata.get("allowedDialogueId", npc_metadata.get("allowed_dialogue_id", "")))
	npc_metadata["blockedDialogue"] = _get_string_array(npc_metadata.get("blockedDialogue", []))
	npc_metadata["allowedDialogue"] = _get_string_array(npc_metadata.get("allowedDialogue", []))
	npc_metadata["successDialogueId"] = str(npc_metadata.get("successDialogueId", npc_metadata.get("success_dialogue_id", "")))
	npc_metadata["alreadyHealedDialogueId"] = str(npc_metadata.get("alreadyHealedDialogueId", npc_metadata.get("already_healed_dialogue_id", "")))
	npc_metadata["noPartyDialogueId"] = str(npc_metadata.get("noPartyDialogueId", npc_metadata.get("no_party_dialogue_id", "")))
	npc_metadata["failureDialogueId"] = str(npc_metadata.get("failureDialogueId", npc_metadata.get("failure_dialogue_id", "")))
	npc_metadata["successDialogue"] = _get_string_array(npc_metadata.get("successDialogue", []))
	npc_metadata["alreadyHealedDialogue"] = _get_string_array(npc_metadata.get("alreadyHealedDialogue", []))
	npc_metadata["noPartyDialogue"] = _get_string_array(npc_metadata.get("noPartyDialogue", []))
	npc_metadata["failureDialogue"] = _get_string_array(npc_metadata.get("failureDialogue", []))
	npc_metadata["healedSystemMessage"] = str(npc_metadata.get("healedSystemMessage", ""))
	npc_metadata["requiresPartyPokemon"] = bool(npc_metadata.get("requiresPartyPokemon", false))
	return npc_metadata


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
