@tool
extends DialogueNPC

class_name MarketAttendantNPC

const MARKET_MODE_PLAYER_BUYS := "player_buys"
const MARKET_MODE_PLAYER_SELLS := "player_sells"

@export var market_id := "standard"
@export_enum("player_buys", "player_sells") var market_mode := MARKET_MODE_PLAYER_BUYS
@export var opening_dialogue_lines: Array[String] = [
	"Welcome! How may I help you?",
]
@export var loaded_dialogue_template := "I have %s items in stock."
@export var failure_dialogue_lines: Array[String] = [
	"I could not load the market right now.",
	"Please try again in a moment.",
]
@export var opening_dialogue_id := ""
@export var failure_dialogue_id := ""


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	await show_dialogue(await _resolve_dialogue_lines(opening_dialogue_id, opening_dialogue_lines))

	var market_service := get_node_or_null("/root/MarketService")
	if market_service == null or not market_service.has_method("load_market"):
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	var result: Dictionary = await market_service.call("load_market", market_id)
	if not bool(result.get("success", false)):
		push_warning("MarketAttendantNPC: market load failed: %s" % str(result.get("error", "Unknown error")))
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	var market: Dictionary = _dictionary_from_value(result.get("market", {}))
	var inventory_items: Array = []
	if market_mode == MARKET_MODE_PLAYER_SELLS:
		var inventory_service := get_node_or_null("/root/InventoryService")
		if inventory_service == null or not inventory_service.has_method("load_inventory"):
			await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
			return
		var inventory_result: Dictionary = await inventory_service.call("load_inventory")
		if not bool(inventory_result.get("success", false)):
			await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
			return
		inventory_items = _array_from_value(inventory_result.get("items", []))

	var ui_overlay := get_tree().current_scene.get_node_or_null("UIOverlay") if get_tree().current_scene != null else null
	if ui_overlay != null and ui_overlay.has_method("open_market"):
		ui_overlay.call("open_market", market, market_mode, inventory_items)
		return

	var items: Array = _array_from_value(market.get("items", []))
	await show_dialogue([loaded_dialogue_template % items.size()])


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	var metadata_market_id := str(metadata.get("marketId", metadata.get("market_id", ""))).strip_edges()
	if not metadata_market_id.is_empty():
		market_id = metadata_market_id
	var metadata_market_mode := str(metadata.get("marketMode", metadata.get("market_mode", ""))).strip_edges()
	if metadata_market_mode in [MARKET_MODE_PLAYER_BUYS, MARKET_MODE_PLAYER_SELLS]:
		market_mode = metadata_market_mode

	var metadata_opening_dialogue := _get_string_array(metadata.get("openingDialogue", []))
	if not metadata_opening_dialogue.is_empty():
		opening_dialogue_lines = metadata_opening_dialogue
	opening_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"openingDialogueId",
		"opening_dialogue_id",
		opening_dialogue_id
	)

	var metadata_failure_dialogue := _get_string_array(metadata.get("failureDialogue", []))
	if not metadata_failure_dialogue.is_empty():
		failure_dialogue_lines = metadata_failure_dialogue
	failure_dialogue_id = _get_metadata_dialogue_id(
		metadata,
		"failureDialogueId",
		"failure_dialogue_id",
		failure_dialogue_id
	)


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
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
		push_warning("MarketAttendantNPC: Dialogue metadata was empty for %s; falling back to inline dialogue." % resolved_dialogue_id)
		return fallback_lines
	return lines


func _show_report_to_staff_message() -> void:
	var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
	if error_dialog_service != null and error_dialog_service.has_method("show_report_to_staff_message"):
		await error_dialog_service.call("show_report_to_staff_message")
		return
	await show_dialogue(failure_dialogue_lines)


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array
