extends SceneTree

const TRACKER_SCENE := preload("res://scenes/interface/shiny_tracker_popup.tscn")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("LocalizationManager").set_locale("en")
	var inventory_service := root.get_node("InventoryService")
	var original_script: Script = inventory_service.get_script()
	inventory_service.set_script(load("res://tests/support/fake_mount_box_inventory_service.gd"))
	var popup := TRACKER_SCENE.instantiate()
	root.add_child(popup)
	await process_frame
	popup.visible = false
	var overlay = load("res://tests/support/mount_box_test_overlay.gd").new()
	var box := {"id": "glaceon-mount-box", "name": "Glaceon Mount Box", "useAction": "open_mount_box"}
	inventory_service.response = {
		"success": true,
		"inventory": [{"itemId": "glaceon-mount", "quantity": 1}],
		"mountBox": {
			"opening": {"mountId": "glaceon", "rewardItemId": "glaceon-mount", "shinyChancePercent": 50, "alreadyOwned": false},
			"tracker": {"activeBoxItemId": "glaceon-mount-box", "boxes": [{"itemId": "glaceon-mount-box", "quantity": 0}], "recentOpenings": []},
		},
	}
	for active_id: Variant in [null, "rayquaza-mount-box"]:
		popup.tracker_state = {"mounts": {"activeBoxItemId": active_id}}
		overlay.bag_selected_item = box.duplicate()
		await overlay._on_bag_item_selected(box)
		_check(inventory_service.used_items[-1] == "glaceon-mount-box", "Bag directly uses selected box regardless of previous opening: " + str(active_id))
		_check(overlay.tracker_opens == 0 and not popup.visible and not popup.mount_confirmation.visible, "Direct opening shows no other interface")
		_check(overlay.bag_selected_item.is_empty() and overlay.bag_inventory_items.size() == 2 and overlay.bag_inventory_items[0]["id"] == "glaceon-mount" and overlay.bag_inventory_items[1]["id"] == "escape-rope-action", "Bag refreshes consumed box and granted mount while retaining permanent actions")
		_check(overlay.messages[-1].contains("Glaceon") and overlay.messages[-1].contains("50%"), "Chat reports server reward and used chance")
		_check(popup.tracker_state["mounts"]["activeBoxItemId"] == "glaceon-mount-box" and popup.mount_open_buttons.size() == 1, "Existing signal updates last opened box in tracker")

	box["id"] = "glaceon-mount-box-bound"
	inventory_service.response["mountBox"]["opening"]["rewardItemId"] = "glaceon-mount-bound"
	await overlay._on_bag_item_selected(box)
	_check(inventory_service.used_items[-1] == "glaceon-mount-box-bound" and overlay.tracker_opens == 0, "Bag opens voucher box directly using its bound ID")
	_check(overlay.messages[-1].contains("Glaceon"), "Bound rewards keep their localized mount name")
	var service_source := FileAccess.get_file_as_string("res://scripts/services/inventory_service.gd")
	_check(service_source.contains('normalized_item_id.trim_suffix("-bound").ends_with("-mount-box")'), "Voucher box requests retain mount opening idempotency keys")
	inventory_service.response["mountBox"]["opening"]["alreadyOwned"] = true
	await overlay._on_bag_item_selected(box)
	_check(overlay.messages[-1].contains("duplicate"), "Duplicate reward is disclosed in chat")
	inventory_service.response["mountBox"]["opening"]["alreadyOwned"] = false
	inventory_service.response["mountBox"]["opening"]["rewardItemId"] = "shiny-glaceon-mount"
	inventory_service.response["mountBox"]["opening"]["mountId"] = "glaceon_shiny"
	inventory_service.response["mountBox"]["opening"]["shinyChancePercent"] = 80
	await overlay._on_bag_item_selected(box)
	_check(overlay.messages[-1].contains("Shiny") and overlay.messages[-1].contains("80%"), "Shiny reward and actual chance are reported")

	var requests_before: int = inventory_service.used_items.size()
	overlay._on_bag_item_selected(box)
	_check(overlay.bag_mount_box_busy, "Opening locks while inventory request is pending")
	overlay._on_bag_item_selected(box)
	await process_frame
	await process_frame
	_check(inventory_service.used_items.size() == requests_before + 1 and not overlay.bag_mount_box_busy, "Repeated clicks consume only one box and release lock")

	inventory_service.response = {"success": false, "error": "Opening rejected"}
	overlay.bag_selected_item = box.duplicate()
	var inventory_before: Array = overlay.bag_inventory_items.duplicate(true)
	await overlay._on_bag_item_selected(box)
	_check(overlay.messages[-1] == "Opening rejected" and not overlay.bag_mount_box_busy, "Failed request reports error and allows retry")
	_check(overlay.bag_selected_item == box and overlay.bag_inventory_items == inventory_before, "Rejected opening preserves Bag state")
	_check(overlay.tracker_opens == 0, "Errors also keep tracker closed")
	# These loaders receive a parent only when the full overlay enters the tree.
	overlay.pokemon_summary_sprite_loader.free()
	overlay.pokedex_sprite_loader.free()
	overlay.free()
	popup.queue_free()
	await process_frame
	inventory_service.set_script(original_script)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
