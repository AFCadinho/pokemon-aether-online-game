extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	var overlay = load("res://tests/support/coop_progression_probe.gd").new()
	# No scene/UI setup is needed to exercise the real reward and prompt queues.
	var reward := [{"battleId": "coop-test", "reward": {
		"moveLearnPrompts": [{"pokemonId": 77, "moveId": "gust", "species": "Pidgey"}, {"pokemonId": 77, "moveId": "quick-attack", "species": "Pidgey"}],
		"evolutionPrompts": [{"pokemonId": 77, "toSpeciesId": "pidgeotto", "fromSpecies": "Pidgey"}]}}]
	overlay.queue_coop_progression_rewards(reward)
	_check(overlay.move_learn_queue.size() == 2, "all crossed level-up moves enter the normal learning queue")
	_check(overlay.evolution_prompt_queue.size() == 1, "evolution enters the normal queue after moves")
	overlay.queue_coop_progression_rewards(reward)
	_check(overlay.move_learn_queue.size() == 2 and overlay.evolution_prompt_queue.size() == 1, "repeated polls do not duplicate choices")
	overlay.move_learn_active_prompt = overlay.move_learn_queue.pop_front()
	overlay.queue_coop_progression_rewards(reward)
	_check(overlay.move_learn_queue.size() == 1, "active choices are not requeued")
	overlay.move_learn_active_prompt.clear()
	overlay.move_learn_queue.clear()
	overlay.evolution_prompt_queue.clear()
	overlay.queue_coop_progression_rewards(reward)
	_check(overlay.move_learn_queue.is_empty() and overlay.evolution_prompt_queue.is_empty(), "late stale polls cannot reopen completed choices in this overlay")
	# A new world/connection must replay choices that the server still has open.
	overlay.coop_progression_seen.clear()
	overlay.queue_coop_progression_rewards(reward)
	_check(overlay.move_learn_queue.size() == 2, "new overlay recovers still-open server choices")
	var evolution_move := {"pokemonId": 77, "moveId": "wing-attack", "species": "Pidgeotto"}
	overlay._queue_move_learn_prompt(evolution_move)
	overlay.queue_coop_progression_rewards([{"battleId": "coop-test", "reward": {"moveLearnPrompts": [evolution_move]}}])
	_check(overlay.move_learn_queue.size() == 3, "durable evolution moves do not duplicate the direct evolution response")
	var missing := reward.duplicate(true)
	missing[0]["battleId"] = "coop-missing"
	missing[0]["reward"]["moveLearnPrompts"][0]["pokemonId"] = 99
	overlay.queue_coop_progression_rewards(missing)
	_check(overlay.move_learn_queue.size() == 3, "another Pokemon's choice cannot attach to this party member")
	overlay.pokemon_summary_sprite_loader.free()
	overlay.pokedex_sprite_loader.free()
	overlay.free()
	var coop := root.get_node("CoopService")
	coop.apply_state({"pendingProgressionRewards": reward})
	_check(coop.pending_progression_rewards == reward, "polling retains durable rewards even without a current party activity")
	coop.reset()
	_check(coop.pending_progression_rewards.is_empty(), "logout clears the previous account's rewards")
	if failures == 0:
		print("COOP_PROGRESSION_PROMPT_PASS")
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS " + message)
	else:
		failures += 1
		push_error(message)
