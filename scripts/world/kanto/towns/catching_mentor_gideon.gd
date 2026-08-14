@tool
extends DialogueNPC

class_name CatchingMentorGideon

const CATCHING_QUEST_ID := "catch_route_22_mankey"
const CATCHING_TURN_IN_STEP_ID := "return_to_gideon"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return
	if StoryService.is_requirement_met(CATCHING_QUEST_ID, CATCHING_TURN_IN_STEP_ID, "active"):
		await _claim_catching_reward()
		return
	if StoryService.is_requirement_met(CATCHING_QUEST_ID, "", "completed"):
		await _show_completed_help()
		return
	await show_dialogue()


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(
		metadata.get("questRewardReceivedDialogueId", "")
	).strip_edges()
	quest_reward_completed_dialogue_id = str(
		metadata.get("questRewardCompletedDialogueId", "")
	).strip_edges()


func _claim_catching_reward() -> void:
	var inventory_service := get_node_or_null("/root/InventoryService")
	if (
		quest_reward_id.is_empty()
		or inventory_service == null
		or not inventory_service.has_method("claim_npc_item_reward")
	):
		await _show_report_to_staff_message()
		return
	var result_value: Variant = await inventory_service.call(
		"claim_npc_item_reward",
		quest_reward_id
	)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("CatchingMentorGideon: reward succeeded but story refresh failed locally.")
	await show_dialogue(await _resolve_dialogue_lines(
		quest_reward_received_dialogue_id,
		[
			"Well done! You proved your potential as a Trainer.",
			"Take these ten Great Balls. Better Poke Balls increase your catch rate.",
			"Visit the Market Seller in any Pokemon Center when you need more.",
		]
	))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.catch_mankey.title"),
			"reward": "10 %s" % ItemLocalization.display_name("great-ball", "Great Balls"),
		})
	)
	if bool(result.get("claimed", false)):
		SfxManager.play("item_received")


func _show_completed_help() -> void:
	var greeting := [LocalizationManager.text("mentor.gideon.help.greeting")]
	if (
		not quest_reward_completed_dialogue_id.is_empty()
		and quest_reward_completed_dialogue_id != quest_reward_received_dialogue_id
	):
		greeting = await _resolve_dialogue_lines(quest_reward_completed_dialogue_id, greeting)
	await show_dialogue(greeting)
	while true:
		var topic_id := await _choose_help_topic(
			LocalizationManager.text("mentor.gideon.help.title"),
			LocalizationManager.text("mentor.gideon.help.prompt"),
			[
				{"id": "finding", "label": LocalizationManager.text("mentor.gideon.help.topic.finding")},
				{"id": "catching", "label": LocalizationManager.text("mentor.gideon.help.topic.catching")},
				{"id": "odds", "label": LocalizationManager.text("mentor.gideon.help.topic.odds")},
			]
		)
		if topic_id.is_empty():
			return
		await show_dialogue(_gideon_help_lines(topic_id), display_name)


func _gideon_help_lines(topic_id: String) -> Array[String]:
	var keys: Array[String] = []
	match topic_id:
		"finding":
			keys = ["mentor.gideon.help.finding.1", "mentor.gideon.help.finding.2"]
		"catching":
			keys = ["mentor.gideon.help.catching.1", "mentor.gideon.help.catching.2"]
		"odds":
			keys = ["mentor.gideon.help.odds.1", "mentor.gideon.help.odds.2"]
	var lines: Array[String] = []
	for key: String in keys:
		lines.append(LocalizationManager.text(key))
	return lines


func _choose_help_topic(title: String, prompt: String, topics: Array[Dictionary]) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		title,
		prompt,
		topics,
		LocalizationManager.text("ui.mentor_help.eyebrow"),
		LocalizationManager.text("common.close")
	)
	menu.queue_free()
	return topic_id


func _resolve_dialogue_lines(dialogue_id: String, fallback: Array[String]) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		dialogue_id,
		fallback,
		"CatchingMentorGideon"
	)


func _show_report_to_staff_message() -> void:
	var error_service := get_node_or_null("/root/GameErrorDialogService")
	if error_service != null and error_service.has_method("show_report_to_staff_message"):
		await error_service.call("show_report_to_staff_message")
		return
	await show_dialogue(["I cannot finish the catching lesson right now."])
