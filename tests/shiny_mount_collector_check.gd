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
	var text: String = collector.call("_confirmation_text", offer, 100)
	_check(text.contains("100") and text.contains("removed") and text.contains("account-bound") and text.contains("already own"), "Confirmation discloses consumption, credit, binding and duplicate normal rewards")
	var menu_script := load("res://scripts/ui/mount_collector_grid.gd") as GDScript
	var menu = menu_script.new()
	root.add_child(menu)
	var tradeable: Dictionary = offer.duplicate()
	tradeable["itemId"] = "shiny-glaceon-mount"
	tradeable["accountBound"] = false
	menu.call("_build_grid", [offer, tradeable], 0, 100)
	await process_frame
	var grid := menu.find_child("MountCards", true, false) as GridContainer
	_check(grid.columns == 2 and grid.get_child_count() == 2, "Small collections fill a compact two-column grid")
	var card := grid.get_child(0) as Button
	_check(card.get_meta("item_id") == offer["itemId"] and card.tooltip_text.contains("×2") and card.tooltip_text.contains("Account-bound"), "Mount card preserves the exact inventory ID, quantity and binding")
	var image := card.find_child("MountImage", true, false) as TextureRect
	_check(image.texture != null and image.custom_minimum_size.y == 80, "Mount card displays a large actual shiny mount image")
	_check((grid.get_child(1) as Button).tooltip_text.contains("Tradeable"), "Tradeable copies have an explicit separate label")
	var selections: Array[String] = []
	menu.topic_selected.connect(func(value: String) -> void: selections.append(value))
	card.pressed.emit()
	card.pressed.emit()
	_check(selections == [str(offer["itemId"])], "Clicking a card selects exactly its inventory variant once")
	menu.queue_free()
	await process_frame
	var many_offers: Array = []
	for index: int in range(18):
		var another: Dictionary = offer.duplicate()
		another["itemId"] = "mount-%s" % index
		many_offers.append(another)
	var page_menu = menu_script.new()
	root.add_child(page_menu)
	page_menu.call("_build_grid", many_offers, 1, 100)
	await process_frame
	var page_grid := page_menu.find_child("MountCards", true, false) as GridContainer
	_check(page_grid.columns == 3 and page_grid.get_child_count() == 6 and page_grid.get_child(0).get_meta("item_id") == "mount-6", "Large collections paginate six mount cards in three columns")
	var page_choices: Array[String] = []
	page_menu.topic_selected.connect(func(value: String) -> void: page_choices.append(value))
	page_menu.call("_finish", "next")
	_check(page_choices == ["next"], "Page navigation is separate from mount selection")
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
	var narrow_grid := narrow_menu.find_child("MountCards", true, false) as GridContainer
	var narrow_panel := narrow_menu.find_child("MountPanel", true, false) as PanelContainer
	_check(narrow_grid.columns == 2 and narrow_panel.size.x <= 480 and narrow_panel.size.y <= 540, "Narrow viewports keep the two-column grid and navigation within the screen")
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
	npc.choice_count = 0
	npc.interact_with_player(null)
	npc.interact_with_player(null)
	for _frame: int in range(8):
		await process_frame
	_check(inventory.traded_items == ["shiny-glaceon-mount-bound"], "Confirm exchanges exactly one selected shiny and blocks overlapping interactions")
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
		_check(translations.has("ui.mount_collector.confirm") and translations.has("ui.mount_collector.received"), "Collector is localized for " + locale)
	quit.call_deferred(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
