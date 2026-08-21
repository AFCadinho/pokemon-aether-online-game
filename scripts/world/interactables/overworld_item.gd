extends WorldInteractable

class_name OverworldItem

@export var pickup_id := ""
@export var item_id := ""
@export_range(1, 999, 1) var quantity := 1

var claimed := false
var claim_in_flight := false


func _ready() -> void:
	interactable_kind = "overworld_item"
	display_name = LocalizationManager.text("ui.overworld_item.name")
	blocks_movement = true
	requires_facing = true
	super._ready()
	_refresh_claimed_state.call_deferred()


func interact_with_player(_player: Node2D) -> void:
	if claimed or claim_in_flight:
		return
	if pickup_id.strip_edges() == "":
		await show_dialogue(
			[LocalizationManager.text("ui.overworld_item.unavailable")],
			display_name
		)
		return

	claim_in_flight = true
	var result: Dictionary = await InventoryService.claim_world_pickup(pickup_id)
	claim_in_flight = false
	if not bool(result.get("success", false)):
		await show_dialogue(
			[str(result.get("error", LocalizationManager.text("ui.overworld_item.unavailable")))],
			display_name
		)
		return

	set_claimed(true)
	if not bool(result.get("claimed", false)):
		return

	var granted_item_id := str(result.get("itemId", item_id)).strip_edges().to_lower()
	var granted_quantity := maxi(int(result.get("quantity", quantity)), 1)
	var item_name := ItemLocalization.display_name(granted_item_id, granted_item_id.capitalize())
	var message_key := "ui.overworld_item.found.one" if granted_quantity == 1 else "ui.overworld_item.found.many"
	SfxManager.play("item_found")
	await show_dialogue(
		[
			LocalizationManager.text(message_key, {
				"item": item_name,
				"quantity": granted_quantity,
			})
		],
		display_name
	)


func set_claimed(value: bool) -> void:
	claimed = value
	visible = not value
	blocks_movement = not value
	set_process(not value)
	if interaction_area != null:
		interaction_area.monitoring = not value
		interaction_area.monitorable = not value


func _refresh_claimed_state() -> void:
	var normalized_pickup_id := pickup_id.strip_edges().to_lower()
	if normalized_pickup_id == "":
		push_warning("OverworldItem %s has no pickup_id." % name)
		return
	var result: Dictionary = await InventoryService.load_collected_world_pickups()
	if bool(result.get("success", false)) and InventoryService.is_world_pickup_collected(normalized_pickup_id):
		set_claimed(true)
