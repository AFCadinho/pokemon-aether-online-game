@tool
extends DialogueNPC

const CHALLENGE_MENU := preload("res://scripts/ui/aether_clash_bot_challenge_menu.gd")
var interaction_in_flight := false


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false


func interact_with_player(_player: Node2D) -> void:
	if interaction_in_flight:
		return
	interaction_in_flight = true
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("_publish_world_presence"):
		world.call("_publish_world_presence", true)
	var response := await _load_training_options()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "ui.clash_bot.unavailable")
		interaction_in_flight = false
		return
	var menu := CHALLENGE_MENU.new()
	add_child(menu)
	var settings: Dictionary = await menu.choose(response.get("options", {}))
	menu.queue_free()
	if bool(settings.get("resetReward", false)):
		var reset_result := await _reset_training_reward()
		if bool(reset_result.get("success", false)):
			var reset_done := bool(reset_result.get("body", {}).get("reset", false))
			await show_dialogue([LocalizationManager.text("ui.clash_bot.reset_done" if reset_done else "ui.clash_bot.reset_not_needed")], display_name)
		else:
			await GameErrorDialogService.show_response(reset_result, "ui.clash_bot.reset_unavailable")
		interaction_in_flight = false
		return
	if not settings.is_empty():
		var result := await _create_training_challenge(
			int(settings["botCount"]), str(settings["tierId"]), str(settings["spectatorAccess"]),
			str(settings["aiPolicy"]), bool(settings.get("rewardAttempt", false))
		)
		if bool(result.get("success", false)):
			await show_dialogue([LocalizationManager.text("ui.clash_bot.accepted")], display_name)
		else:
			await GameErrorDialogService.show_response(result, "ui.clash_bot.unavailable")
	interaction_in_flight = false


func _load_training_options() -> Dictionary:
	return await GuildService.load_aether_clash_bot_options()


func _reset_training_reward() -> Dictionary:
	return await GuildService.reset_aether_clash_bot_reward_for_development()


func _create_training_challenge(count: int, tier_id: String, access: String, ai_policy: String, reward_attempt: bool) -> Dictionary:
	return await GuildService.create_aether_clash_bot_challenge(count, tier_id, access, ai_policy, reward_attempt)
