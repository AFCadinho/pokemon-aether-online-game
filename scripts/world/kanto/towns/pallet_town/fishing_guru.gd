@tool
extends ItemGiftNPC

class_name FishingGuru

const QUEST_ID := "learn_to_fish"
const RECEIVE_ROD_STEP_ID := "receive_old_rod"
const RETURN_STEP_ID := "return_to_fishing_guru"
const OFFER_PREREQUISITE_QUEST_ID := "oaks_parcel"
const OFFER_PREREQUISITE_STEP_ID := "return_to_oak"
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


func _is_lesson_offer_unlocked() -> bool:
	return StoryService.is_requirement_met(
		OFFER_PREREQUISITE_QUEST_ID,
		OFFER_PREREQUISITE_STEP_ID,
		"completed"
	)


func _refresh_quest_marker() -> void:
	super._refresh_quest_marker()
	if quest_marker != null and quest_marker.visible:
		return
	if not _should_show_lesson_marker():
		return
	_setup_quest_marker()
	quest_marker.visible = true
	quest_marker_label.text = "✦"
	quest_marker_label.add_theme_color_override("font_color", Color("#75ddffff"))
	quest_marker.add_theme_stylebox_override("panel", _quest_marker_style(Color("#176b8fff")))


func _should_show_lesson_marker() -> bool:
	var story_service := get_node_or_null("/root/StoryService")
	if story_service == null:
		return false
	var quest: Dictionary = story_service.get_quest(QUEST_ID)
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


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array) -> Array[String]:
	var lines: Array[String] = await super._resolve_dialogue_lines(
		dialogue_reference_id,
		fallback_lines
	)
	return _format_fishing_instructions(lines)


func _format_fishing_instructions(lines: Array[String]) -> Array[String]:
	var formatted_lines: Array[String] = []
	var values := {"fishing_hotkey": SettingsManager.get_input_binding_label("fish")}
	for line: String in lines:
		formatted_lines.append(line.format(values))
	return formatted_lines


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
		InventoryService.notify_claimed_item_reward(result)
		SfxManager.play("item_received")


func _show_completed_help() -> void:
	var greeting: Array[String] = [LocalizationManager.text("mentor.fishing_guru.help.greeting")]
	if (
		not quest_reward_completed_dialogue_id.is_empty()
		and quest_reward_completed_dialogue_id != quest_reward_received_dialogue_id
	):
		greeting = await _resolve_dialogue_lines(quest_reward_completed_dialogue_id, greeting)
	await show_dialogue(greeting)
	while true:
		var topic_id := await _choose_help_topic([
			{"id": "starting", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.starting")},
			{"id": "catching", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.catching")},
			{"id": "progression", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.progression")},
			{"id": "treasure", "label": LocalizationManager.text("mentor.fishing_guru.help.topic.treasure")},
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
			keys = [
				"mentor.fishing_guru.help.starting.1",
				"mentor.fishing_guru.help.starting.2",
				"mentor.fishing_guru.help.starting.3",
				"mentor.fishing_guru.help.starting.4",
			]
		"catching":
			keys = ["mentor.fishing_guru.help.catching.1", "mentor.fishing_guru.help.catching.2"]
		"progression":
			keys = ["mentor.fishing_guru.help.progression.1", "mentor.fishing_guru.help.progression.2"]
		"treasure":
			keys = ["mentor.fishing_guru.help.treasure.1", "mentor.fishing_guru.help.treasure.2"]
	var lines: Array[String] = []
	var values := {"fishing_hotkey": SettingsManager.get_input_binding_label("fish")}
	for key: String in keys:
		lines.append(LocalizationManager.text(key, values))
	return lines
