extends "res://scripts/services/inventory_service.gd"

var use_calls := 0

func use_inventory_item(item_id: String) -> Dictionary:
	use_calls += 1
	await get_tree().process_frame
	var game: Node = get_node("/root/PlayerGameStateService")
	var before: int = game.charge
	game.charge = mini(before + {"repel": 100, "super-repel": 200, "max-repel": 250}[item_id], 10000)
	return {"success": true, "repelSteps": game.charge, "addedRepelSteps": game.charge - before, "inventory": []}


func load_inventory() -> Dictionary:
	return {"success": true, "items": []}
