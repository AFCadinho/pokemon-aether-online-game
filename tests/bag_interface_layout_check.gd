extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const BAG_SIZE := Vector2(1120, 660)"), "Bag has room for navigation, inventory and item details")
	_check(source.contains("const UI_WINDOW_Z_INDEX := UI_CHAT_TABS_Z_INDEX + 1") and source.contains("const UI_BAG_Z_INDEX := UI_WINDOW_Z_INDEX"), "Bag shares the window layer above chat tabs")
	_check(source.contains("panel.z_index = UI_WINDOW_Z_INDEX"), "Refocusing the Bag preserves its window priority")
	_check(source.contains("var bag_shell_style := _make_glass_panel_style(14)"), "Bag uses the shared modern glass shell")
	_check(source.contains('"id": "all", "labelKey": "ui.bag.category.all"'), "Bag starts with a localized complete inventory category")
	_check(source.contains('category_panel.custom_minimum_size = Vector2(178, 0)'), "Bag categories use a compact left sidebar")
	_check(source.contains('_set_localized_control_property(bag_search_input, "placeholder_text", "ui.bag.search")'), "Bag keeps localized item search prominent")
	_check(source.contains("bag_item_grid.columns = 5"), "Bag uses a readable five-column item grid")
	_check(source.contains("slot.custom_minimum_size = Vector2(106, 118)"), "Bag item cards leave room for icons and names")
	_check(source.contains("quantity_label.text = _bag_item_quantity_marker(item)"), "Bag routes quantity badges through assignment-aware markers")
	_check(source.contains('return "∞"') and source.contains('== "account_entitlement"'), "Bag shows account entitlements as infinitely assignable")
	_check(source.contains('_bag_item_quantity_marker(item)]') and source.contains('assign_entitlement_tooltip'), "Held-item picker explains and marks reusable entitlements")
	_check(source.contains("func _setup_bag_detail_panel") and source.contains('_set_localized_control_property(caption, "text", "ui.bag.selected_item")'), "Bag includes a localized selected-item detail panel")
	_check(source.contains("func _select_bag_item") and source.contains("_refresh_bag_detail()"), "Bag selection updates item details")
	_check(source.contains("await _on_bag_item_selected(bag_selected_item.duplicate(true))"), "Detail panel retains the existing item-use flow")
	_check(source.contains("await _assign_bag_item_to_hotbar(bag_selected_item.duplicate(true))"), "Detail panel can assign compatible items to the hotbar")
	_check(source.contains("MOUSE_BUTTON_RIGHT") and source.contains("_assign_bag_item_to_hotbar(item)"), "Right-click hotbar assignment remains available")
	_check(source.contains('"shortDesc": str(item.get("shortDesc", item.get("description", ""))).strip_edges()'), "Inventory normalization preserves item descriptions")
	_check(source.contains('LocalizationManager.text("ui.bag.no_search_matches")') and source.contains('LocalizationManager.text("ui.bag.no_items_in_category"'), "Bag has localized search and category empty states")
	_check(source.contains('active_bag_category == "all" and item_category == "key_items"'), "All Items hides key items")
	_check(source.contains('category_id == "all" and item_category != "key_items"'), "All Items count excludes key items")
	_check(not source.contains('{"id": "currency", "labelKey": "ui.bag.category.currency"'), "Bag omits the redundant Currency tab")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
