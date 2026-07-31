extends Node

class_name NpcDialogueServiceNode


func resolve_default_dialogue(
	metadata_dialogue_id: String,
	dialogue_override_id: String,
	legacy_dialogue_id: String,
	fallback_lines: Array[String],
	context := "NPC"
) -> Dictionary:
	var selection := select_dialogue_reference(
		metadata_dialogue_id,
		dialogue_override_id,
		legacy_dialogue_id
	)
	var resolved_dialogue_id := str(selection.get("dialogueId", ""))
	var source := str(selection.get("source", "fallback"))

	var result := await resolve_dialogue(
		resolved_dialogue_id,
		fallback_lines,
		context
	)
	result["source"] = source if not resolved_dialogue_id.is_empty() else "fallback"
	return result


func select_dialogue_reference(
	metadata_dialogue_id: String,
	dialogue_override_id: String,
	legacy_dialogue_id: String
) -> Dictionary:
	var explicit_override := dialogue_override_id.strip_edges()
	if not explicit_override.is_empty():
		return {
			"dialogueId": explicit_override,
			"source": "scene_override",
		}

	var metadata_reference := metadata_dialogue_id.strip_edges()
	if not metadata_reference.is_empty():
		return {
			"dialogueId": metadata_reference,
			"source": "npc_metadata",
		}

	var legacy_reference := legacy_dialogue_id.strip_edges()
	if not legacy_reference.is_empty():
		return {
			"dialogueId": legacy_reference,
			"source": "legacy_scene",
		}

	return {
		"dialogueId": "",
		"source": "fallback",
	}


func resolve_dialogue(
	dialogue_id: String,
	fallback_lines: Array[String] = [],
	context := "NPC"
) -> Dictionary:
	var normalized_fallback := _get_string_array(fallback_lines)
	var normalized_dialogue_id := dialogue_id.strip_edges()
	if normalized_dialogue_id.is_empty():
		if not normalized_fallback.is_empty():
			return {
				"success": true,
				"dialogueId": "",
				"speakerName": "",
				"lines": normalized_fallback,
				"usedFallback": true,
			}
		return {
			"success": false,
			"error": "%s has no dialogue reference" % context,
			"dialogueId": "",
			"speakerName": "",
			"lines": [],
			"usedFallback": false,
		}

	var dialogue_metadata_service := get_node_or_null(
		"/root/DialogueMetadataService"
	)
	if (
		dialogue_metadata_service == null
		or not dialogue_metadata_service.has_method("get_dialogue")
	):
		return _fallback_or_failure(
			normalized_dialogue_id,
			normalized_fallback,
			context,
			"DialogueMetadataService is unavailable"
		)

	var response_value: Variant = await dialogue_metadata_service.call(
		"get_dialogue",
		normalized_dialogue_id
	)
	var response: Dictionary = (
		response_value as Dictionary
		if response_value is Dictionary
		else {}
	)
	if bool(response.get("success", false)):
		var metadata_value: Variant = response.get("metadata", {})
		var metadata: Dictionary = (
			metadata_value as Dictionary
			if metadata_value is Dictionary
			else {}
		)
		var lines := _get_string_array(metadata.get("lines", []))
		if not lines.is_empty():
			return {
				"success": true,
				"dialogueId": normalized_dialogue_id,
				"speakerName": str(metadata.get("speakerName", "")).strip_edges(),
				"lines": lines,
				"usedFallback": false,
			}

	return _fallback_or_failure(
		normalized_dialogue_id,
		normalized_fallback,
		context,
		str(response.get(
			"error",
			"%s dialogue metadata was empty for %s" % [context, normalized_dialogue_id]
		))
	)


func resolve_lines(
	dialogue_id: String,
	fallback_lines: Array[String] = [],
	context := "NPC"
) -> Array[String]:
	var result := await resolve_dialogue(dialogue_id, fallback_lines, context)
	return _get_string_array(result.get("lines", []))


func _fallback_or_failure(
	dialogue_id: String,
	fallback_lines: Array[String],
	context: String,
	error: String
) -> Dictionary:
	if not fallback_lines.is_empty():
		push_warning(
			"%s: dialogue metadata was unavailable for %s; using the legacy inline fallback."
			% [context, dialogue_id]
		)
		return {
			"success": true,
			"dialogueId": dialogue_id,
			"speakerName": "",
			"lines": fallback_lines,
			"usedFallback": true,
		}
	return {
		"success": false,
		"error": error,
		"dialogueId": dialogue_id,
		"speakerName": "",
		"lines": [],
		"usedFallback": false,
	}


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
