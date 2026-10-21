@tool
extends "res://scripts/world/npcs/dialogue_npc.gd"


func interact_with_player(player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	if not StoryService.is_requirement_met("fuchsia_gold_teeth", "return_gold_teeth", "active"):
		await super.interact_with_player(player)
		return
	var inventory_result: Dictionary = await InventoryService.load_inventory()
	if not bool(inventory_result.get("success", false)):
		await GameErrorDialogService.show_response(inventory_result, "backend.error.reward_claim")
		return
	if not InventoryService.has_item("gold-teeth"):
		await show_dialogue()
		return
	var result: Dictionary = await InventoryService.turn_in_npc_quest_item("kanto_fuchsia_gold_teeth")
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	var lines: Array[String] = await NpcDialogueService.resolve_lines(
		"fuchsia_warden_received", [], "FuchsiaWarden"
	)
	await show_dialogue(lines)
	if bool(result.get("turnedIn", false)):
		InventoryService.notify_story_reward_effects(result.get("storyEffects", []))
		SfxManager.play("item_received")
	_refresh_quest_marker()
