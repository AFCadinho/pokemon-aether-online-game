@tool
extends ItemGiftNPC

class_name KarateMasterKenji

const QUEST_ID := "learn_rock_smash"
const RECEIVE_STEP_ID := "receive_rock_smash"
const RETURN_STEP_ID := "return_to_karate_master"
const OFFER_PREREQUISITE_QUEST_ID := "learn_at_trainer_school"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""


func interact_with_player(player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return
	var quest := StoryService.get_quest(QUEST_ID)
	var quest_status := str(quest.get("status", "")).strip_edges().to_lower()
	if quest_status == "available":
		if _is_lesson_offer_unlocked():
			await _show_available_quest_offer(display_name)
		else:
			await show_dialogue()
		return
	if StoryService.is_requirement_met(QUEST_ID, RECEIVE_STEP_ID, "active"):
		var was_unlocked := RockSmashService.is_unlocked()
		await super.interact_with_player(player)
		var state_result: Dictionary = await RockSmashService.load_state()
		if (
			bool(state_result.get("success", false))
			and not was_unlocked
			and RockSmashService.is_unlocked()
		):
			get_tree().call_group(
				"ui_overlay",
				"add_system_message",
				LocalizationManager.text("ui.skill.rock_smash.unlocked")
			)
		return
	if StoryService.is_requirement_met(QUEST_ID, RETURN_STEP_ID, "active"):
		await _claim_lesson_reward()
		return
	if StoryService.is_requirement_met(QUEST_ID, "", "completed"):
		await _show_completed_help()
		return
	await show_dialogue()


func _is_lesson_offer_unlocked() -> bool:
	return StoryService.is_requirement_met(OFFER_PREREQUISITE_QUEST_ID, "", "completed")


func _refresh_quest_marker() -> void:
	super._refresh_quest_marker()
	if quest_marker != null and quest_marker.visible:
		return
	if not _should_show_lesson_marker():
		return
	_setup_quest_marker()
	quest_marker.visible = true
	quest_marker_label.text = "✦"
	quest_marker_label.add_theme_color_override("font_color", Color("#e3b96bff"))
	quest_marker.add_theme_stylebox_override("panel", _quest_marker_style(Color("#755020ff")))


func _should_show_lesson_marker() -> bool:
	var quest: Dictionary = StoryService.get_quest(QUEST_ID)
	var quest_status := str(quest.get("status", "")).strip_edges().to_lower()
	if quest_status == "active":
		return true
	return quest_status == "available" and _is_lesson_offer_unlocked()


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(
		metadata.get("questRewardReceivedDialogueId", "")
	).strip_edges()
	quest_reward_completed_dialogue_id = str(
		metadata.get("questRewardCompletedDialogueId", "")
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
		push_warning("KarateMasterKenji: reward succeeded but story refresh failed locally.")
	await RockSmashService.load_state()
	await show_dialogue(await NpcDialogueService.resolve_lines(
		quest_reward_received_dialogue_id,
		["You completed your first Rock Smash lesson!"],
		"KarateMasterKenji"
	))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.learn_rock_smash.title"),
			"reward": LocalizationManager.text("ui.quest.rock_smash_lesson_reward"),
		})
	)
	if bool(result.get("claimed", false)):
		SfxManager.play("item_received")


func _show_completed_help() -> void:
	var greeting: Array[String] = [LocalizationManager.text("mentor.karate_master.help.greeting")]
	if not quest_reward_completed_dialogue_id.is_empty():
		greeting = await _resolve_dialogue_lines(quest_reward_completed_dialogue_id, greeting)
	await show_dialogue(greeting, display_name)
	while true:
		var topic_id := await _choose_help_topic([
			{"id": "basics", "label": LocalizationManager.text("mentor.karate_master.help.topic.basics")},
			{"id": "daily", "label": LocalizationManager.text("mentor.karate_master.help.topic.daily")},
			{"id": "treasure", "label": LocalizationManager.text("mentor.karate_master.help.topic.treasure")},
			{"id": "fossils", "label": LocalizationManager.text("mentor.karate_master.help.topic.fossils")},
		])
		if topic_id.is_empty():
			return
		await show_dialogue(_help_lines(topic_id), display_name)


func _choose_help_topic(topics: Array[Dictionary]) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		LocalizationManager.text("mentor.karate_master.help.title"),
		LocalizationManager.text("mentor.karate_master.help.prompt"),
		topics,
		LocalizationManager.text("ui.mentor_help.eyebrow"),
		LocalizationManager.text("common.close")
	)
	menu.queue_free()
	return topic_id


func _help_lines(topic_id: String) -> Array[String]:
	return [
		LocalizationManager.text("mentor.karate_master.help.%s.1" % topic_id),
		LocalizationManager.text("mentor.karate_master.help.%s.2" % topic_id),
	]
