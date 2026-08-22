extends SceneTree

const PLAYER_STATE_SERVICE_PATH := "res://scripts/services/player_game_state_service.gd"
const INVENTORY_SERVICE_PATH := "res://scripts/services/inventory_service.gd"
const OVERWORLD_ITEM_PATH := "res://scripts/world/interactables/overworld_item.gd"

var failed := false


func _init() -> void:
	var service_source := FileAccess.get_file_as_string(PLAYER_STATE_SERVICE_PATH)
	var checkpoint_block := _function_block(service_source, "func dev_set_story_checkpoint(checkpoint_id: String)")
	_check(
		checkpoint_block.contains("StoryService.apply_story(story)"),
		"developer checkpoint applies its authoritative story projection"
	)
	_check(
		checkpoint_block.contains("InventoryService.load_collected_world_pickups(true)"),
		"developer checkpoint bypasses the collected-world-pickup cache"
	)
	_check(
		checkpoint_block.contains("InventoryService.load_inventory()"),
		"developer checkpoint refreshes fossil inventory ownership"
	)
	_check(
		checkpoint_block.find("StoryService.apply_story(story)")
		< checkpoint_block.find("InventoryService.load_collected_world_pickups(true)"),
		"world pickup refresh follows the accepted checkpoint response"
	)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_PATH)
	var pickup_loader := _function_block(inventory_source, "func load_collected_world_pickups(force_refresh := false)")
	_check(
		pickup_loader.contains("if force_refresh:")
		and pickup_loader.contains("return await load_collected_world_pickups(true)"),
		"forced refresh retries after any older in-flight pickup request"
	)

	var item_source := FileAccess.get_file_as_string(OVERWORLD_ITEM_PATH)
	_check(
		item_source.contains("InventoryService.world_pickup_state_changed.connect(_on_world_pickup_state_changed)"),
		"overworld items listen for the refreshed pickup snapshot"
	)
	var pickup_callback := _function_block(item_source, "func _on_world_pickup_state_changed()")
	_check(
		pickup_callback.contains("set_claimed(InventoryService.is_world_pickup_collected(normalized_pickup_id))"),
		"a refreshed uncollected fossil makes its Poké Ball visible again"
	)

	quit(1 if failed else 0)


func _function_block(source: String, function_header: String) -> String:
	var start := source.find(function_header)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + function_header.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
