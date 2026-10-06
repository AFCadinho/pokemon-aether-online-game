extends SceneTree

var failures := 0

class CollectorSyncWorld extends Node:
	signal continue_sync
	var hold_sync := true
	var sync_calls := 0
	var result := {"success": true}

	func sync_player_position_for_world_action() -> Dictionary:
		sync_calls += 1
		if hold_sync:
			await continue_sync
		return result

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("LocalizationManager").set_locale("en")
	var bike_scene := load("res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn") as PackedScene
	var bike := bike_scene.instantiate()
	var collector := bike.get_node("Entities/NPCs/ShinyMountCollector")
	_check(collector.position == Vector2(368, 464), "Collector is placed in Cerulean Bike Shop at its server position")
	_check(collector.npc_id == "kanto_cerulean_city_shiny_mount_collector", "Collector has a unique NPC metadata identity")
	_check(collector.mugshot != null and collector.mugshot.get_size() == Vector2(80, 80), "Collector uses its matching dialogue mugshot")
	_check(collector.portrait_id == "showdown_collector_gen6", "Collector portrait is registered with the portrait catalog")
	var frames: SpriteFrames = collector.call("_get_directional_sprite_frames", collector.npc_sprite_frames)
	for direction: String in ["down", "left", "right", "up"]:
		_check(frames.has_animation("walk_" + direction) and frames.get_frame_count("walk_" + direction) == 4, "Collector overworld sprite supports direction " + direction)
	var offer := {"itemId": "shiny-glaceon-mount-bound", "quantity": 2, "shinyMountId": "glaceon_shiny", "normalMountId": "glaceon", "rewardItemId": "glaceon-mount-bound", "accountBound": true, "normalAlreadyOwned": true}
	var confirmation_script := load("res://scripts/ui/mount_collector_confirmation.gd") as GDScript
	var confirmation = confirmation_script.new()
	root.add_child(confirmation)
	confirmation.call("_build_confirmation", offer, 100, false)
	for _frame: int in range(3):
		await process_frame
	_check(confirmation.find_child("ShinyPreview", true, false).texture != null and confirmation.find_child("NormalPreview", true, false).texture != null, "Confirmation shows the actual shiny input and normal reward images")
	_check(confirmation.find_child("VoucherCredit", true, false).text == "+100" and confirmation.find_child("RewardBinding", true, false).text == "Account-bound", "Confirmation separates voucher credit and normal mount binding")
	_check(confirmation.find_child("NormalAlreadyOwned", true, false) != null, "Already-owned normal mount is marked beside the reward")
	_check(confirmation.back_button.has_focus(), "Confirmation starts with Back focused")
	var cancelled: Array[String] = []
	confirmation.topic_selected.connect(func(choice: String) -> void: cancelled.append(choice))
	confirmation.back_button.pressed.emit()
	_check(cancelled == [""], "Back cancels without confirming an exchange")
	confirmation.queue_free()
	await process_frame
	var last_copy: Dictionary = offer.duplicate()
	last_copy["shinyOwnedQuantity"] = 1
	last_copy["accountBound"] = false
	last_copy["normalAlreadyOwned"] = false
	var last_dialog = confirmation_script.new()
	root.add_child(last_dialog)
	last_dialog.call("_build_confirmation", last_copy, 100, false)
	_check(last_dialog.find_child("LastShinyWarning", true, false) != null and last_dialog.find_child("RewardBinding", true, false).text == "Tradeable", "The last-shiny warning is highlighted separately for tradeable conversion")
	var confirmed: Array[String] = []
	last_dialog.topic_selected.connect(func(choice: String) -> void: confirmed.append(choice))
	last_dialog.confirm_button.pressed.emit()
	last_dialog.confirm_button.pressed.emit()
	_check(confirmed == ["confirm"], "Explicit exchange confirmation resolves only once")
	last_dialog.queue_free()
	await process_frame
	var confirmation_viewport := SubViewport.new()
	confirmation_viewport.size = Vector2i(480, 540)
	root.add_child(confirmation_viewport)
	var protected_dialog = confirmation_script.new()
	confirmation_viewport.add_child(protected_dialog)
	protected_dialog.call("_build_confirmation", offer, 100, true)
	for _frame: int in range(4):
		await process_frame
	_check(protected_dialog.find_child("ProtectedShinyNotice", true, false) != null and protected_dialog.find_child("LastShinyWarning", true, false) == null, "Duplicates-only shows keep-one protection instead of a last-copy warning")
	_check(protected_dialog.confirmation_panel.size.x <= 480 and protected_dialog.confirmation_panel.size.y <= 540 and protected_dialog.back_button.is_visible_in_tree(), "Preview and action buttons fit a narrow screen with scrollable details")
	confirmation_viewport.queue_free()
	await process_frame
	var menu_script := load("res://scripts/ui/mount_collector_grid.gd") as GDScript
	var menu = menu_script.new()
	root.add_child(menu)
	var tradeable: Dictionary = offer.duplicate()
	tradeable["itemId"] = "shiny-glaceon-mount"
	tradeable["quantity"] = 1
	tradeable["accountBound"] = false
	var single := {"itemId": "shiny-rayquaza-mount", "shinyMountId": "rayquaza_shiny", "quantity": 1, "accountBound": false}
	var surf := {"itemId": "shiny-primal-kyogre-mount-bound", "shinyMountId": "primal_kyogre_shiny", "quantity": 3, "accountBound": true}
	var state: Dictionary = {}
	menu.call("_build_grid", [offer, tradeable, single, surf], 0, 100, state)
	await process_frame
	var grid := menu.find_child("MountCards", true, false) as GridContainer
	_check(grid.columns == 4 and grid.get_child_count() == 4, "Compact cards fill a four-column collection browser")
	var card: Button
	for child: Button in grid.get_children():
		if child.get_meta("item_id") == offer["itemId"]:
			card = child
	_check(card != null and card.tooltip_text.contains("×2") and card.tooltip_text.contains("Account-bound") and card.tooltip_text.contains("2 spare"), "Binding variants stay separate while duplicate totals count all owned copies")
	var image := card.find_child("MountImage", true, false) as TextureRect
	_check(image.texture != null and image.custom_minimum_size.y == 48 and card.custom_minimum_size.y == 146, "Compact cards keep visible shiny previews")
	menu.duplicates.button_pressed = true
	_check(menu.filtered_offers.size() == 3 and bool(state.get("duplicates", false)), "Duplicates-only excludes the last Rayquaza and includes mixed binding Glaceon copies")
	menu.binding.select(1)
	menu.binding.item_selected.emit(1)
	_check(menu.filtered_offers.size() == 1 and menu.filtered_offers[0]["itemId"] == tradeable["itemId"], "Binding filters combine with duplicate protection")
	menu.binding.select(0)
	menu.binding.item_selected.emit(0)
	menu.tabs.current_tab = 2
	_check(menu.filtered_offers.size() == 1 and menu.filtered_offers[0]["shinyMountId"] == "primal_kyogre_shiny", "Surf tab selects Surf mounts")
	menu.search.text = "   GLACEON "
	menu.search.text_changed.emit(menu.search.text)
	_check(menu.filtered_offers.is_empty() and menu.empty_label.visible, "Search combines with tabs and shows an explicit empty result")
	menu.tabs.current_tab = 1
	_check(menu.filtered_offers.size() == 2, "Search ignores case and surrounding whitespace and selects matching Land mounts")
	var selections: Array[String] = []
	menu.topic_selected.connect(func(value: String) -> void: selections.append(value))
	var chosen := grid.get_child(0) as Button
	var chosen_id := str(chosen.get_meta("item_id"))
	chosen.pressed.emit()
	chosen.pressed.emit()
	_check(selections == [chosen_id], "Choosing a card selects exactly one binding variant once")
	menu.queue_free()
	await process_frame
	var refreshed = menu_script.new()
	root.add_child(refreshed)
	refreshed.call("_build_grid", [offer, tradeable, single, surf], 0, 100, state)
	_check(refreshed.search.text == "   GLACEON " and refreshed.duplicates.button_pressed and refreshed.tabs.current_tab == 1, "Search, tabs and filters survive confirmation and catalog refresh")
	refreshed.queue_free()
	await process_frame
	var many_offers: Array = []
	for index: int in range(250):
		var another: Dictionary = offer.duplicate()
		another["itemId"] = "mount-%03d" % index
		many_offers.append(another)
	var page_menu = menu_script.new()
	root.add_child(page_menu)
	page_menu.call("_build_grid", many_offers, 0, 100)
	_check(page_menu.grid.get_child_count() == 12, "Large inventories create at most twelve cards on a page")
	page_menu.next.pressed.emit()
	_check(page_menu.grid.get_child(0).get_meta("item_id") == "mount-012" and not page_menu._resolved, "Pagination changes cards locally without selecting a mount or reloading the catalog")
	page_menu.search.text_changed.emit("no such mount")
	_check(page_menu.grid.get_child_count() == 0 and page_menu.view_state["page"] == 0 and page_menu.previous.disabled and page_menu.next.disabled, "Changing filters resets paging and handles zero results")
	page_menu.queue_free()
	await process_frame
	var narrow_viewport := SubViewport.new()
	narrow_viewport.size = Vector2i(480, 540)
	root.add_child(narrow_viewport)
	var narrow_menu = menu_script.new()
	narrow_viewport.add_child(narrow_menu)
	narrow_menu.call("_build_grid", many_offers, 1, 100)
	for _frame: int in range(3):
		await process_frame
	var narrow_panel := narrow_menu.find_child("MountPanel", true, false) as PanelContainer
	_check(narrow_menu.grid.columns == 2 and narrow_panel.size.x <= 480 and narrow_panel.size.y <= 540, "Filters, scrolling cards and navigation fit narrow viewports")
	narrow_viewport.queue_free()
	await process_frame
	bike.free()

	var inventory := root.get_node("InventoryService")
	var original_script: Script = inventory.get_script()
	inventory.set_script(load("res://tests/support/fake_mount_collector_inventory.gd"))
	inventory.collector_offer = offer
	var world := CollectorSyncWorld.new()
	root.add_child(world)
	world.add_to_group("world")
	var fake_script := load("res://tests/support/fake_mount_collector_npc.gd") as GDScript
	var npc = load("res://scenes/npcs/dialogue_npc.tscn").instantiate()
	npc.set_script(fake_script)
	root.add_child(npc)
	npc.accept_trade = false
	npc.interact_with_player(null)
	for _frame: int in range(2):
		await process_frame
	_check(world.sync_calls == 1 and inventory.catalog_requests == 0 and npc.exchange_in_progress, "First interaction waits for the current map save before requesting collector offers")
	world.hold_sync = false
	world.continue_sync.emit()
	for _frame: int in range(3):
		await process_frame
	_check(inventory.catalog_requests > 0 and npc.shown_errors.is_empty() and not npc.exchange_in_progress, "The initial interaction continues successfully as soon as position synchronization finishes")
	_check(inventory.traded_items.is_empty(), "Canceling confirmation exchanges no mount")
	npc.accept_trade = true
	npc.duplicates_mode = true
	npc.choice_count = 0
	npc.interact_with_player(null)
	npc.interact_with_player(null)
	for _frame: int in range(8):
		await process_frame
	_check(inventory.traded_items == ["shiny-glaceon-mount-bound"], "Confirm exchanges exactly one selected shiny and blocks overlapping interactions")
	_check(inventory.keep_one_requests == [true], "Duplicates-only sends the keep-one safeguard with the exchange request")
	_check(not npc.exchange_in_progress, "Collector releases its interaction lock after completing the exchange")
	_check(npc.shown_dialogue.any(func(line: String) -> bool: return line.contains("received") and line.contains("100")), "Success dialogue reports normal mount and voucher credit")
	var requests_before_failure: int = inventory.catalog_requests
	world.result = {"success": false, "error": "fixture position save failure"}
	await npc.interact_with_player(null)
	_check(inventory.catalog_requests == requests_before_failure and inventory.traded_items.size() == 1, "Failed position synchronization loads no offers and consumes no mount")
	_check(npc.shown_errors.size() == 1 and not npc.exchange_in_progress, "Synchronization errors are shown and release the interaction lock")
	world.result = {"success": true}
	await npc.interact_with_player(null)
	_check(inventory.catalog_requests == requests_before_failure + 1 and not npc.exchange_in_progress, "The collector can be used again after a failed position save")
	npc.queue_free()
	world.queue_free()
	await process_frame
	inventory.set_script(original_script)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var translations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/" + locale + ".json"))
		_check(translations.has("ui.mount_collector.confirmation_title") and translations.has("ui.mount_collector.last_body") and translations.has("ui.mount_collector.received"), "Collector is localized for " + locale)
	quit.call_deferred(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
