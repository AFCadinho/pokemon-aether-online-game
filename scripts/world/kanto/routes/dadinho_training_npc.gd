@tool
extends DialogueNPC

class_name DadinhoTrainingNPC

const TRAINING_QUEST_ID := "train_starter_to_level_10"
const TRAINING_TURN_IN_STEP_ID := "return_to_dadinho"

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return
	if _is_training_reward_available():
		await _claim_training_reward()
		return
	if _is_training_quest_completed():
		await show_dialogue(await _resolve_dialogue_lines(
			quest_reward_completed_dialogue_id,
			["That Exp. Share will help your whole team keep up."]
		))
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


func _is_training_reward_available() -> bool:
	return StoryService.is_requirement_met(
		TRAINING_QUEST_ID,
		TRAINING_TURN_IN_STEP_ID,
		"active"
	)


func _is_training_quest_completed() -> bool:
	return StoryService.is_requirement_met(TRAINING_QUEST_ID, "", "completed")


func _claim_training_reward() -> void:
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
		push_warning("DadinhoTrainingNPC: reward succeeded but story refresh failed locally.")
	await show_dialogue(await _resolve_dialogue_lines(
		quest_reward_received_dialogue_id,
		[
			"You made it to level 10! I knew you two would make a great team.",
			"Take this Exp. Share. It will help the rest of your team grow alongside you.",
		]
	))
	_notify_training_completed(str(result.get("itemId", "exp-share")))


func _notify_training_completed(item_id: String) -> void:
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.quest.completed_reward", {
			"quest": LocalizationManager.text("story.kanto.train_starter.title"),
			"reward": ItemLocalization.display_name(item_id, "Exp. Share"),
		})
	)


func _resolve_dialogue_lines(dialogue_id: String, fallback: Array[String]) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		dialogue_id,
		fallback,
		"DadinhoTrainingNPC"
	)


func _show_report_to_staff_message() -> void:
	var error_service := get_node_or_null("/root/GameErrorDialogService")
	if error_service != null and error_service.has_method("show_report_to_staff_message"):
		await error_service.call("show_report_to_staff_message")
		return
	await show_dialogue(["I cannot finish the training challenge right now."])
