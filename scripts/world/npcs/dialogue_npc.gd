@tool
extends BaseNPC

class_name DialogueNPC

var resolved_dialogue_speaker_name := ""
var story_dialogue_variants: Array[Dictionary] = []


func _ready() -> void:
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> bool:
	var resolved_speaker_name := speaker_name_override.strip_edges()
	if resolved_speaker_name.is_empty():
		resolved_speaker_name = resolved_dialogue_speaker_name
	if not lines.is_empty():
		return await super.show_dialogue(lines, resolved_speaker_name)

	var dialogue_metadata_lines := await _get_dialogue_metadata_lines()
	if not dialogue_metadata_lines.is_empty():
		if speaker_name_override.strip_edges().is_empty():
			resolved_speaker_name = resolved_dialogue_speaker_name
		return await super.show_dialogue(dialogue_metadata_lines, resolved_speaker_name)

	return await super.show_dialogue(lines, resolved_speaker_name)


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
		_resolve_story_dialogue_id(),
		_get_dialogue_override_id(),
		"",
		dialogue_lines,
		_get_npc_metadata_id() if not _get_npc_metadata_id().is_empty() else name
	)
	resolved_dialogue_speaker_name = str(
		result.get("speakerName", "")
	).strip_edges()
	return _get_string_array(result.get("lines", []))


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	story_dialogue_variants.clear()
	var variants_value: Variant = metadata.get("dialogueVariants", [])
	if not variants_value is Array:
		return
	for variant_value: Variant in variants_value as Array:
		if variant_value is Dictionary:
			story_dialogue_variants.append((variant_value as Dictionary).duplicate(true))


func _resolve_story_dialogue_id() -> String:
	for variant: Dictionary in story_dialogue_variants:
		var dialogue_reference := str(variant.get("dialogueId", "")).strip_edges()
		var quest_id := str(variant.get("requiredQuestId", "")).strip_edges()
		if dialogue_reference.is_empty() or quest_id.is_empty():
			continue
		if StoryService.is_requirement_met(
			quest_id,
			str(variant.get("requiredQuestStepId", "")).strip_edges(),
			str(variant.get("requiredQuestStatus", "completed")).strip_edges()
		):
			return dialogue_reference
	return metadata_dialogue_id
