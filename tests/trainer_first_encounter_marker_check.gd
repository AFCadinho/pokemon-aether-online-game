extends SceneTree

const FIRST_ENCOUNTER_TEXTURE_PATH := "res://assets/ui/icons/trainer_first_encounter.png"
const REMATCH_TEXTURE_PATH := "res://assets/ui/icons/trainer_challenge.png"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var trainer_scene := load("res://scenes/npcs/trainer_npc.tscn") as PackedScene
	_check(trainer_scene != null, "Trainer NPC scene loads for marker checks")
	if trainer_scene == null:
		quit(1)
		return

	var trainer := trainer_scene.instantiate() as Node
	trainer.call("_setup_rematch_marker")
	trainer.set("trainer_progress_loaded", true)
	trainer.set("trainer_progress_state", "first_encounter")
	trainer.call("_refresh_rematch_marker")

	var marker := trainer.get("rematch_marker") as Control
	var icon := trainer.get("rematch_marker_icon") as TextureRect
	_check(marker != null and marker.visible, "unbattled trainer shows a challenge marker")
	_check(
		icon != null
		and icon.visible
		and icon.texture != null
		and icon.texture.resource_path == FIRST_ENCOUNTER_TEXTURE_PATH,
		"unbattled trainer uses the exclamation icon"
	)
	_check(
		icon.texture.get_width() == 48 and icon.texture.get_height() == 48,
		"exclamation icon keeps the existing 48 pixel marker size"
	)

	_check(bool(trainer.call("_claim_battle_interaction")), "trainer battle can claim interaction")
	_check(not marker.visible, "challenge marker hides when the battle interaction starts")

	trainer.set("battle_in_progress", false)
	trainer.call("_refresh_rematch_marker")
	_check(marker.visible, "challenge marker returns if the first battle does not start")

	trainer.set("trainer_progress_state", "defeated")
	trainer.call("_refresh_rematch_marker")
	_check(not marker.visible, "challenge marker stays hidden for a defeated trainer")

	trainer.set("trainer_progress_state", "ready")
	trainer.call("_refresh_rematch_marker")
	_check(
		marker.visible
		and icon.texture != null
		and icon.texture.resource_path == REMATCH_TEXTURE_PATH,
		"ready rematches keep their existing trainer challenge icon"
	)

	trainer.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
