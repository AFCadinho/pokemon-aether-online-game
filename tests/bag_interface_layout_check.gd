extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const BAG_SIZE := Vector2(1120, 660)"), "Bag has room for navigation, inventory and item details")
	_check(source.contains("const UI_BAG_Z_INDEX := UI_CHAT_TABS_Z_INDEX + 1") and source.contains("bag_popup.z_index = UI_BAG_Z_INDEX"), "Bag always renders above chat tabs")
	_check(source.contains("panel.z_index = UI_BAG_Z_INDEX if panel == bag_popup else UI_ACTIVE_Z_INDEX"), "Refocusing the Bag preserves its chat-tab priority")
	_check(source.contains("var bag_shell_style := _make_glass_panel_style(14)"), "Bag uses the shared modern glass shell")
	_check(source.contains('"id": "all", "label": "All Items"'), "Bag starts with a complete inventory category")
	_check(source.contains('category_panel.custom_minimum_size = Vector2(178, 0)'), "Bag categories use a compact left sidebar")
	_check(source.contains('bag_search_input.placeholder_text = "Search items..."'), "Bag keeps item search prominent")
	_check(source.contains("bag_item_grid.columns = 5"), "Bag uses a readable five-column item grid")
	_check(source.contains("slot.custom_minimum_size = Vector2(106, 118)"), "Bag item cards leave room for icons and names")
	_check(source.contains('quantity_label.text = "KEY" if bool(item.get("permanent", false)) else "x%s"'), "Bag distinguishes permanent items from stack quantities")
	_check(source.contains("func _setup_bag_detail_panel") and source.contains('caption.text = "SELECTED ITEM"'), "Bag includes a dedicated selected-item detail panel")
	_check(source.contains("func _select_bag_item") and source.contains("_refresh_bag_detail()"), "Bag selection updates item details")
	_check(source.contains("await _on_bag_item_selected(bag_selected_item.duplicate(true))"), "Detail panel retains the existing item-use flow")
	_check(source.contains("await _assign_bag_item_to_hotbar(bag_selected_item.duplicate(true))"), "Detail panel can assign compatible items to the hotbar")
	_check(source.contains("MOUSE_BUTTON_RIGHT") and source.contains("_assign_bag_item_to_hotbar(item)"), "Right-click hotbar assignment remains available")
	_check(source.contains('"shortDesc": str(item.get("shortDesc", item.get("description", ""))).strip_edges()'), "Inventory normalization preserves item descriptions")
	_check(source.contains('"No items match your search."') and source.contains('"No items in %s."'), "Bag has clear search and category empty states")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
