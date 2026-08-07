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
	var trainer_mount_index := world_source.find("if not _mount_battle_ui():", world_trainer_start_index)
	_check_true(
		trainer_transition_index > world_trainer_start_index
		and trainer_transition_index < trainer_request_index
		and trainer_request_index < trainer_mount_index,
		"NPC transition covers trainer loading before the battle scene mounts"
	)
	var trainer_setup_index := battle_source.find("func setup_trainer_battle_from_response")
	var trainer_ready_index := battle_source.find("await _notify_trainer_entry_ready(entry_ready_callback)", trainer_setup_index)
	var trainer_lead_index := battle_source.find("var lead_response := await _run_trainer_lead_selection", trainer_setup_index)
	_check_true(
		trainer_ready_index > trainer_setup_index and trainer_ready_index < trainer_lead_index,
		"NPC transition reveals before trainer lead selection begins"
	)

	transition.queue_free()
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
