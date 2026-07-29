@tool
extends BaseNPC

class_name DialogueNPC


func _ready() -> void:
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> void:
	if not lines.is_empty():
		await super.show_dialogue(lines, speaker_name_override)
		return

	var dialogue_metadata_lines := await _get_dialogue_metadata_lines()
	if not dialogue_metadata_lines.is_empty():
		await super.show_dialogue(dialogue_metadata_lines, speaker_name_override)
		return

	await super.show_dialogue(lines, speaker_name_override)


func _get_dialogue_metadata_lines() -> Array[String]:
	if dialogue_id.strip_edges().is_empty() and not _get_npc_metadata_id().is_empty():
		var metadata_response: Dictionary = await _load_npc_metadata()
		if not metadata_response.get("success", false):
			return []

	var resolved_dialogue_id := dialogue_id.strip_edges()
	if resolved_dialogue_id.is_empty():
		return []

	var dialogue_response: Dictionary = await DialogueMetadataService.get_dialogue(resolved_dialogue_id)
	if not dialogue_response.get("success", false):
		push_warning("%s dialogue metadata failed for %s: %s" % [
			name,
			resolved_dialogue_id,
			str(dialogue_response.get("error", "Unknown API error")),
		])
		return []

	var dialogue_metadata: Dictionary = dialogue_response.get("metadata", {})
	return _get_string_array(dialogue_metadata.get("lines", []))
