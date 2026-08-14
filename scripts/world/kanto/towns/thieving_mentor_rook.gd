@tool
extends DialogueNPC

class_name ThievingMentorRook

const QUEST_ID := "learn_to_pickpocket"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")


func interact_with_player(_player: Node2D) -> void:
	if StoryService.is_requirement_met(QUEST_ID, "", "completed"):
		await _show_completed_help()
		return

	var was_unlocked := ThievingService.is_unlocked()
	await show_dialogue()
	var state_result: Dictionary = await ThievingService.load_state()
	if (
		bool(state_result.get("success", false))
		and not was_unlocked
		and ThievingService.is_unlocked()
	):
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.skill.thieving.unlocked")
		)


func _get_dialogue_metadata_lines() -> Array[String]:
	var lines: Array[String] = await super._get_dialogue_metadata_lines()
	return _format_hotkey(lines)


func _show_completed_help() -> void:
	var fallback_greeting: Array[String] = [
		LocalizationManager.text("mentor.rocket_rook.help.greeting")
	]
	var greeting: Array[String] = await NpcDialogueService.resolve_lines(
		"kanto_viridian_city_rocket_grunt_rook_completed",
		fallback_greeting,
		"ThievingMentorRook"
	)
	await show_dialogue(_format_hotkey(greeting), display_name)
	while true:
		var topics: Array[Dictionary] = [
			{"id": "basics", "label": LocalizationManager.text("mentor.rocket_rook.help.topic.basics")},
			{"id": "risk", "label": LocalizationManager.text("mentor.rocket_rook.help.topic.risk")},
			{"id": "targets", "label": LocalizationManager.text("mentor.rocket_rook.help.topic.targets")},
			{"id": "progression", "label": LocalizationManager.text("mentor.rocket_rook.help.topic.progression")},
		]
		var topic_id := await _choose_help_topic(topics)
		if topic_id.is_empty():
			return
		await show_dialogue(_help_lines(topic_id), display_name)


func _choose_help_topic(topics: Array[Dictionary]) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		LocalizationManager.text("mentor.rocket_rook.help.title"),
		LocalizationManager.text("mentor.rocket_rook.help.prompt"),
		topics,
		LocalizationManager.text("ui.mentor_help.eyebrow"),
		LocalizationManager.text("common.close")
	)
	menu.queue_free()
	return topic_id


func _help_lines(topic_id: String) -> Array[String]:
	var keys: Array[String] = [
		"mentor.rocket_rook.help.%s.1" % topic_id,
		"mentor.rocket_rook.help.%s.2" % topic_id,
	]
	var lines: Array[String] = []
	for key: String in keys:
		lines.append(LocalizationManager.text(key, _hotkey_values()))
	return lines


func _format_hotkey(lines: Array[String]) -> Array[String]:
	var formatted: Array[String] = []
	for line: String in lines:
		formatted.append(line.format(_hotkey_values()))
	return formatted


func _hotkey_values() -> Dictionary:
	return {"pickpocket_hotkey": SettingsManager.get_input_binding_label("pickpocket")}
