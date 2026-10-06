extends "res://scripts/services/inventory_service.gd"

var used_items: Array[String] = []
var response: Dictionary = {}

func use_inventory_item(item_id: String, _quantity: int = 1) -> Dictionary:
	used_items.append(item_id)
	await get_tree().process_frame
	if bool(response.get("success", false)):
		mount_box_opened.emit(response["mountBox"])
	return response.duplicate(true)
