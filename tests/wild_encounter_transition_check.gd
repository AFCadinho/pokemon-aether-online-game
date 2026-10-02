extends SceneTree

const WildEncounterTransitionScript := preload("res://scripts/ui/wild_encounter_transition.gd")
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const WORLD_PATH := "res://scripts/world/world.gd"
const BATTLE_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var transition := WildEncounterTransitionScript.new() as WildEncounterTransition
	root.add_child(transition)
	await process_frame
	_check_true(transition.size.x > 0.0 and transition.size.y > 0.0, "encounter transition fills the viewport")

	# Sample every band at its staggered start and end: motion must begin
	# gently, remain monotonic, and fully cover even the final band.
	for index in range(WildEncounterTransition.BAND_COUNT):
		var start := float(index) / float(WildEncounterTransition.BAND_COUNT - 1) * WildEncounterTransition.BAND_STAGGER_SHARE
		transition.cover_progress = start
		_check_true(is_zero_approx(transition.band_progress(index)), "band starts at zero width")
		transition.cover_progress = start + 0.001
		_check_true(transition.band_progress(index) < 0.00001, "band starts without an abrupt velocity jump")
		var previous := 0.0
		for sample_index in range(101):
			transition.cover_progress = float(sample_index) / 100.0
			var progress := transition.band_progress(index)
			_check_true(progress >= previous, "band motion remains monotonic")
			previous = progress
		_check_true(is_equal_approx(previous, 1.0), "every band fully covers at the endpoint")
	transition.cover_progress = 0.23
	_check_true(transition.encounter_flash_alpha() <= 0.24, "wild entry flash stays soft")
	transition.is_revealing = true
	_check_true(is_zero_approx(transition.encounter_flash_alpha()), "wild reveal never repeats the entry flash")

	transition.begin()
	_check_true(transition.visible, "encounter transition becomes visible immediately")
	_check_true(transition.is_processing(), "encounter transition animates while covering")

	await transition.wait_until_covered()
	_check_true(transition.cover_progress >= 0.999, "encounter transition reaches full cover")

	await transition.reveal()
	_check_true(not transition.visible, "encounter transition hides after reveal")
	_check_true(not transition.is_processing(), "encounter transition stops animating after reveal")
	_check_true(transition.cover_progress <= 0.001, "encounter transition fully clears after reveal")

	transition.begin(WildEncounterTransition.STYLE_RANKED)
	_check_true(transition.transition_style == WildEncounterTransition.STYLE_RANKED, "ranked battle uses its dedicated transition style")
	await transition.wait_until_covered()
	await transition.reveal()
	_check_true(not transition.visible, "ranked transition hides after battle reveal")

	transition.begin(WildEncounterTransition.STYLE_TRAINER)
	_check_true(transition.transition_style == WildEncounterTransition.STYLE_TRAINER, "ordinary NPC battles use the trainer transition")
	await transition.wait_until_covered()
	await transition.reveal()

	transition.begin(WildEncounterTransition.STYLE_SPECIAL_TRAINER)
	_check_true(transition.transition_style == WildEncounterTransition.STYLE_SPECIAL_TRAINER, "special NPC battles use the cinematic trainer transition")
	await transition.wait_until_covered()
	await transition.reveal()

	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	var countdown_finish_index := ui_source.find("func _finish_pvp_match_countdown()")
	var transition_begin_index := ui_source.find("_begin_ranked_battle_entry_transition()", countdown_finish_index)
	var request_start_index := ui_source.find("await _open_pvp_queue_match(true)", countdown_finish_index)
	_check_true(
		transition_begin_index > countdown_finish_index and transition_begin_index < request_start_index,
		"ranked transition starts at countdown zero before the battle request"
	)
	var world_pvp_start_index := world_source.find("func start_pvp_battle_from_response")
	var cover_wait_index := world_source.find("await _wait_for_pvp_battle_cover()", world_pvp_start_index)
	var mount_index := world_source.find("if not _mount_battle_ui():", world_pvp_start_index)
	_check_true(
		cover_wait_index > world_pvp_start_index and cover_wait_index < mount_index,
		"PvP scene mounting happens behind the covered transition"
	)
	var setup_index := battle_source.find("func setup_pvp_battle_from_response")
	var ready_index := battle_source.find("await _notify_pvp_entry_ready(entry_ready_callback)", setup_index)
	var lead_selection_index := battle_source.find("lead_response = await _run_pvp_team_preview_lead_selection", setup_index)
	_check_true(
		ready_index > setup_index and ready_index < lead_selection_index,
		"ranked transition reveals when Team Preview is ready"
	)
	var world_trainer_start_index := world_source.find("func start_trainer_battle")
	var trainer_transition_index := world_source.find("_begin_trainer_battle_transition(battle_trainer_data)", world_trainer_start_index)
	var trainer_request_index := world_source.find("await create_trainer_battle_response", world_trainer_start_index)
	var trainer_expected_rejection_index := world_source.find(
		"if not _is_expected_trainer_battle_rejection(response):",
		trainer_request_index
	)
	var trainer_failure_warning_index := world_source.find(
		'push_warning("World.start_trainer_battle failed:',
		trainer_request_index
	)
	var trainer_mount_index := world_source.find("if not _mount_battle_ui():", world_trainer_start_index)
	_check_true(
		trainer_transition_index > world_trainer_start_index
		and trainer_transition_index < trainer_request_index
		and trainer_request_index < trainer_mount_index,
		"NPC transition covers trainer loading before the battle scene mounts"
	)
	_check_true(
		world_source.count('== "pokemon_party_changed_refresh_required"') >= 2
		and world_source.count("and await _load_player_party_state()") >= 2,
		"wild and Trainer battle starts refresh a stale party and retry once"
	)
	_check_true(
		world_source.contains("PlayerSave.replace_party_from_state([])"),
		"an authoritative empty party clears stale local party state"
	)
	_check_true(
		trainer_expected_rejection_index > trainer_request_index
		and trainer_failure_warning_index > trainer_expected_rejection_index
		and world_source.contains('"pokemon_level_cap_party_ineligible"'),
		"expected trainer level-cap rejections do not emit failure warnings"
	)
	var trainer_setup_index := battle_source.find("func setup_trainer_battle_from_response")
	var trainer_lead_index := battle_source.find("var lead_response := await _run_trainer_lead_selection", trainer_setup_index)
	var trainer_preview_gate_index := battle_source.find("if team_preview_enabled:", trainer_setup_index)
	var trainer_preview_ready_index := battle_source.find(
		"await _notify_trainer_entry_ready(entry_ready_callback)",
		trainer_preview_gate_index
	)
	var trainer_default_gate_index := battle_source.find("if not team_preview_enabled:", trainer_lead_index)
	var trainer_default_ready_index := battle_source.find(
		"await _notify_trainer_entry_ready(entry_ready_callback)",
		trainer_default_gate_index
	)
	var trainer_default_field_clear_index := battle_source.find(
		"await _prepare_team_preview_lead_summon_transition()",
		trainer_default_gate_index
	)
	_check_true(
		trainer_preview_gate_index > trainer_setup_index
		and trainer_preview_ready_index > trainer_preview_gate_index
		and trainer_preview_ready_index < trainer_lead_index,
		"configured NPC Team Preview reveals before interactive lead selection"
	)
	_check_true(
		trainer_default_gate_index > trainer_lead_index
		and trainer_default_field_clear_index > trainer_default_gate_index
		and trainer_default_ready_index > trainer_default_gate_index,
		"regular NPC transition stays covered until automatic leads and the empty summon field are ready"
	)
	_check_true(
		trainer_default_field_clear_index < trainer_default_ready_index,
		"regular NPC transition reveals the empty field before either lead is summoned"
	)

	await _check_classic_overlay(transition)
	transition.queue_free()
	if not failed:
		print("wild_encounter_transition_check: PASS")
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)


func _check_classic_overlay(transition: WildEncounterTransition) -> void:
	var settings := root.get_node("SettingsManager")
	var previous_layout: String = settings.battle_ui_layout
	var previous_mode: String = settings.battle_presentation_mode
	settings.battle_ui_layout = "classic"
	settings.battle_presentation_mode = "2d"
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load(WORLD_PATH))
	world.set_process(false)
	world.wild_encounter_transition = transition
	world.battle_ui_host = Control.new()
	world.add_child(world.battle_ui_host)
	world.active_battle_kind = "wild"
	var started: int = world._begin_wild_encounter_transition()
	_check_true(transition.transition_style == WildEncounterTransition.STYLE_CLASSIC_WILD, "Classic overlay selects transparent wild transition")
	var entry_frame := Engine.get_process_frames()
	await world._wait_for_wild_encounter_cover(started)
	_check_true(Engine.get_process_frames() == entry_frame and transition.active_tween == null, "Classic entry never waits for a cover animation")
	_check_true(is_zero_approx(transition.encounter_flash_alpha()), "Classic wild encounters have no fullscreen flash")
	world.battle_instance = Control.new()
	world.battle_instance.size = Vector2(640, 400)
	_check_true(world._attach_battle_ui(), "Classic battle mounts directly over the world")
	_check_true(world.battle_screen_host == null, "Classic 2D overlay has no opaque screen host")
	_check_true(world.classic_wild_backdrop.get_index() < world.battle_instance.get_index(), "Dimming stays behind the battle controls")
	world._prepare_battle_instance_reveal()
	_check_true(is_equal_approx(world.battle_instance.modulate.a, 1.0), "Classic battle is visible as soon as it mounts")
	var reveal_frame := Engine.get_process_frames()
	await world._reveal_prepared_wild_battle()
	_check_true(Engine.get_process_frames() == reveal_frame and world.classic_wild_tween == null, "Classic reveal starts the battle without waiting for a fade")
	_check_true(is_equal_approx(world.battle_instance.modulate.a, 1.0), "Battle remains fully visible")
	_check_true(world.battle_instance.scale.is_equal_approx(Vector2.ONE), "Battle finishes at its normal size")
	_check_true(is_equal_approx(world.classic_wild_backdrop.color.a, WildEncounterTransition.CLASSIC_DIM_ALPHA), "Overworld remains softly dimmed during battle")
	_check_true(not transition.visible, "Entry effect clears after reveal")
	_check_true(await world._fade_classic_wild_battle_out(), "Normal Classic exit completes")
	_check_true(is_zero_approx(world.battle_instance.modulate.a) and is_zero_approx(world.classic_wild_backdrop.color.a), "Exit clears the battle and dimming together")
	world._clear_battle_ui_instance.call_deferred()
	_check_true(not await world._fade_classic_wild_battle_out(), "Teardown cancels a pending exit without waiting on a killed tween")
	world._clear_battle_ui_instance()
	_check_true(world.classic_wild_backdrop == null, "Repeated teardown releases the dimming layer")
	settings.battle_ui_layout = "immersive"
	world._begin_wild_encounter_transition()
	_check_true(transition.transition_style == WildEncounterTransition.STYLE_FULLSCREEN_SLIDE, "Immersive wild entry keeps the world visible for the fullscreen slide")
	_check_true(transition.active_tween == null and is_zero_approx(transition.encounter_flash_alpha()), "Fullscreen entry has no pre-battle wipe or flash")
	await transition.wait_until_covered()
	await transition.reveal()
	_check_true(transition.overworld_snapshot == null, "Fullscreen reveal releases its snapshot reference")
	settings.battle_ui_layout = previous_layout
	settings.battle_presentation_mode = previous_mode
	world.set_script(null)
	world.queue_free()
	await process_frame
