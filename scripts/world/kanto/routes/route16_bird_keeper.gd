@tool
extends "res://scripts/world/npcs/dialogue_npc.gd"

const QUEST_ID := "route16_bird_research"
const TURN_IN_STEP := "return_to_bird_keeper"

var quest_reward_id := ""
var received_dialogue_id := ""

func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	received_dialogue_id = str(metadata.get("questRewardReceivedDialogueId", "")).strip_edges()

func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	if not StoryService.is_requirement_met(QUEST_ID, TURN_IN_STEP, "active"):
		await show_dialogue()
		return
	if quest_reward_id.is_empty():
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var result: Dictionary = await InventoryService.claim_npc_item_reward(quest_reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("Route16BirdKeeper: reward granted; story refresh needs retry.")
	await show_dialogue(await NpcDialogueService.resolve_lines(received_dialogue_id, [], "Route16BirdKeeper"))
	if bool(result.get("claimed", false)):
		InventoryService.notify_claimed_item_reward(result)
		SfxManager.play("item_received")
