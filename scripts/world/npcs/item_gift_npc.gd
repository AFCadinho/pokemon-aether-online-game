extends DialogueNPC

class_name ItemGiftNPC

@export var reward_id := ""
@export var success_dialogue_lines: Array[String] = [
	"Here, take this. It will help you fish in any body of water.",
	"You received an Old Rod!",
]
@export var already_received_dialogue_lines: Array[String] = [
	"That Old Rod should be enough to get you started.",
]
@export var failure_dialogue_lines: Array[String] = [
	"I cannot give you this item right now.",
	"Please try again in a moment.",
]
@export var success_dialogue_id := ""
@export var already_received_dialogue_id := ""
@export var failure_dialogue_id := ""


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	if reward_id.strip_edges().is_empty():
		push_warning("ItemGiftNPC: reward id is missing for %s." % _get_npc_metadata_id())
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null or not inventory_service.has_method("claim_npc_item_reward"):
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	var result: Dictionary = await inventory_service.call("claim_npc_item_reward", reward_id)
	if not bool(result.get("success", false)):
		push_warning("ItemGiftNPC: reward claim failed: %s" % str(result.get("error", "Unknown error")))
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	if bool(result.get("claimed", false)):
		await show_dialogue(await _resolve_dialogue_lines(success_dialogue_id, success_dialogue_lines))
	else:
		await show_dialogue(await _resolve_dialogue_lines(
			already_received_dialogue_id,
			already_received_dialogue_lines
		))


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	var metadata_reward_id := str(metadata.get("rewardId", metadata.get("reward_id", ""))).strip_edges()
	if not metadata_reward_id.is_empty():
		reward_id = metadata_reward_id
	success_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"successDialogueId",
		"success_dialogue_id",
		success_dialogue_id
	)
	already_received_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"alreadyReceivedDialogueId",
		"already_received_dialogue_id",
		already_received_dialogue_id
	)
	failure_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"failureDialogueId",
		"failure_dialogue_id",
		failure_dialogue_id
	)


func _get_metadata_dialogue_id(
	metadata: Dictionary,
	camel_key: String,
	snake_key: String,
	current_value: String
) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:
	var resolved_dialogue_id := dialogue_reference_id.strip_edges()
	if resolved_dialogue_id.is_empty():
		return fallback_lines

	var lines: Array[String] = await DialogueMetadataService.get_lines(resolved_dialogue_id)
	if lines.is_empty():
		push_warning("ItemGiftNPC: Dialogue metadata was empty for %s; falling back to inline dialogue." % resolved_dialogue_id)
		return fallback_lines
	return lines


func _show_report_to_staff_message() -> void:
	var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
	if error_dialog_service != null and error_dialog_service.has_method("show_report_to_staff_message"):
		await error_dialog_service.call("show_report_to_staff_message")
		return
	await show_dialogue(failure_dialogue_lines)
