extends Node

class_name StoryServiceNode

signal story_changed(revision: int)

var _story: Dictionary = {
	"revision": 0,
	"quests": [],
}


func project_story(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _empty_story()

	var source: Dictionary = value as Dictionary
	var projected_quests: Array = []
	var quests_value: Variant = source.get("quests", [])
	if quests_value is Array:
		for quest_value: Variant in quests_value as Array:
			if quest_value is Dictionary:
				projected_quests.append(_project_quest(quest_value as Dictionary))

	return {
		"revision": maxi(int(source.get("revision", 0)), 0),
		"quests": projected_quests,
	}


func apply_story(value: Variant) -> void:
	_story = project_story(value)
	story_changed.emit(get_revision())


func apply_story_if_not_stale(value: Variant) -> bool:
	var projected := project_story(value)
	if int(projected.get("revision", 0)) < get_revision():
		return false
	_story = projected
	story_changed.emit(get_revision())
	return true


func reset_story() -> void:
	_story = _empty_story()
	story_changed.emit(0)


func get_story() -> Dictionary:
	return _story.duplicate(true)


func get_quests() -> Array:
	var quests_value: Variant = _story.get("quests", [])
	return (quests_value as Array).duplicate(true) if quests_value is Array else []


func get_quest(quest_id: String) -> Dictionary:
	var normalized_quest_id := quest_id.strip_edges()
	for quest_value: Variant in _story.get("quests", []):
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value as Dictionary
		if str(quest.get("questId", "")) == normalized_quest_id:
			return quest.duplicate(true)
	return {}


func is_requirement_met(
	quest_id: String,
	quest_step_id := "",
	required_status := "completed"
) -> bool:
	var normalized_quest_id := quest_id.strip_edges()
	if normalized_quest_id.is_empty():
		return true

	var quest := get_quest(normalized_quest_id)
	if quest.is_empty():
		return false

	var normalized_status := required_status.strip_edges().to_lower()
	var normalized_step_id := quest_step_id.strip_edges()
	if normalized_step_id.is_empty():
		return str(quest.get("status", "")).strip_edges().to_lower() == normalized_status

	var steps_value: Variant = quest.get("steps", [])
	if not steps_value is Array:
		return false
	for step_value: Variant in steps_value as Array:
		if not step_value is Dictionary:
			continue
		var step := step_value as Dictionary
		if str(step.get("stepId", "")).strip_edges() != normalized_step_id:
			continue
		return str(step.get("status", "")).strip_edges().to_lower() == normalized_status
	return false


func get_revision() -> int:
	return int(_story.get("revision", 0))


func _project_quest(source: Dictionary) -> Dictionary:
	var projected_steps: Array = []
	var steps_value: Variant = source.get("steps", [])
	if steps_value is Array:
		for step_value: Variant in steps_value as Array:
			if step_value is Dictionary:
				projected_steps.append(_project_step(step_value as Dictionary))

	return {
		"questId": str(source.get("questId", "")),
		"storylineId": str(source.get("storylineId", "")),
		"definitionVersion": maxi(int(source.get("definitionVersion", 1)), 1),
		"questType": str(source.get("questType", "main")),
		"titleKey": str(source.get("titleKey", "")),
		"summaryKey": str(source.get("summaryKey", "")),
		"status": str(source.get("status", "")),
		"steps": projected_steps,
		"rewardPreviews": _project_reward_previews(source.get("rewardPreviews", [])),
		"startedAt": _project_optional_timestamp(source.get("startedAt", null)),
		"completedAt": _project_optional_timestamp(source.get("completedAt", null)),
	}


func _project_reward_previews(source: Variant) -> Array:
	var projected: Array = []
	if source is not Array:
		return projected
	for value: Variant in source as Array:
		if value is not Dictionary:
			continue
		var reward := value as Dictionary
		match str(reward.get("type", "")):
			"item":
				var item_id := str(reward.get("itemId", "")).strip_edges()
				if not item_id.is_empty():
					projected.append({
						"type": "item",
						"itemId": item_id,
						"quantity": maxi(int(reward.get("quantity", 1)), 1),
					})
			"currency":
				var currency := str(reward.get("currency", "")).strip_edges()
				if not currency.is_empty():
					projected.append({
						"type": "currency",
						"currency": currency,
						"amount": maxi(int(reward.get("amount", 1)), 1),
					})
			"skill_experience":
				var skill_id := str(reward.get("skillId", "")).strip_edges().to_lower()
				if not skill_id.is_empty():
					projected.append({
						"type": "skill_experience",
						"skillId": skill_id,
						"experience": maxi(int(reward.get("experience", 1)), 1),
					})
	return projected


func _project_step(source: Dictionary) -> Dictionary:
	var target_value := maxi(int(source.get("targetValue", 1)), 1)
	return {
		"stepId": str(source.get("stepId", "")),
		"objectiveKey": str(source.get("objectiveKey", "")),
		"status": str(source.get("status", "")),
		"currentValue": clampi(int(source.get("currentValue", 0)), 0, target_value),
		"targetValue": target_value,
		"activatedAt": _project_optional_timestamp(source.get("activatedAt", null)),
		"completedAt": _project_optional_timestamp(source.get("completedAt", null)),
	}


func _project_optional_timestamp(value: Variant) -> Variant:
	return null if value == null else str(value)


func _empty_story() -> Dictionary:
	return {
		"revision": 0,
		"quests": [],
	}
