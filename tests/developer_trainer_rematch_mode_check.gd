extends SceneTree

const TRAINER_SCENE_PATH := "res://scenes/npcs/trainer_npc.tscn"
const GYM_LEADER_SCENE_PATH := "res://scenes/npcs/gym_leader_npc.tscn"
const TRAINER_PROGRESS_SERVICE_PATH := "res://scripts/services/trainer_progress_service.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_contract_sources()
	_check_regular_trainers_become_manual_rematches()
	_check_story_trainers_keep_their_normal_state()
	quit(1 if failures > 0 else 0)


func _check_contract_sources() -> void:
	_check(load(UI_OVERLAY_PATH) != null, "developer tools overlay script parses")
	var service_source := FileAccess.get_file_as_string(TRAINER_PROGRESS_SERVICE_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(
		service_source.contains('DEVELOPER_REMATCH_MODE_ENDPOINT := "/game/dev/progression/trainer-rematch-mode"'),
		"trainer progress service uses the protected rematch-mode endpoint"
	)
	_check(
		overlay_source.contains("TrainerProgressService.invalidate_all()"),
		"developer toggle refreshes every visible trainer"
	)
	_check(
		overlay_source.contains("ui.staff.dev.trainer_rematch_mode_description"),
		"developer tools describe the non-rewarding rematch test mode"
	)


func _check_regular_trainers_become_manual_rematches() -> void:
	var trainer := (load(TRAINER_SCENE_PATH) as PackedScene).instantiate() as Node
	trainer.call("_setup_rematch_marker")
	trainer.call("_apply_trainer_progress", {
		"state": "first_encounter",
		"developerRematchMode": true,
	}, "first_encounter")
	trainer.call("_refresh_rematch_marker")
	var marker := trainer.get("rematch_marker") as Control
	_check(trainer.get("trainer_progress_state") == "ready", "ordinary trainer becomes rematch-ready")
	_check(not bool(trainer.call("_can_auto_challenge")), "rematch-ready trainer cannot auto-challenge")
	_check(marker != null and marker.visible, "rematch-ready trainer keeps a visible manual-battle marker")
	trainer.free()


func _check_story_trainers_keep_their_normal_state() -> void:
	var leader := (load(GYM_LEADER_SCENE_PATH) as PackedScene).instantiate() as Node
	leader.call("_apply_trainer_progress", {
		"state": "first_encounter",
		"developerRematchMode": true,
	}, "first_encounter")
	_check(leader.get("trainer_progress_state") == "first_encounter", "gym leader ignores developer rematch mode")
	leader.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
