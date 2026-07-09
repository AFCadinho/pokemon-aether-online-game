extends DialogueNPC

class_name MarketAttendantNPC

@export var market_id := "standard"
@export var opening_dialogue_lines: Array[String] = [
	"Welcome! How may I help you?",
]
@export var loaded_dialogue_template := "I have %s items in stock."
@export var failure_dialogue_lines: Array[String] = [
	"I could not load the market right now.",
	"Please try again in a moment.",
]


func interact_with_player(_player: Node2D) -> void:
	if not opening_dialogue_lines.is_empty():
		await show_dialogue(opening_dialogue_lines)

	var market_service := get_node_or_null("/root/MarketService")
	if market_service == null or not market_service.has_method("load_standard_market"):
		await show_dialogue(failure_dialogue_lines)
		return

	var result: Dictionary = await market_service.call("load_standard_market")
	if not bool(result.get("success", false)):
		push_warning("MarketAttendantNPC: market load failed: %s" % str(result.get("error", "Unknown error")))
		await show_dialogue(failure_dialogue_lines)
		return

	var market: Dictionary = _dictionary_from_value(result.get("market", {}))
	var ui_overlay := get_tree().current_scene.get_node_or_null("UIOverlay") if get_tree().current_scene != null else null
	if ui_overlay != null and ui_overlay.has_method("open_market"):
		ui_overlay.call("open_market", market)
		return

	var items: Array = _array_from_value(market.get("items", []))
	await show_dialogue([loaded_dialogue_template % items.size()])


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	var metadata_market_id := str(metadata.get("marketId", metadata.get("market_id", ""))).strip_edges()
	if not metadata_market_id.is_empty():
		market_id = metadata_market_id

	var metadata_opening_dialogue := _get_string_array(metadata.get("openingDialogue", []))
	if not metadata_opening_dialogue.is_empty():
		opening_dialogue_lines = metadata_opening_dialogue

	var metadata_failure_dialogue := _get_string_array(metadata.get("failureDialogue", []))
	if not metadata_failure_dialogue.is_empty():
		failure_dialogue_lines = metadata_failure_dialogue


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
