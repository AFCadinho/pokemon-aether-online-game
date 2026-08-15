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

	trainer.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
