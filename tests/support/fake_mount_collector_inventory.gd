extends "res://scripts/services/inventory_service.gd"

var collector_offer: Dictionary = {}
var traded_items: Array[String] = []
var catalog_requests := 0

func load_mount_collector() -> Dictionary:
	catalog_requests += 1
	await get_tree().process_frame
	return {"success": true, "catalog": {"voucherCredit": 100, "offers": [collector_offer] if traded_items.is_empty() else []}}

func exchange_shiny_mount(item_id: String) -> Dictionary:
	traded_items.append(item_id)
	await get_tree().process_frame
	return {"success": true, "exchange": {"rewardItemId": collector_offer["rewardItemId"], "voucherCredit": 100}}
