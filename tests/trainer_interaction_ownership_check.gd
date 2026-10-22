extends SceneTree

class ErrorDialogueProbe extends Node:
	signal dialogue_finished
	var shown := 0

	func start_dialogue(_lines: Array[String], _speaker: String) -> void:
		shown += 1


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
	var metadata_failure_start := trainer_source.find("func _fail_trainer_metadata")
	var metadata_failure_end := trainer_source.find("\nfunc ", metadata_failure_start + 1)
	var metadata_failure_source := trainer_source.substr(metadata_failure_start, metadata_failure_end - metadata_failure_start)
	_check(
		metadata_failure_source.contains("_show_generic_trainer_error_dialogue(dialogue_box)")
			and metadata_failure_source.contains("_recover_overworld_after_failed_battle_start()"),
		"a rejected trainer metadata request also restores browser overworld control"
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
	await _check_recruiter_reward_failure()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)


func _check_recruiter_reward_failure() -> void:
	# Responses are controlled; the production recruiter owns all state transitions.
	var game_state := root.get_node("GameState")
	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	var dialogue_layer := Node.new()
	dialogue_layer.name = "DialogueBox"
	scene.add_child(dialogue_layer)
	var dialogue := ErrorDialogueProbe.new()
	dialogue.name = "Box"
	dialogue_layer.add_child(dialogue)
	var recruiter_script := load("res://tests/fixtures/nugget_bridge_recruiter_probe.gd") as GDScript
	var recruiter_scene := load("res://scenes/npcs/trainer_npc.tscn") as PackedScene
	var recruiter := recruiter_scene.instantiate() as Node2D
	recruiter.set_script(recruiter_script)
	scene.add_child(recruiter)
	recruiter.trainer_progress_loaded = true
	var player := Node2D.new()
	player.name = "Player"
	scene.add_child(player)
	recruiter.vision_candidate = player
	recruiter.triggered = true
	recruiter.battle_in_progress = true
	game_state.call("lock_overworld_input")
	recruiter.show_intro_dialogue()
	_check(dialogue.shown == 1, "recruiter displays a rejected reward once")
	for frame in range(3):
		await process_frame
		_check(not recruiter._can_auto_challenge(), "recruiter suppresses vision retries while reward error is open")
	dialogue.dialogue_finished.emit()
	_check(not bool(game_state.call("is_overworld_input_locked")), "closing the reward error restores overworld movement")
	_check(not recruiter.battle_in_progress and not recruiter.triggered, "reward failure releases recruiter interaction ownership")
	_check(recruiter.vision_candidate == null, "reward failure clears the recruiter vision candidate")
	_check(not recruiter._can_auto_challenge(), "reward error stays dismissed while the player remains in sight")
	recruiter.interact_with_player(player)
	_check(dialogue.shown == 2, "player can manually retry the recruiter after a reward failure")
	dialogue.dialogue_finished.emit()
	_check(not bool(game_state.call("is_overworld_input_locked")), "failed manual retry also restores movement")
	_check(not recruiter.revealed, "rejected reward does not reveal Rocket or start a battle")
	var reward_requests_before: int = recruiter.reward_requests
	recruiter.progress_response = {"success": false, "error": "Progress temporarily unavailable."}
	recruiter.trainer_progress_state = "first_encounter"
	game_state.call("lock_overworld_input")
	recruiter.show_intro_dialogue()
	_check(recruiter.reward_requests == reward_requests_before, "unknown recruiter progress never attempts another prize claim")
	_check(not recruiter._can_auto_challenge(), "unavailable recruiter progress blocks automatic first-encounter replay")
	dialogue.dialogue_finished.emit()
	_check(not bool(game_state.call("is_overworld_input_locked")), "unavailable recruiter progress restores movement")

	# A retry now learns that this recruiter was already defeated before this map load.
	recruiter.progress_response = {"success": true, "progress": {"state": "completed", "firstDefeated": true}}
	await recruiter.interact_with_player(player)
	_check(recruiter.last_dialogue_id == "kanto_route_24_rocket_recruiter_completed", "saved recruiter victory selects the follow-up dialogue on retry")
	_check(recruiter.last_speaker == "Team Rocket Recruiter" and recruiter.revealed, "defeated recruiter speaks as Team Rocket without replaying the disguise")
	_check(recruiter.reward_requests == reward_requests_before, "saved recruiter victory bypasses the prize claim")
	_check(not recruiter._can_auto_challenge(), "defeated recruiter never automatically challenges again")
	var error_count: int = dialogue.shown
	await recruiter.interact_with_player(player)
	_check(recruiter.last_dialogue_id == "kanto_route_24_rocket_recruiter_completed", "repeat interaction keeps the Rocket follow-up dialogue")
	_check(dialogue.shown == error_count and recruiter.reward_requests == reward_requests_before, "repeat interaction starts no reward request or System error")

	# Losing a later lookup must preserve completion that was already confirmed.
	recruiter.progress_response = {"success": false, "error": "Progress temporarily unavailable."}
	await recruiter._load_trainer_progress()
	_check(recruiter.trainer_progress_state == "completed" and recruiter.revealed, "failed refresh preserves known recruiter completion and identity")
	await recruiter.interact_with_player(player)
	_check(recruiter.reward_requests == reward_requests_before, "failed refresh cannot reopen a completed recruiter prize")
	current_scene = null
	scene.queue_free()
	await process_frame
