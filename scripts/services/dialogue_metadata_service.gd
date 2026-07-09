extends Node

class_name DialogueMetadataServiceNode

const DIALOGUE_METADATA_ENDPOINT := "/dialogues/%s"

var dialogue_metadata_cache: Dictionary = {}


func get_dialogue(dialogue_id: String) -> Dictionary:
	var normalized_dialogue_id := dialogue_id.strip_edges()
	if normalized_dialogue_id.is_empty():
		return {
			"success": false,
			"error": "Missing dialogue_id",
			"metadata": {},
		}

	if dialogue_metadata_cache.has(normalized_dialogue_id):
		return dialogue_metadata_cache[normalized_dialogue_id]

	var response := await _fetch_dialogue_metadata(normalized_dialogue_id)
	if not response.get("success", false):
		return response

	var normalized_metadata := _normalize_dialogue_metadata(
		normalized_dialogue_id,
		response.get("metadata", {})
	)
	var result := {
		"success": true,
		"metadata": normalized_metadata,
	}
	dialogue_metadata_cache[normalized_dialogue_id] = result
	return result


func get_lines(dialogue_id: String) -> Array[String]:
	var response: Dictionary = await get_dialogue(dialogue_id)
	if not response.get("success", false):
		return []

	var metadata: Dictionary = response.get("metadata", {})
	return _get_string_array(metadata.get("lines", []))


func has_dialogue(dialogue_id: String) -> bool:
	var lines: Array[String] = await get_lines(dialogue_id)
	return not lines.is_empty()


func clear_cache() -> void:
	dialogue_metadata_cache.clear()


func _fetch_dialogue_metadata(dialogue_id: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + DIALOGUE_METADATA_ENDPOINT % dialogue_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var error := request.request(url, GatewayApiConfig.get_accept_headers())
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Dialogue metadata request failed to start",
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
			"error": "Dialogue metadata request failed with status %s" % response_code,
			"raw": response_text,
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": response_code,
			"error": "Dialogue metadata response was not valid JSON",
			"raw": response_text,
		}

	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("dialogue") and parsed_dictionary["dialogue"] is Dictionary:
		return {
			"success": true,
			"metadata": parsed_dictionary["dialogue"],
		}

	return {
		"success": false,
		"status": response_code,
		"error": "Dialogue metadata response did not include dialogue metadata",
		"raw": response_text,
	}


func _normalize_dialogue_metadata(dialogue_id: String, metadata: Dictionary) -> Dictionary:
	var dialogue_metadata := metadata.duplicate(true)
	dialogue_metadata["id"] = str(
		dialogue_metadata.get("id", dialogue_metadata.get("dialogueId", dialogue_metadata.get("dialogue_id", dialogue_id)))
	)
	dialogue_metadata["dialogueId"] = str(
		dialogue_metadata.get("dialogueId", dialogue_metadata.get("dialogue_id", dialogue_metadata["id"]))
	)
	dialogue_metadata["speakerName"] = str(
		dialogue_metadata.get("speakerName", dialogue_metadata.get("speaker_name", dialogue_metadata.get("name", "")))
	)
	dialogue_metadata["lines"] = _get_string_array(
		dialogue_metadata.get(
			"lines",
			dialogue_metadata.get(
				"dialogueLines",
				dialogue_metadata.get("dialogue_lines", dialogue_metadata.get("dialogue", []))
			)
		)
	)
	return dialogue_metadata


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var line := str(item).strip_edges()
			if not line.is_empty():
				strings.append(line)
	elif value is String:
		var line := str(value).strip_edges()
		if not line.is_empty():
			strings.append(line)
	return strings
