extends SceneTree

var failed := false


func _init() -> void:
	var item_scene_source := FileAccess.get_file_as_string(
		"res://scenes/world/interactables/overworld_item.tscn"
	)
	var item_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/overworld_item.gd"
	)
	var boulder_scene_source := FileAccess.get_file_as_string(
		"res://scenes/world/interactables/strength_boulder.tscn"
	)
	var boulder_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/strength_boulder.gd"
	)
	var inventory_source := FileAccess.get_file_as_string(
		"res://scripts/services/inventory_service.gd"
	)

	_check(ResourceLoader.exists("res://scenes/world/interactables/overworld_item.tscn"), "overworld item scene exists")
	_check(item_scene_source.contains("Object ball.png"), "overworld item uses the reusable Poké Ball asset")
	_check(item_script_source.contains("@export var pickup_id"), "overworld items expose a persistent pickup id")
	_check(item_script_source.contains("claim_world_pickup(pickup_id)"), "overworld item claims through the inventory service")
	_check(item_script_source.contains("set_claimed(true)"), "collected overworld items are hidden")
	_check(item_script_source.contains("world_pickup_state_changed.connect"), "exclusive pickup choices hide their counterpart immediately")
	_check(inventory_source.contains('const WORLD_PICKUPS_ENDPOINT := "/game/world-pickups"'), "inventory service loads collected pickups")
	_check(inventory_source.contains("func claim_world_pickup"), "inventory service exposes world pickup claims")
	_check(inventory_source.contains('body.get("collectedPickupIds"'), "inventory service applies every collected id from exclusive choices")

	_check(ResourceLoader.exists("res://scenes/world/interactables/strength_boulder.tscn"), "Strength boulder scene exists")
	_check(boulder_scene_source.contains("Object boulder.png"), "Strength boulder uses the official boulder sheet")
	_check(boulder_scene_source.contains('"name": &"push"'), "Strength boulder has a push animation")
	_check(boulder_script_source.contains('can_use_field_move("strength")'), "Strength boulder validates the field move")
	_check(boulder_script_source.contains('player.call("can_move_to", destination)'), "Strength boulder validates its destination")
	_check(boulder_script_source.contains('push_direction * TILE_SIZE'), "Strength boulder moves exactly one tile")

	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
