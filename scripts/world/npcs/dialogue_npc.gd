@tool
extends BaseNPC

class_name DialogueNPC

var resolved_dialogue_speaker_name := ""
var story_dialogue_variants: Array[Dictionary] = []
var offered_quest_id := ""
var offered_quest_required_quest_id := ""
var offered_quest_required_quest_step_id := ""
var offered_quest_required_quest_status := "completed"


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
		var shown := await super.show_dialogue(dialogue_metadata_lines, resolved_speaker_name)
		if shown:
			await _show_available_quest_offer(resolved_speaker_name)
		return shown

	var shown := await super.show_dialogue(lines, resolved_speaker_name)
	if shown:
		await _show_available_quest_offer(resolved_speaker_name)
	return shown


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
	offered_quest_id = str(metadata.get("offeredQuestId", "")).strip_edges()
	offered_quest_required_quest_id = str(
		metadata.get("offeredQuestRequiredQuestId", "")
	).strip_edges()
	offered_quest_required_quest_step_id = str(
		metadata.get("offeredQuestRequiredQuestStepId", "")
	).strip_edges()
	offered_quest_required_quest_status = str(
		metadata.get("offeredQuestRequiredQuestStatus", "completed")
	).strip_edges().to_lower()
	story_dialogue_variants.clear()
	var variants_value: Variant = metadata.get("dialogueVariants", [])
	if not variants_value is Array:
		return
	for variant_value: Variant in variants_value as Array:
		if variant_value is Dictionary:
			story_dialogue_variants.append((variant_value as Dictionary).duplicate(true))


func _show_available_quest_offer(speaker_name: String) -> void:
	if offered_quest_id.is_empty():
		return
	if (
		not offered_quest_required_quest_id.is_empty()
		and not StoryService.is_requirement_met(
			offered_quest_required_quest_id,
			offered_quest_required_quest_step_id,
			offered_quest_required_quest_status
		)
	):
		return
	var quest := StoryService.get_quest(offered_quest_id)
	if (
		str(quest.get("questType", "")) != "side"
		or str(quest.get("status", "")) != "available"
	):
		return
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null or not dialogue_box.has_method("start_quest_offer"):
		return
	var offer_speaker_name := speaker_name.strip_edges()
	if offer_speaker_name.is_empty():
		offer_speaker_name = display_name if not display_name.is_empty() else name
	dialogue_box.start_quest_offer(quest, offer_speaker_name, mugshot)
	await dialogue_box.quest_offer_resolved


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
