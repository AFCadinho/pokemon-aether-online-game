extends SceneTree

var failures := 0

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
	var topics: Array = collector.call("_offer_topics", [offer], 0)
	_check(topics[0]["id"] == offer["itemId"] and topics[0]["label"].contains("Account-bound"), "Selection preserves bound inventory ID and displays its binding")
	var many_offers: Array = []
	for index: int in range(12):
		var another: Dictionary = offer.duplicate()
		another["itemId"] = "mount-%s" % index
		many_offers.append(another)
	var page: Array = collector.call("_offer_topics", many_offers, 1)
	_check(page.size() == 7 and page[0]["id"] == "mount-5" and page[5]["id"] == "previous" and page[6]["id"] == "next", "Large collections paginate without hiding later mount types")
	bike.free()

	var inventory := root.get_node("InventoryService")
	var original_script: Script = inventory.get_script()
	inventory.set_script(load("res://tests/support/fake_mount_collector_inventory.gd"))
	inventory.collector_offer = offer
	var fake_script := load("res://tests/support/fake_mount_collector_npc.gd") as GDScript
	var npc = load("res://scenes/npcs/dialogue_npc.tscn").instantiate()
	npc.set_script(fake_script)
	root.add_child(npc)
	npc.accept_trade = false
	await npc.interact_with_player(null)
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
	npc.queue_free()
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
