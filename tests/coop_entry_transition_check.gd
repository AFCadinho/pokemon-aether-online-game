extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings._manual_model_catalog_this_session = false
	settings.battle_3d_catalog_path = ""
	root.get_node("OnDemand3DBundleService").set_process(false)
	var service := root.get_node("CoopService")
	service.set_process(false)
	for mode: String in ["2d", "3d"]:
		for layout: String in ["immersive", "classic"]:
			for warm in [true, false]:
				settings.battle_presentation_mode = mode
				settings.battle_ui_layout = layout
				await _check_entry(warm)
	settings.battle_presentation_mode = "3d"
	settings.battle_ui_layout = "classic"
	await _check_entry(true, true)
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	await _check_rejected_entry()
	service.reset()
	print("coop_entry_transition_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _make_world() -> Variant:
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://tests/fixtures/coop_world_fixture.gd"))
	world.set_process(false)
	var ui := Control.new()
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hide()
	world.battle_ui_host = ui
	var transition := WildEncounterTransition.new()
	root.add_child(transition)
	world.wild_encounter_transition = transition
	world.coop_world_ready = true
	return world

func _check_entry(warm: bool, solo_cache := false) -> void:
	var service := root.get_node("CoopService")
	service.reset()
	service.party = {"leaderId": 1, "memberIds": [1, 2]}
	var world: Variant = _make_world()
	if warm:
		# Exercise the real idle-party prewarm callback before the reservation.
		if solo_cache:
			world._prewarm_wild_battle_ui()
		else:
			world._on_coop_state_changed()
		await process_frame
		_check(is_instance_valid(world.prepared_wild_battle), "Idle parties prepare the doubles screen in advance")
	var prepared: Control = world.prepared_wild_battle
	service.activity = {"reservationId": "fixture", "battleId": "fixture", "status": "starting",
		"activityId": "wild_grass:kanto_route_1"}
	world._on_coop_state_changed()
	var battle: Control = world.battle_instance
	var host: Control = world.battle_screen_host
	_check(is_instance_valid(battle) and is_instance_valid(host) and world.is_in_battle,
		"Doubles mounts even before the first participant view")
	if not is_instance_valid(host):
		await _dispose(world)
		return
	_check(world.mount_count == (0 if warm and not solo_cache else 1)
		and (not warm or (battle != prepared if solo_cache else battle == prepared)),
		"Doubles reuses compatible screens and safely replaces an incompatible classic cache")
	_check(battle.coop_mode and battle.has_meta("immersive_battle_ui") and world.lock_count == 1,
		"Both layouts mount the doubles screen and lock the overworld once")
	_check(world.wild_encounter_transition.transition_style == WildEncounterTransition.STYLE_FULLSCREEN_FADE
		and not world.wild_encounter_transition.visible,
		"Doubles hands the fullscreen transition snapshot over to the battle host")
	_check(host.reveal_requested or host.early_arena_requested,
		"Entry requests the early arena without waiting for a participant view")
	if root.get_node("SettingsManager").battle_presentation_mode == "3d":
		_check(host.early_arena_requested and battle.animation_router.model_presenter.double_mode,
			"3D entry uses the actual four-slot arena presenter")
	var deadline := Time.get_ticks_msec() + 15000
	while host.fade_progress < 1.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(host.fade_progress == 1.0 and service.view.is_empty(),
		"The fade finishes while the shared battle response is still pending")
	if root.get_node("SettingsManager").battle_presentation_mode == "3d":
		_check(host.entry_arena_ready and not host.preparation_ready
			and battle.animation_router.model_presenter.is_visible_in_tree(),
			"The real 3D arena stays visible while combatants are unknown")
	var fade_before: float = host.fade_progress
	world._on_coop_state_changed()
	_check(world.battle_instance == battle and world.battle_screen_host == host and world.lock_count == 1
		and host.fade_progress >= fade_before, "Repeated polls preserve the scene and transition progress")
	await _dispose(world)

func _check_rejected_entry() -> void:
	var service := root.get_node("CoopService")
	service.reset()
	service.activity = {"reservationId": "retry", "status": "starting"}
	var world: Variant = _make_world()
	world.reject_mount = true
	world._on_coop_state_changed()
	_check(not world.is_in_battle and world.active_battle_kind.is_empty() and world.unlock_count == 1
		and not world.battle_ui_host.visible and not world.wild_encounter_transition.visible,
		"Failed mounts restore overworld input and hide the transition")
	_check(service.activity.get("reservationId") == "retry", "A local mount failure preserves the shared reservation for retry")
	world.reject_mount = false
	world._on_coop_state_changed()
	_check(world.is_in_battle and world.active_battle_kind == "coop" and world.lock_count == 2
		and is_instance_valid(world.battle_screen_host), "The next poll can retry a failed mount successfully")
	await _dispose(world)

func _dispose(world: Variant) -> void:
	world._discard_prepared_wild_battle_ui()
	world._clear_battle_ui_instance()
	world.battle_ui_host.queue_free()
	world.wild_encounter_transition.queue_free()
	world.queue_free()
	await process_frame
