extends SceneTree

class WorldFixture extends Node:
	var is_in_battle := false
	var wild_battle_resume_pending := false

var failures := 0
var clock := Time.get_unix_time_from_system()

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("Encounter Guard renewal check timed out")
		quit(1)
	)
	var auth := root.get_node("AuthService")
	var guard := root.get_node("EncounterGuardService")
	for name in ["EncounterGuardService", "ThievingService", "RockSmashService", "CoopService"]:
		root.get_node(name).set_process(false)
	auth.current_user = {"id": 1}
	auth.session_token = "guard-renewal-check"
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	var world := WorldFixture.new()
	root.add_child(world)
	world.add_to_group("world")
	var inventory = load("res://tests/support/encounter_guard_renewal_inventory.gd").new()
	root.add_child(inventory)
	var ui = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	# Changing the root script leaves its two unattached helper Nodes behind.
	ui.pokemon_summary_sprite_loader.free()
	ui.pokedex_sprite_loader.free()
	ui.set_script(load("res://tests/support/encounter_guard_renewal_overlay.gd"))
	ui.inventory = inventory
	root.add_child(ui)
	_state({"active": false, "remaining": 0})
	await ui._refresh_encounter_guard_renewal(3)
	_check(not guard.renewal_pending and inventory.loads == 0, "inactive login does not offer renewal")
	_state({"active": true, "remaining": 1})
	world.is_in_battle = true
	_state({"active": false, "remaining": 0})
	await ui._refresh_encounter_guard_renewal(3)
	_check(guard.renewal_pending and inventory.loads == 0, "3,000th encounter queues renewal until battle finishes")
	world.is_in_battle = false
	world.wild_battle_resume_pending = true
	await ui._refresh_encounter_guard_renewal(3)
	_check(inventory.loads == 0, "pending battle resume also defers the dialog")
	world.wild_battle_resume_pending = false
	var state := root.get_node("GameState")
	state.acquire_overworld_input_lock(&"renewal-test-interaction")
	await ui._refresh_encounter_guard_renewal(3)
	_check(inventory.loads == 0, "NPC or transition lock defers the dialog")
	state.release_overworld_input_lock(&"renewal-test-interaction")
	ui._show_ui_confirm_popup("Other", "Existing dialog", "Confirm", Callable())
	await ui._refresh_encounter_guard_renewal(3)
	_check(ui.ui_confirm_title_label.text == "Other" and inventory.loads == 0, "existing confirmation is not replaced")
	ui._hide_ui_confirm_popup()
	ui.evolution_prompt_queue.append({"pokemonId": 123})
	await ui._refresh_encounter_guard_renewal(3)
	_check(inventory.loads == 0, "pending post-battle evolution takes priority")
	ui.evolution_prompt_queue.clear()
	await ui._refresh_encounter_guard_renewal(3)
	_check(ui.ui_confirm_popup.visible and inventory.loads == 1 and inventory.uses == 0, "spare item offers confirmation without consuming it")
	_check(state.is_overworld_input_locked(), "renewal dialog blocks walking into another encounter")
	if "--preview" in OS.get_cmdline_user_args():
		ui.ui_confirm_title_label.text = "Encounter Guard uitgewerkt"
		ui.ui_confirm_message_label.text = "Je Encounter Guard is uitgewerkt. Wil je een nieuwe activeren voor maximaal 3.000 wilde encounters, tot je eerste Ultra Rare, Legendary of Shiny?"
		ui.ui_confirm_confirm_button.text = "Activeren"
		ui.ui_confirm_cancel_button.text = "Later"
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var region: Rect2 = root.get_stretch_transform() * ui.ui_confirm_popup.get_global_rect().grow(8)
		image.get_region(Rect2i(region)).save_png(ProjectSettings.globalize_path("res://../.runtime/encounter_guard_renewal_preview.png"))
	await ui._on_ui_confirm_cancel_pressed()
	_check(not state.is_overworld_input_locked(), "Later releases the movement lock")
	_state({"active": false, "remaining": 0})
	await ui._refresh_encounter_guard_renewal(3)
	_check(not ui.ui_confirm_popup.visible and inventory.loads == 1 and inventory.uses == 0, "Later and repeated polls do not repeat the offer")
	_deplete()
	inventory.owned_items = []
	inventory.borrowed_items = [{"itemId": "encounter-guard", "quantity": 5}]
	await ui._refresh_encounter_guard_renewal(3)
	_check(not guard.renewal_pending and not ui.ui_confirm_popup.visible, "borrowed stock cannot produce a renewal offer")
	_deplete()
	inventory.owned_items = [{"itemId": "encounter-guard", "quantity": 0}]
	await ui._refresh_encounter_guard_renewal(3)
	_check(not ui.ui_confirm_popup.visible and not guard.renewal_pending, "zero stock produces no dialog")
	_deplete()
	inventory.owned_items[0].quantity = 2
	inventory.fail_load = true
	await ui._refresh_encounter_guard_renewal(3)
	_check(guard.renewal_pending and not ui.ui_confirm_popup.visible, "failed Bag refresh keeps the offer pending")
	inventory.fail_load = false
	inventory.after_load = func() -> void: world.is_in_battle = true
	await ui._refresh_encounter_guard_renewal(3)
	_check(guard.renewal_pending and not ui.ui_confirm_popup.visible, "battle beginning during Bag refresh defers the offer")
	world.is_in_battle = false
	await ui._refresh_encounter_guard_renewal(3)
	var stale_callback: Callable = ui.ui_confirm_callback
	_state({"active": true, "remaining": 3000})
	await ui._refresh_encounter_guard_renewal(3)
	await stale_callback.call()
	_check(not ui.ui_confirm_popup.visible and inventory.uses == 0, "manual activation cancels the offer and invalidates its old callback")
	# Rare protection is consumed before the symbol challenge. Offer only after
	# successful unlock, co-op partner readiness and completion of the battle.
	world.is_in_battle = true
	_state({"active": false, "remaining": 0, "locked": true, "battleId": "rare-check", "expiresAt": clock + 60, "challenge": JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/encounter_guard_challenge.json"))})
	await ui._refresh_encounter_guard_renewal(3)
	_check(guard.renewal_pending and paused and not ui.ui_confirm_popup.visible, "rare consumption queues renewal behind the unlock screen")
	_state({"active": false, "remaining": 0, "battleId": "rare-check", "waitingForPartner": true})
	await ui._refresh_encounter_guard_renewal(3)
	_check(paused and not ui.ui_confirm_popup.visible, "co-op partner wait retains the pending offer")
	_state({"active": false, "remaining": 0, "battleId": "rare-check"})
	await ui._refresh_encounter_guard_renewal(3)
	_check(not paused and not ui.ui_confirm_popup.visible, "unlock alone does not interrupt the rare battle")
	world.is_in_battle = false
	await ui._refresh_encounter_guard_renewal(3)
	_check(ui.ui_confirm_popup.visible, "rare battle completion offers a fresh guard")
	await ui._on_ui_confirm_confirm_pressed()
	_check(inventory.uses == 1 and guard.guard.remaining == 3000 and not guard.renewal_pending, "confirm consumes exactly one spare and restores 3,000 encounters")
	_check(root.get_node("InventoryService").cached_inventory_items[0].quantity == 1 and ui.bag_refreshes == 1, "activation updates authoritative Bag stock and visible Bag")
	_check(ui.messages.back() == root.get_node("LocalizationManager").text("ui.encounter_guard.activated"), "activation confirms success in chat")
	clock = Time.get_unix_time_from_system() + 1100
	_deplete()
	await ui._refresh_encounter_guard_renewal(3)
	inventory.fail_use = true
	await ui._on_ui_confirm_confirm_pressed()
	_check(inventory.uses == 2 and guard.guard.remaining == 0 and ui.messages.back() == "Activation refused", "rejected activation reports the failure without inventing protection")
	_deplete()
	await ui._refresh_encounter_guard_renewal(3)
	stale_callback = ui.ui_confirm_callback
	auth.session_token = "different-session"
	await ui._refresh_encounter_guard_renewal(3)
	await stale_callback.call()
	_check(not ui.ui_confirm_popup.visible and inventory.uses == 2, "session change closes the dialog and invalidates confirmation")
	_state({"active": false, "remaining": 0})
	_check(not guard.renewal_pending, "session change resets the pending offer")
	_deplete()
	inventory.after_load = func() -> void: auth.session_token = "new-session-during-load"
	await ui._refresh_encounter_guard_renewal(3)
	_check(not ui.ui_confirm_popup.visible, "old-session Bag response cannot show a dialog")
	ui.pokemon_summary_sprite_loader.free()
	ui.pokedex_sprite_loader.free()
	ui.queue_free()
	inventory.queue_free()
	world.queue_free()
	auth.current_user = {}
	auth.session_token = ""
	await process_frame
	print("Encounter Guard renewal check: ", failures, " failures")
	quit(1 if failures else 0)

func _state(value: Dictionary) -> void:
	clock += 1
	value["serverTime"] = clock
	root.get_node("EncounterGuardService").apply_state(value)

func _deplete() -> void:
	_state({"active": true, "remaining": 1})
	_state({"active": false, "remaining": 0})

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
