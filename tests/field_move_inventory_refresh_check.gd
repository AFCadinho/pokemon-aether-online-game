extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory_service := root.get_node_or_null("InventoryService")
	var field_move_service := root.get_node_or_null("FieldMoveService")
	var player_save := root.get_node_or_null("PlayerSave")
	_check(inventory_service != null, "InventoryService autoload is available")
	_check(field_move_service != null, "FieldMoveService autoload is available")
	_check(player_save != null, "PlayerSave autoload is available")
	if inventory_service == null or field_move_service == null or player_save == null:
		quit(1)
		return

	var original_items: Array = inventory_service.get("cached_inventory_items").duplicate(true)
	var original_user_id: int = int(inventory_service.get("cached_inventory_user_id"))
	var original_loaded: bool = bool(inventory_service.get("inventory_loaded"))
	var original_charms: Dictionary = field_move_service.get("owned_charm_moves").duplicate(true)
	var original_hms: Dictionary = field_move_service.get("owned_hm_item_ids").duplicate(true)
	var original_badges: Array = player_save.get("earned_gym_badges").duplicate()

	player_save.get("earned_gym_badges").append("kanto:cascade")
	inventory_service.call("apply_inventory_items", [
		{"itemId": "hm-cut", "machineKind": "hm"},
		{"itemId": "cut-charm", "fieldMove": "cut", "name": "Cut Charm", "requiredHm": "hm-cut"},
	])
	var cut_result: Dictionary = field_move_service.call("can_use_field_move", "cut")
	_check(bool(cut_result.get("success", false)), "an inventory update immediately unlocks Cut")
	_check(str(cut_result.get("source", "")) == "charm", "the refreshed Cut Charm is used as Cut's source")

	inventory_service.set("cached_inventory_items", original_items)
	inventory_service.set("cached_inventory_user_id", original_user_id)
	inventory_service.set("inventory_loaded", original_loaded)
	field_move_service.set("owned_charm_moves", original_charms)
	field_move_service.set("owned_hm_item_ids", original_hms)
	player_save.get("earned_gym_badges").assign(original_badges)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failed = true
	push_error("FAIL: %s" % message)
