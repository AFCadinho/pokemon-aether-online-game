extends "res://scripts/services/inventory_service.gd"

var use_calls := 0
var last_quantity := 0

func use_inventory_item(item_id: String, quantity: int = 1) -> Dictionary:
	use_calls += 1
	last_quantity = quantity
	await get_tree().process_frame
	var game: Node = get_node("/root/PlayerGameStateService")
	var before: int = game.charge
	game.charge = mini(before + {"repel": 100, "super-repel": 200, "max-repel": 250}[item_id] * quantity, 10000)
	return {"success": true, "repelSteps": game.charge, "addedRepelSteps": game.charge - before, "inventory": []}


func load_inventory() -> Dictionary:
	return {"success": true, "items": []}
