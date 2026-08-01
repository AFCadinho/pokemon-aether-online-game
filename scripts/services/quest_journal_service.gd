extends Node

class_name QuestJournalServiceNode

signal journal_changed


func _ready() -> void:
	var story_service := _story_service()
	if story_service != null and not story_service.story_changed.is_connected(_on_story_changed):
		story_service.story_changed.connect(_on_story_changed)


func get_entries() -> Array:
	var offers: Array = []
	var active: Array = []
	var history: Array = []
	var story_service := _story_service()
	if story_service == null:
		return []
	for quest_value: Variant in story_service.get_quests():
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value as Dictionary
		match str(quest.get("status", "")):
			"available":
				offers.append(quest.duplicate(true))
			"active":
				active.append(quest.duplicate(true))
			"completed", "failed":
				history.append(quest.duplicate(true))
	return active + offers + history


func get_active_main_quest() -> Dictionary:
	var story_service := _story_service()
	if story_service == null:
		return {}
	for quest_value: Variant in story_service.get_quests():
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value as Dictionary
		if str(quest.get("status", "")) != "active":
			continue
		if str(quest.get("questType", "main")) == "main":
			return quest.duplicate(true)
	return {}


func get_active_side_quests() -> Array:
	var result: Array = []
	for quest_value: Variant in get_entries():
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value as Dictionary
		if (
			str(quest.get("status", "")) == "active"
			and str(quest.get("questType", "main")) == "side"
		):
			result.append(quest.duplicate(true))
	return result


func get_active_objective(quest: Dictionary = {}) -> Dictionary:
	var source_quest := quest if not quest.is_empty() else get_active_main_quest()
	var steps_value: Variant = source_quest.get("steps", [])
	if not (steps_value is Array):
		return {}
	for step_value: Variant in steps_value as Array:
		if step_value is Dictionary and str((step_value as Dictionary).get("status", "")) == "active":
			return (step_value as Dictionary).duplicate(true)
	return {}


func get_visible_steps(quest: Dictionary) -> Array:
	var result: Array = []
	var steps_value: Variant = quest.get("steps", [])
	if not (steps_value is Array):
		return result
	for step_value: Variant in steps_value as Array:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value as Dictionary
		if str(step.get("status", "")) in ["active", "completed", "failed", "skipped"]:
			result.append(step.duplicate(true))
	return result


func _on_story_changed(_revision: int) -> void:
	journal_changed.emit()


func _story_service() -> Node:
	return get_node_or_null("/root/StoryService")
