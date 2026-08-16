@tool
extends DialogueNPC

class_name ThievingMentorRook

const QUEST_ID := "learn_to_pickpocket"
const RETURN_STEP_ID := "return_to_rook"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return
	if StoryService.is_requirement_met(QUEST_ID, RETURN_STEP_ID, "active"):
		await _claim_lesson_reward()
		return
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


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(
		metadata.get("questRewardReceivedDialogueId", "")
	).strip_edges()
	quest_reward_completed_dialogue_id = str(
		metadata.get("questRewardCompletedDialogueId", "")
	).strip_edges()


func _get_dialogue_metadata_lines() -> Array[String]:
	var lines: Array[String] = await super._get_dialogue_metadata_lines()
	return _format_hotkey(lines)


func _show_completed_help() -> void:
	var fallback_greeting: Array[String] = [
		LocalizationManager.text("mentor.rocket_rook.help.greeting")
	]
	var greeting_dialogue_id := (
		quest_reward_completed_dialogue_id
		if not quest_reward_completed_dialogue_id.is_empty()
		else "kanto_viridian_city_rocket_grunt_rook_completed"
	)
	var greeting: Array[String] = await NpcDialogueService.resolve_lines(
		greeting_dialogue_id,
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


func _claim_lesson_reward() -> void:
	if quest_reward_id.is_empty():
		await _show_report_to_staff_message()
		return
	var result: Dictionary = await InventoryService.claim_npc_item_reward(quest_reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("ThievingMentorRook: reward succeeded but story refresh failed locally.")
	await ThievingService.load_state()
	var fallback_lines: Array[String] = [
		"You completed Rook's first Thieving lesson.",
		"Higher Thieving levels unlock more alert target classes with better rewards.",
	]
	var reward_lines: Array[String] = await NpcDialogueService.resolve_lines(
		quest_reward_received_dialogue_id,
		fallback_lines,
		"ThievingMentorRook"
	)
	await show_dialogue(_format_hotkey(reward_lines), display_name)
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.learn_to_pickpocket.title"),
			"reward": LocalizationManager.text("ui.quest.thieving_lesson_reward", {
				"tm": ItemLocalization.display_name("tm-thief", "TM Thief"),
				"glasses": ItemLocalization.display_name("black-glasses", "Black Glasses"),
			}),
		})
	)
	if bool(result.get("claimed", false)):
		SfxManager.play("item_received")


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


func _show_report_to_staff_message() -> void:
	var error_service := get_node_or_null("/root/GameErrorDialogService")
	if error_service != null and error_service.has_method("show_report_to_staff_message"):
		await error_service.call("show_report_to_staff_message")
		return
	await show_dialogue([LocalizationManager.text("npc.error.thieving_lesson")], display_name)
