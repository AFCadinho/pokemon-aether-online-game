extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var trainer_script := load("res://scripts/world/npcs/trainer_npc.gd") as GDScript
	_check(trainer_script != null, "Trainer NPC script loads")
	if trainer_script == null:
		quit(1)
		return
	var trainer_source := FileAccess.get_file_as_string("res://scripts/world/npcs/trainer_npc.gd")
	_check(
		trainer_source.contains("var maximum_steps := clampi(expected_steps + 1, 1, 16)")
			and trainer_source.contains("completed_steps < maximum_steps")
			and trainer_source.contains("snapping to battle position"),
		"vision-triggered trainer movement is bounded and cannot freeze overworld input"
	)
	_check(
		trainer_source.contains("_recover_overworld_after_failed_battle_start()")
		and trainer_source.contains("recover_failed_trainer_battle_start"),
		"a rejected trainer battle restores browser overworld control after its error dialogue"
	)
	var trainer := trainer_script.new() as Node
	trainer.set("trainer_progress_loaded", true)
	trainer.set("trainer_progress_state", "first_encounter")

	_check(bool(trainer.call("_claim_battle_interaction")), "first trainer interaction claims battle ownership")
	_check(not bool(trainer.call("_claim_battle_interaction")), "a concurrent trainer interaction cannot claim the same battle")

	trainer.set("battle_in_progress", false)
	trainer.set("is_interacting", true)
	_check(not bool(trainer.call("_can_auto_challenge")), "vision challenge waits while manual interaction owns the NPC")

	trainer.set("is_interacting", false)
	_check(bool(trainer.call("_can_auto_challenge")), "vision challenge remains available outside a manual interaction")

	trainer.set("battle_in_progress", true)
	trainer.set("triggered", true)
	var vision_candidate := Node2D.new()
	trainer.set("vision_candidate", vision_candidate)
	trainer.call("_release_failed_battle_start")
	_check(not bool(trainer.get("battle_in_progress")), "failed battle start releases battle ownership")
	_check(not bool(trainer.get("triggered")), "failed first encounter releases its trigger")
	_check(bool(trainer.get("auto_trigger_failed")), "failed battle start blocks an immediate vision retry")
	_check(trainer.get("vision_candidate") == null, "failed battle start clears the vision candidate")
	_check(not bool(trainer.call("_can_auto_challenge")), "rejected trainer battle cannot enter an automatic dialogue loop")

	vision_candidate.free()
	trainer.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
