@tool
extends BaseNPC

class_name DialogueNPC

var resolved_dialogue_speaker_name := ""


func _ready() -> void:
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> void:
	var resolved_speaker_name := speaker_name_override.strip_edges()
	if resolved_speaker_name.is_empty():
		resolved_speaker_name = resolved_dialogue_speaker_name
	if not lines.is_empty():
		await super.show_dialogue(lines, resolved_speaker_name)
		return

	var dialogue_metadata_lines := await _get_dialogue_metadata_lines()
	if not dialogue_metadata_lines.is_empty():
		if speaker_name_override.strip_edges().is_empty():
			resolved_speaker_name = resolved_dialogue_speaker_name
		await super.show_dialogue(dialogue_metadata_lines, resolved_speaker_name)
		return

	await super.show_dialogue(lines, resolved_speaker_name)


func _get_dialogue_metadata_lines() -> Array[String]:
	if not _get_npc_metadata_id().is_empty():
		var metadata_response: Dictionary = await _load_npc_metadata()
		if (
			not metadata_response.get("success", false)
			and _get_dialogue_override_id().is_empty()
			and dialogue_lines.is_empty()
		):
			return []

	var result: Dictionary = await NpcDialogueService.resolve_default_dialogue(
		metadata_dialogue_id,
		_get_dialogue_override_id(),
		"",
		dialogue_lines,
		_get_npc_metadata_id() if not _get_npc_metadata_id().is_empty() else name
	)
	resolved_dialogue_speaker_name = str(
		result.get("speakerName", "")
	).strip_edges()
	return _get_string_array(result.get("lines", []))
