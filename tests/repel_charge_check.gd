extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Keep unrelated login pollers offline while this check uses a fake session.
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	var auth: Node = root.get_node("AuthService")
	var state: Node = root.get_node("GameState")
	var repel: Node = root.get_node("RepelService")
	var game: Node = root.get_node("PlayerGameStateService")
	var inventory: Node = root.get_node("InventoryService")
	game.set_script(load("res://tests/support/fake_repel_game_service.gd"))
	inventory.set_script(load("res://tests/support/fake_repel_inventory.gd"))
	auth.session_token = "repel-check"
	auth.current_user = {"id": 1}
	repel.set_process(false)
	repel.apply_initial_state({"repelSteps": 100})
	state.repel_enabled = true
	var actor: Node2D = load("res://scripts/world/player.gd").new()
	var map := _EncounterMap.new()
	state.current_map = map

	for encounter_type: String in ["grass", "surf", "cave"]:
		actor.check_for_wild_encounter(encounter_type)
	_check(state.repel_steps == 97, "grass, surf and cave each cost one step before any encounter roll")
	map.chance = 0.0
	actor.check_for_wild_encounter("cave")
	_check(state.repel_steps == 97, "safe areas with zero encounter chance keep charge")
	map.area_id = ""
	actor.check_for_wild_encounter("grass")
	_check(state.repel_steps == 97, "maps without encounters keep charge")
	map.area_id = "test"
	map.chance = 0.25
	state.repel_enabled = false
	actor.check_for_wild_encounter("grass")
	_check(state.repel_steps == 97, "disabled toggle keeps charge")
	state.repel_enabled = true
	_check(not actor._does_repel_block_encounter("old_rod"), "fishing bypasses Repel")
	actor.check_for_wild_encounter("old_rod")
	_check(state.repel_steps == 97, "fishing does not consume charge")

	repel._sync_usage()
	repel.consume_step()
	await repel.sync_finished
	_check(state.repel_steps == 96, "steps walked during an in-flight save remain deducted locally")
	await repel.flush()
	_check(game.charge == 96, "flush persists all completed encounter steps")
	game.fail_next = true
	repel.consume_step()
	var failed_save: Dictionary = await repel.flush()
	_check(not failed_save.success and state.repel_steps == 95, "network failure keeps local consumption pending")
	await repel.flush()
	_check(game.charge == 95 and state.repel_steps == 95, "retry persists consumption without returning free charge")

	game.charge = 100
	state.repel_steps = 100
	state.repel_enabled = true
	var uses_before: int = inventory.use_calls
	var saves_before: int = game.sync_calls
	repel.refill("repel")
	var duplicate: Dictionary = await repel.refill("repel")
	_check(not duplicate.success and inventory.use_calls == uses_before + 1, "repeated refill clicks start only one item request")
	repel.consume_step()
	repel.flush()
	_check(game.sync_calls == saves_before, "autosave waits for an in-flight refill")
	await repel.refill_finished
	await repel.flush()
	_check(game.charge == 199 and state.repel_steps == 199, "walking during refill cannot restore a consumed step")

	game.charge = 9900
	state.repel_steps = 9900
	var refill: Dictionary = await repel.refill("max-repel")
	_check(refill.success and state.repel_steps == 10000, "partial Max Repel refill caps at 10000")
	refill = await repel.refill("repel")
	_check(refill.addedRepelSteps == 0 and state.repel_steps == 10000, "already full stays at cap")

	game.charge = 1
	state.repel_steps = 1
	state.repel_enabled = true
	actor.check_for_wild_encounter("grass")
	_check(state.repel_steps == 0 and not state.repel_enabled, "last charge blocks its step and disables the toggle")
	_check(not repel.consume_step(), "empty charge cannot block another encounter")
	await repel.flush()
	_check(game.charge == 0, "depletion persists")
	var overlay = load("res://tests/support/repel_inventory_test_overlay.gd").new()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(52, 52)
	panel.position = Vector2(30, 30)
	var button := TextureButton.new()
	button.texture_normal = load("res://assets/ui/repel_icon.svg")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.toggle_mode = true
	panel.add_child(button)
	root.add_child(panel)
	overlay.repel_slot = panel
	overlay.repel_toggle_button = button
	overlay._setup_repel_toggle()
	root.get_node("LocalizationManager").set_locale("en")
	var hotbar: Node = root.get_node("PlayerHotbarService")
	hotbar.set_script(load("res://tests/support/fake_repel_hotbar_service.gd"))
	hotbar.hotbar_changed.connect(overlay._on_hotbar_changed)
	var detail_panel := PanelContainer.new()
	root.add_child(detail_panel)
	overlay._setup_bag_detail_panel(detail_panel)
	for item_id: String in ["repel", "super-repel", "max-repel"]:
		# Use the actual inventory projection shape, including empty Pokémon gameplay.
		var normalized: Array = overlay._normalize_bag_inventory_items([
			{"itemId": item_id, "quantity": 1, "category": "general", "useAction": "recharge_repel", "gameplay": {}}
		])
		var refill_item: Dictionary = normalized[0]
		overlay.bag_inventory_items = normalized
		overlay.bag_selected_item = refill_item
		overlay._refresh_bag_detail()
		_check(overlay.bag_detail_use_button.text == "Recharge Repel" and not overlay.bag_detail_use_button.disabled, item_id + " shows an enabled Recharge Repel button")
		_check(not overlay.bag_detail_hotbar_button.disabled, item_id + " can be assigned from Bag details")
		var expected: int = {"repel": 100, "super-repel": 200, "max-repel": 250}[item_id]
		game.charge = 0
		state.repel_steps = 0
		await overlay._on_bag_detail_use_pressed()
		_check(state.repel_steps == expected, item_id + " recharges from the Bag detail button")
		game.charge = 0
		state.repel_steps = 0
		overlay.bag_item_context_item = refill_item
		await overlay._on_bag_item_context_menu_id_pressed(overlay.BAG_CONTEXT_ACTION_USE)
		_check(state.repel_steps == expected, item_id + " recharges from the Bag context menu")
		overlay.bag_inventory_items = normalized
		var slot := HotbarBagItemSlot.new()
		slot.hotbar_item = refill_item
		root.add_child(slot)
		var drag: Variant = slot._get_drag_data(Vector2.ZERO)
		_check(drag is Dictionary and drag.get("kind", "") == "bag_hotbar_item", item_id + " supports native hotbar drag-and-drop")
		await overlay._assign_bag_item_to_hotbar_slot(refill_item, 5)
		_check(hotbar.cached_slots[0] == {"slot": 5, "entryType": "item", "entryId": item_id}, item_id + " saves as an inventory hotbar binding")
		game.charge = 0
		state.repel_steps = 0
		await overlay._on_hotbar_slot_pressed(5)
		_check(state.repel_steps == expected and overlay.pokemon_target_requests == 0, item_id + " recharges directly from the hotbar without Pokémon selection")
		var calls: int = inventory.use_calls
		await overlay._on_hotbar_slot_pressed(5)
		_check(inventory.use_calls == calls, "empty " + item_id + " hotbar stack cannot spend another item")
		slot.queue_free()
		await process_frame
	_check(not overlay._bag_item_can_assign_to_hotbar({"id": "unsupported", "useAction": "unsupported"}), "unsupported inventory actions remain unavailable")
	overlay.bag_inventory_items = overlay._normalize_bag_inventory_items([{ "itemId": "potion", "quantity": 1, "gameplay": {"target": "pokemon", "contexts": ["field"], "effects": [{"type": "heal_hp", "amount": 20}]}}])
	overlay.hotbar_slots = [{"slot": 0, "entryType": "item", "entryId": "potion"}]
	await overlay._on_hotbar_slot_pressed(0)
	_check(overlay.pokemon_target_requests == 1, "medicine hotbar use still selects a Pokémon")
	var item := {"id": "max-repel", "useAction": "recharge_repel"}
	_check(overlay._bag_item_can_use_from_bag(item), "Bag exposes Repel recharge as a usable item")
	game.charge = 9900
	state.repel_steps = 9900
	await overlay._on_bag_item_selected(item)
	_check(overlay.repel_charge_label.text == "10000" and button.tooltip_text.contains("10000"), "toggle displays authoritative charge and cap")
	_check(not state.repel_enabled, "recharge keeps the player's toggle choice")
	root.get_node("LocalizationManager").set_locale("nl")
	overlay._on_locale_changed("nl")
	_check(button.tooltip_text.contains("stappen"), "charge tooltip follows language changes")
	overlay.pokemon_summary_sprite_loader.free()
	overlay.pokedex_sprite_loader.free()
	overlay.free()
	detail_panel.queue_free()
	panel.queue_free()
	await process_frame
	state.repel_steps = 0
	repel.apply_initial_state({"repelSteps": 100})
	_check(state.repel_steps == 0, "late login snapshots cannot restore consumed charge")
	game.charge = 100
	state.repel_steps = 100
	state.repel_enabled = true
	repel.consume_step()
	repel._sync_usage()
	repel.reset()
	auth.session_token = "next-session"
	repel.apply_initial_state({"repelSteps": 45})
	await repel.sync_finished
	_check(state.repel_steps == 45, "late usage responses cannot replace another session's charge")
	repel.reset()
	_check(state.repel_steps == 0 and repel.total_steps == 0, "gameplay reset clears charge and pending usage")
	actor.free()
	map.free()
	state.current_map = null
	auth.session_token = ""
	auth.current_user = {}
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)

class _EncounterMap:
	extends Node2D
	var chance := 0.25
	var area_id := "test"
	func get_wild_encounter_area_id() -> String:
		return area_id
	func get_wild_encounter_chance(_type: String) -> float:
		return chance
	func should_trigger_wild_encounter(_type: String) -> bool:
		return false
