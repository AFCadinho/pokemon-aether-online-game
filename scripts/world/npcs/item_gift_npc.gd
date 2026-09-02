@tool
extends DialogueNPC

class_name ItemGiftNPC

@export var reward_id := ""
@export var success_dialogue_lines: Array[String] = [
	"Here, take this. It will help you fish in any body of water.",
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
@export var locked_dialogue_id := ""
@export var reward_item_id := ""
@export var locked_dialogue_lines: Array[String] = [
	"I do not have anything for you just yet.",
]

var reward_resolved := false


func _ready() -> void:
	super._ready()
	_refresh_reward_resolution.call_deferred()


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return
	if not is_story_requirement_met():
		await show_dialogue(await _resolve_dialogue_lines(locked_dialogue_id, locked_dialogue_lines))
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
		await GameErrorDialogService.show_response(
			result,
			"backend.error.reward_claim"
		)
		return

	if bool(result.get("claimed", false)):
		reward_resolved = true
		_refresh_quest_marker()
		await show_dialogue(await _resolve_dialogue_lines(success_dialogue_id, success_dialogue_lines))
		var inventory_item_id := str(result.get("itemId", "")).strip_edges().to_lower()
		var inventory_quantity := maxi(int(result.get("quantity", 1)), 1)
		if inventory_item_id != "":
			inventory_service.item_received.emit(inventory_item_id, inventory_quantity)
		if inventory_item_id != "" and inventory_item_id not in ["town-map", "old-rod"]:
			get_tree().call_group(
				"ui_overlay",
				"add_system_message",
				LocalizationManager.text("ui.world.reward.story_item", {
					"item": ItemLocalization.display_name(inventory_item_id),
					"quantity": inventory_quantity,
				})
			)
		if str(result.get("itemId", "")).strip_edges().to_lower() == "town-map":
			get_tree().call_group(
				"ui_overlay",
				"add_system_message",
				LocalizationManager.text("ui.key_item.received_town_map")
			)
		elif str(result.get("itemId", "")).strip_edges().to_lower() == "old-rod":
			get_tree().call_group(
				"ui_overlay",
				"add_system_message",
				LocalizationManager.text("ui.skill.fishing.unlocked")
			)
		SfxManager.play("item_received")
	else:
		reward_resolved = true
		_refresh_quest_marker()
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
	locked_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"lockedDialogueId",
		"locked_dialogue_id",
		locked_dialogue_id
	)
	var metadata_reward_item_id := str(
		metadata.get("rewardItemId", metadata.get("reward_item_id", ""))
	).strip_edges().to_lower()
	if not metadata_reward_item_id.is_empty():
		reward_item_id = metadata_reward_item_id


func _refresh_reward_resolution() -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)) or reward_item_id.is_empty():
		return
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null or not inventory_service.has_method("load_inventory"):
		return
	var result: Dictionary = await inventory_service.call("load_inventory")
	if not bool(result.get("success", false)):
		return
	for value: Variant in result.get("items", []):
		if not value is Dictionary:
			continue
		var item := value as Dictionary
		if (
			str(item.get("itemId", item.get("item_id", ""))).strip_edges().to_lower() == reward_item_id
			and int(item.get("quantity", 0)) > 0
		):
			reward_resolved = true
			break
	_refresh_quest_marker()


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


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		dialogue_reference_id,
		fallback_lines,
		"ItemGiftNPC"
	)


func _show_report_to_staff_message() -> void:
	var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
	if error_dialog_service != null and error_dialog_service.has_method("show_report_to_staff_message"):
		await error_dialog_service.call("show_report_to_staff_message")
		return
	await show_dialogue(failure_dialogue_lines)
