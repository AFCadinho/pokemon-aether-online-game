extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("unlock_input")
	game_state.call("unlock_overworld_input")
	var npc := (load("res://scenes/npcs/trainer_npc.tscn") as PackedScene).instantiate()
	npc.set_script(load("res://tests/support/rematch_completion_probe.gd"))
	root.add_child(npc)
	npc.add_to_group("trainer_npcs")
	var player := Node2D.new()
	root.add_child(player)
	npc.set("nearby_player", player)
	npc.set("player_nearby", true)
	npc.call("_apply_trainer_progress", {"state": "ready"}, "first_encounter")
	_check(bool(npc.call("_claim_battle_interaction")), "ready trainer claims the rematch")
	var trainer_id := str(npc.get("trainer_id"))
	npc.call("finish_trainer_battle", trainer_id, true)
	_check(bool(npc.get("battle_in_progress")), "won rematch remains locked while its reward response is pending")
	for _press in range(12):
		await _press_interact()
		if bool(npc.call("_can_start_manual_interaction")):
			await npc.call("interact_with_player", player)
		await _release_interact()
	_check(int(npc.get("battle_dialogues")) == 0, "space spam cannot start another battle during settlement")
	npc.call("apply_battle_victory_progress", trainer_id, {"state": "sleeping"})
	_check(not bool(npc.get("battle_in_progress")), "sleeping status releases battle ownership")
	_check(npc.get("trainer_progress_state") == "sleeping", "won rematch applies the sleeping state")
	var marker := npc.get("rematch_marker") as Control
	_check(marker.visible, "sleeping marker is visible after settlement")
	for _press in range(3):
		await _press_interact()
		if bool(npc.call("_can_start_manual_interaction")):
			await npc.call("interact_with_player", player)
		await _release_interact()
	_check(int(npc.get("sleeping_dialogues")) == 3, "space spam after settlement shows only the sleeping dialogue")
	_check(int(npc.get("battle_dialogues")) == 0, "sleeping trainer never starts a new battle")
	# A failed reward request releases the pending lock; the server decides
	# whether a later retry is eligible. A loss must not consume the rematch.
	npc.call("_apply_trainer_progress", {"state": "ready"}, "first_encounter")
	npc.call("_claim_battle_interaction")
	npc.call("finish_trainer_battle", trainer_id, true)
	var world := Node2D.new()
	root.add_child(world)
	world.set_script(load("res://scripts/world/world.gd"))
	world.set_process(false)
	# No session is configured in this isolated check. The real wallet service
	# returns a failed claim without issuing HTTP, exercising World's recovery.
	var failed_reward: Dictionary = await world.call(
		"_award_trainer_battle_rewards", "rematch-failure-fixture", trainer_id, "Fixture"
	)
	_check(not bool(failed_reward.get("success", true)), "failed wallet claim reaches World's recovery path")
	world.set_script(null)
	world.free()
	_check(not bool(npc.get("battle_in_progress")), "failed reward settlement releases the NPC")
	_check(npc.get("trainer_progress_state") == "ready", "lost or unsettled rematch stays available for a server-validated retry")
	# Developer rematches return the same ready projection instead of sleeping.
	npc.call("_claim_battle_interaction")
	npc.call("finish_trainer_battle", trainer_id, true)
	npc.call("apply_battle_victory_progress", trainer_id, {
		"state": "first_encounter", "developerRematchMode": true,
	})
	_check(npc.get("trainer_progress_state") == "ready", "developer rematch mode remains ready after settlement")
	_check(not bool(npc.get("battle_in_progress")), "developer rematch releases its pending lock")
	# Ordinary first wins stay defeated in this map until its next load.
	npc.call("_apply_trainer_progress", {"state": "first_encounter"}, "first_encounter")
	npc.call("_claim_battle_interaction")
	npc.call("finish_trainer_battle", trainer_id, true)
	npc.call("apply_battle_victory_progress", trainer_id, {"state": "defeated"})
	await _press_interact()
	if bool(npc.call("_can_start_manual_interaction")):
		await npc.call("interact_with_player", player)
	await _release_interact()
	_check(int(npc.get("post_battle_dialogues")) == 1, "first victory keeps its post-battle dialogue until map reload")
	npc.free()
	player.free()
	quit(1 if failures > 0 else 0)


func _press_interact() -> void:
	Input.action_press("interact")
	if not Input.is_action_just_pressed("interact"):
		await process_frame


func _release_interact() -> void:
	Input.action_release("interact")
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
