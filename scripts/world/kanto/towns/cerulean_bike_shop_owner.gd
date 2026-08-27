@tool
extends DialogueNPC

class_name CeruleanBikeShopOwner

@export var voucher_item_id := "bike-voucher"
@export var voucher_turn_in_id := "kanto_cerulean_city_bike_voucher"
@export var mount_item_id := "cyclizar-mount"
@export var mount_id := "cyclizar"
@export var voucher_dialogue_id := ""
@export var mount_received_dialogue_id := ""
@export var mount_owned_dialogue_id := ""
@export var failure_dialogue_id := ""

const VOUCHER_FALLBACK_LINES: Array[String] = [
	"Oh, you have a Bike Voucher...? Let me see that.",
	"These vouchers were valid for life. A promise is a promise.",
	"I still cannot offer you a bicycle, but I may have something else for you.",
]
const RECEIVED_FALLBACK_LINES: Array[String] = [
	"This is Cyclizar. He has been looking for a Trainer to travel with.",
	"You can now select Cyclizar as your land mount.",
]
const OWNED_FALLBACK_LINES: Array[String] = [
	"Take good care of Cyclizar. He will take good care of you on the road.",
]
const FAILURE_FALLBACK_LINES: Array[String] = [
	"I cannot complete the exchange right now. Please come back in a moment.",
]


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message(_get_dialogue_box())
		return

	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null or not inventory_service.has_method("load_inventory"):
		await _show_exchange_failure()
		return
	var inventory_result: Dictionary = await inventory_service.call("load_inventory")
	if not bool(inventory_result.get("success", false)):
		await GameErrorDialogService.show_response(
			inventory_result,
			"backend.error.inventory_load"
		)
		return

	if bool(inventory_service.call("has_item", mount_item_id)):
		await show_dialogue(await _resolve_lines(mount_owned_dialogue_id, OWNED_FALLBACK_LINES))
		return
	if not bool(inventory_service.call("has_item", voucher_item_id)):
		await show_dialogue()
		return

	await show_dialogue(await _resolve_lines(voucher_dialogue_id, VOUCHER_FALLBACK_LINES))
	if not inventory_service.has_method("turn_in_npc_quest_item"):
		await _show_exchange_failure()
		return
	var turn_in_result: Dictionary = await inventory_service.call(
		"turn_in_npc_quest_item",
		voucher_turn_in_id
	)
	if not bool(turn_in_result.get("success", false)):
		await GameErrorDialogService.show_response(
			turn_in_result,
			"backend.error.reward_claim"
		)
		return

	var received_mount_id := str(turn_in_result.get("rewardItemId", "")).strip_edges().to_lower()
	if received_mount_id != mount_item_id:
		await _show_exchange_failure()
		return
	SettingsManager.set_selected_mount_id(SettingsManager.MOUNT_MODE_LAND, mount_id)
	if bool(turn_in_result.get("turnedIn", false)):
		await show_dialogue(await _resolve_lines(
			mount_received_dialogue_id,
			RECEIVED_FALLBACK_LINES
		))
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.mounts.cyclizar_received")
		)
		SfxManager.play("item_received")
		return
	await show_dialogue(await _resolve_lines(mount_owned_dialogue_id, OWNED_FALLBACK_LINES))


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	voucher_item_id = _metadata_value(metadata, "voucherItemId", voucher_item_id)
	voucher_turn_in_id = _metadata_value(metadata, "voucherTurnInId", voucher_turn_in_id)
	mount_item_id = _metadata_value(metadata, "mountItemId", mount_item_id)
	mount_id = _metadata_value(metadata, "mountId", mount_id)
	voucher_dialogue_id = _metadata_value(metadata, "voucherDialogueId", voucher_dialogue_id)
	mount_received_dialogue_id = _metadata_value(
		metadata,
		"mountReceivedDialogueId",
		mount_received_dialogue_id
	)
	mount_owned_dialogue_id = _metadata_value(
		metadata,
		"mountOwnedDialogueId",
		mount_owned_dialogue_id
	)
	failure_dialogue_id = _metadata_value(metadata, "failureDialogueId", failure_dialogue_id)


func _metadata_value(metadata: Dictionary, key: String, fallback: String) -> String:
	var value := str(metadata.get(key, "")).strip_edges()
	return value if not value.is_empty() else fallback


func _resolve_lines(dialogue_id: String, fallback_lines: Array[String]) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		dialogue_id,
		fallback_lines,
		"CeruleanBikeShopOwner"
	)


func _show_exchange_failure() -> void:
	await show_dialogue(await _resolve_lines(failure_dialogue_id, FAILURE_FALLBACK_LINES))
