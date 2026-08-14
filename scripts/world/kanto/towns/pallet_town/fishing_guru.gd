@tool
extends ItemGiftNPC

class_name FishingGuru

const QUEST_ID := "learn_to_fish"
const RECEIVE_ROD_STEP_ID := "receive_old_rod"
const RETURN_STEP_ID := "return_to_fishing_guru"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""


func interact_with_player(player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	var quest := StoryService.get_quest(QUEST_ID)
	var quest_status := str(quest.get("status", "")).strip_edges().to_lower()
	if quest_status == "available":
		await show_dialogue()
		return
	if StoryService.is_requirement_met(QUEST_ID, RECEIVE_ROD_STEP_ID, "active"):
		await super.interact_with_player(player)
		return
	if StoryService.is_requirement_met(QUEST_ID, RETURN_STEP_ID, "active"):
		await _claim_lesson_reward()
		return
	if StoryService.is_requirement_met(QUEST_ID, "", "completed"):
		await _show_completed_help()
		return
	await show_dialogue()


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(
		metadata.get("questRewardReceivedDialogueId", "")
	).strip_edges()


func _claim_lesson_reward() -> void:
	if quest_reward_id.is_empty():
		await _show_report_to_staff_message()
		return
	var result: Dictionary = await InventoryService.claim_npc_item_reward(quest_reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("FishingGuru: reward succeeded but story refresh failed locally.")
	await show_dialogue(await NpcDialogueService.resolve_lines(
		quest_reward_received_dialogue_id,
		["You completed your first fishing lesson!"],
		"FishingGuru"
	))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.learn_to_fish.title"),
			"reward": LocalizationManager.text("ui.quest.fishing_lesson_reward"),
		})
	)
	if bool(result.get("claimed", false)):
		SfxManager.play("item_received")


func _show_completed_help() -> void:
	await show_dialogue([LocalizationManager.text("mentor.fishing_guru.help.greeting")])
	while true:
		var topic_id := await _choose_help_topic([
			{"id": "starting", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.starting")},
			{"id": "catching", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.catching")},
			{"id": "progression", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.progression")},
		])
		if topic_id.is_empty():
			return
		await show_dialogue(_help_lines(topic_id), display_name)


func _choose_help_topic(topics: Array[Dictionary]) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		LocalizationManager.text("mentor.fishing_guru.help.title"),
		LocalizationManager.text("mentor.fishing_guru.help.prompt"),
		topics,
		LocalizationManager.text("ui.mentor_help.eyebrow"),
		LocalizationManager.text("common.close")
	)
	menu.queue_free()
	return topic_id


func _help_lines(topic_id: String) -> Array[String]:
	var keys: Array[String] = []
	match topic_id:
		"starting":
			keys = ["mentor.fishing_guru.help.starting.1", "mentor.fishing_guru.help.starting.2"]
		"catching":
			keys = ["mentor.fishing_guru.help.catching.1", "mentor.fishing_guru.help.catching.2"]
		"progression":
			keys = ["mentor.fishing_guru.help.progression.1", "mentor.fishing_guru.help.progression.2"]
	var lines: Array[String] = []
	for key: String in keys:
		lines.append(LocalizationManager.text(key))
	return lines
