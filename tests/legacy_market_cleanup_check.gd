extends SceneTree

var failures := 0


func _init() -> void:
	var ui := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var selected_start := ui.find("func _on_bag_item_selected")
	var selected_end := ui.find("func _show_bag_item_use_popup", selected_start)
	var selected_source := ui.substr(selected_start, selected_end - selected_start)
	var normalize_start := ui.find("func _normalize_bag_inventory_items")
	var normalize_end := ui.find("func ", normalize_start + 5)
	var normalize_source := ui.substr(normalize_start, normalize_end - normalize_start)

	_check(ui.contains('item.get("useNotice", {})'), "Bag reads generic use notice")
	_check(ui.contains('LocalizationManager.text("ui.bag.message.informational"'), "localized generic informational message")
	_check(normalize_source.contains('"useNotice": use_notice'), "legacy notice survives inventory normalization")
	_check(not selected_source.contains("PlayerActionService"), "inventory does not execute Player Actions")
	_check(not selected_source.contains("repel_enabled"), "inventory Repels do not toggle free Repel")
	_check(ui.contains("BAG_ITEM_EFFECT_PREVIEW.supports"), "medicine target selection remains effect-driven")
	_check(ui.contains("func _is_pokemon_usable_item_id"), "unsupported target filtering remains centralized")
	_check(ui.contains("InventoryService.use_pokemon_item"), "supported Bag use remains server-authoritative")
	_check(ui.contains("MarketService.purchase_item"), "named market purchases remain server-backed")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
