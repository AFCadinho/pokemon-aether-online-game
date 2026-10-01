@tool
extends "res://scripts/world/npcs/gate_npc.gd"

# The first ticket conversation runs through StoryHook. Repeat visits reflect
# the existing rival quest without issuing the skipper's request again.
func select_allowed_dialogue_id() -> String:
	var story := get_node_or_null("/root/StoryService")
	if story != null:
		if bool(story.call("is_requirement_met", "ss_anne_rival", "", "completed")):
			return "kanto_ss_anne_skipper_thanks"
		if bool(story.call("is_requirement_met", "ss_anne_rival", "", "active")):
			return "kanto_ss_anne_skipper_reminder"
	return allowed_dialogue_id


func select_gate_dialogue_id(dialogue_reference_id: String) -> String:
	if not allowed_dialogue_id.is_empty() and dialogue_reference_id == allowed_dialogue_id:
		return select_allowed_dialogue_id()
	return dialogue_reference_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array) -> Array[String]:
	return await super._resolve_dialogue_lines(select_gate_dialogue_id(dialogue_reference_id), fallback_lines)
