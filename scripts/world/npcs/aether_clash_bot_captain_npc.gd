@tool
extends DialogueNPC

const CHALLENGE_MENU := preload("res://scripts/ui/aether_clash_bot_challenge_menu.gd")
const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
var interaction_in_flight := false
signal training_choice_resolved(action: String)


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false


func interact_with_player(_player: Node2D) -> void:
	if interaction_in_flight:
		return
	interaction_in_flight = true
	while true:
		var action := await _show_training_choice()
		if action == "explain":
			await show_dialogue(_training_explanation(), display_name)
			continue
		if action == "money_reward":
			await show_dialogue(_money_reward_explanation(), display_name)
			continue
		if action != "challenge":
			interaction_in_flight = false
			return
		break
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


func _show_training_choice() -> String:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	var choice := OptionButton.new()
	choice.add_item(LocalizationManager.text("ui.clash_bot.choice_challenge"))
	choice.add_item(LocalizationManager.text("ui.clash_bot.choice_explain"))
	choice.add_item(LocalizationManager.text("ui.clash_bot.choice_money_reward"))
	choice.custom_minimum_size = Vector2(0, 42)
	dialog.add_custom_control(choice)
	dialog.style_option_button(choice)
	dialog.configure(
		display_name,
		LocalizationManager.text("ui.clash_bot.choice_prompt"),
		LocalizationManager.text("ui.clash_bot.choice_continue"),
		LocalizationManager.text("ui.clash_bot.choice_close")
	)
	dialog.confirmed.connect(func(): training_choice_resolved.emit([
		"challenge", "explain", "money_reward"
	][clampi(choice.selected, 0, 2)]), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): training_choice_resolved.emit("close"), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 300))
	var action: String = await training_choice_resolved
	layer.queue_free()
	return action


func _training_explanation() -> Array[String]:
	return [
		LocalizationManager.text("ui.clash_bot.explain_1"),
		LocalizationManager.text("ui.clash_bot.explain_2"),
		LocalizationManager.text("ui.clash_bot.explain_3"),
		LocalizationManager.text("ui.clash_bot.explain_4"),
	]


func _money_reward_explanation() -> Array[String]:
	return [
		LocalizationManager.text("ui.clash_bot.money_explain_1"),
		LocalizationManager.text("ui.clash_bot.money_explain_2"),
		LocalizationManager.text("ui.clash_bot.money_explain_3"),
		LocalizationManager.text("ui.clash_bot.money_explain_4"),
	]


func _load_training_options() -> Dictionary:
	return await GuildService.load_aether_clash_bot_options()


func _reset_training_reward() -> Dictionary:
	return await GuildService.reset_aether_clash_bot_reward_for_development()


func _create_training_challenge(count: int, tier_id: String, access: String, ai_policy: String, reward_attempt: bool) -> Dictionary:
	return await GuildService.create_aether_clash_bot_challenge(count, tier_id, access, ai_policy, reward_attempt)
