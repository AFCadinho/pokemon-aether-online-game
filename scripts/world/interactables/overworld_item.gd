extends WorldInteractable

class_name OverworldItem

const MACHINE_BALL_TEXTURE := preload(
	"res://assets/npcs/gen4-ow-sprites/Object ball gold.png"
)

@export var pickup_id := ""
@export var item_id := ""
@export_range(1, 999, 1) var quantity := 1

@onready var item_sprite := $Sprite2D as Sprite2D

var claimed := false
var claim_in_flight := false


func _ready() -> void:
	interactable_kind = "overworld_item"
	display_name = LocalizationManager.text("ui.overworld_item.name")
	blocks_movement = true
	requires_facing = true
	_apply_item_visual()
	super._ready()
	if not InventoryService.world_pickup_state_changed.is_connected(_on_world_pickup_state_changed):
		InventoryService.world_pickup_state_changed.connect(_on_world_pickup_state_changed)
	_refresh_claimed_state.call_deferred()


func _apply_item_visual() -> void:
	if item_sprite == null or not _is_machine_item():
		return
	var machine_texture := AtlasTexture.new()
	machine_texture.atlas = MACHINE_BALL_TEXTURE
	machine_texture.region = Rect2(0, 0, 32, 32)
	item_sprite.texture = machine_texture


func _is_machine_item() -> bool:
	var normalized_item_id := item_id.strip_edges().to_lower()
	return normalized_item_id.begins_with("tm-") or normalized_item_id.begins_with("hm-")


func interact_with_player(_player: Node2D) -> void:
	if claimed or claim_in_flight:
		return
	if pickup_id.strip_edges() == "":
		_notify_pickup_warning(LocalizationManager.text("ui.overworld_item.unavailable"))
		return

	claim_in_flight = true
	var result: Dictionary = await InventoryService.claim_world_pickup(pickup_id)
	claim_in_flight = false
	if not bool(result.get("success", false)):
		_notify_pickup_warning(
			str(result.get("error", LocalizationManager.text("ui.overworld_item.unavailable")))
		)
		return

	set_claimed(true)
	if not bool(result.get("claimed", false)):
		return

	var granted_item_id := str(result.get("itemId", item_id)).strip_edges().to_lower()
	var granted_quantity := maxi(int(result.get("quantity", quantity)), 1)
	_notify_item_found(granted_item_id, granted_quantity)


func _notify_item_found(granted_item_id: String, granted_quantity: int) -> void:
	var item_name := ItemLocalization.display_name(granted_item_id, granted_item_id.capitalize())
	var message_key := "ui.overworld_item.found.one" if granted_quantity == 1 else "ui.overworld_item.found.many"
	var message := LocalizationManager.text(message_key, {
		"item": item_name,
		"quantity": granted_quantity,
	})
	SfxManager.play("item_found")
	_add_pickup_system_message(message)


func _add_pickup_system_message(message: String) -> void:
	get_tree().call_group("ui_overlay", "add_system_message", message)


func _notify_pickup_warning(message: String) -> void:
	get_tree().call_group("ui_overlay", "add_system_warning", message)


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


func _on_world_pickup_state_changed() -> void:
	var normalized_pickup_id := pickup_id.strip_edges().to_lower()
	if normalized_pickup_id != "":
		set_claimed(InventoryService.is_world_pickup_collected(normalized_pickup_id))
