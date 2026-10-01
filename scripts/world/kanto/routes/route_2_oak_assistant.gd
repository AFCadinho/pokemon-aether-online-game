@tool
extends DialogueNPC

class_name Route2OakAssistant

const QUEST_ID := "route_2_oak_assistant_flash"
const QUEST_STEP_ID := "catch_ten_species"
const REWARD_ID := "kanto_route_2_oak_assistant_flash_hm"
const REQUIRED_CAUGHT_SPECIES := 10


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	await _get_dialogue_metadata_lines()
	var story_result: Dictionary = await PlayerGameStateService.refresh_story()
	if not bool(story_result.get("success", false)):
		push_warning("Route2OakAssistant: could not refresh story: %s" % str(story_result.get("error", "Unknown error")))
	var story_service := get_node_or_null("/root/StoryService")
	if story_service == null:
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var quest: Dictionary = story_service.call("get_quest", QUEST_ID)
	var quest_status := str(quest.get("status", "")).strip_edges().to_lower()
	if quest_status == "available":
		await show_dialogue()
		return
	if bool(story_service.call("is_requirement_met", QUEST_ID, QUEST_STEP_ID, "active")):
		var caught_count := await _load_caught_species_count()
		if caught_count < 0:
			await GameErrorDialogService.show_report_to_staff_message()
		elif caught_count >= REQUIRED_CAUGHT_SPECIES:
			await _claim_flash_reward()
		else:
			await show_dialogue([LocalizationManager.text(
				"story.kanto.route_2_oak_assistant.progress",
				{"caught": caught_count, "required": REQUIRED_CAUGHT_SPECIES}
			)])
		return
	if quest_status == "completed":
		await show_dialogue([LocalizationManager.text("story.kanto.route_2_oak_assistant.completed")])
		return
	await show_dialogue()


func _load_caught_species_count() -> int:
	var profile_result: Dictionary = await PlayerGameStateService.load_player_profile()
	if not bool(profile_result.get("success", false)):
		push_warning("Route2OakAssistant: could not load Pokédex progress: %s" % str(profile_result.get("error", "Unknown error")))
		return -1
	var pokedex: Dictionary = profile_result.get("pokedex", {})
	if not pokedex.has("caught"):
		return -1
	return int(pokedex.get("caught", 0))


func _claim_flash_reward() -> void:
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null or not inventory_service.has_method("claim_npc_item_reward"):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var result_value: Variant = await inventory_service.call("claim_npc_item_reward", REWARD_ID)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {}
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("Route2OakAssistant: reward succeeded but story refresh failed locally.")
	await show_dialogue([LocalizationManager.text("story.kanto.route_2_oak_assistant.reward")])
	if inventory_service.has_method("notify_claimed_item_reward"):
		inventory_service.call("notify_claimed_item_reward", result)
	var item_localization := get_node_or_null("/root/ItemLocalization")
	var reward_name := "HM Flash"
	if item_localization != null and item_localization.has_method("display_name"):
		reward_name = str(item_localization.call("display_name", "hm-flash", reward_name))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.route_2_oak_assistant.title"),
			"reward": reward_name,
		})
	)
	var sfx_manager := get_node_or_null("/root/SfxManager")
	if sfx_manager != null and sfx_manager.has_method("play"):
		sfx_manager.call("play", "item_received")
