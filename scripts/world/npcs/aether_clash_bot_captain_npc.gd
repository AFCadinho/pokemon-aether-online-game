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
	var response := await _load_training_options()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "ui.clash_bot.unavailable")
		interaction_in_flight = false
		return
	var menu := CHALLENGE_MENU.new()
	add_child(menu)
	var settings: Dictionary = await menu.choose(response.get("options", {}))
	menu.queue_free()
	if not settings.is_empty():
		var result := await _create_training_challenge(
			int(settings["botCount"]), str(settings["tierId"]), str(settings["spectatorAccess"])
		)
		if bool(result.get("success", false)):
			await show_dialogue([LocalizationManager.text("ui.clash_bot.accepted")], display_name)
		else:
			await GameErrorDialogService.show_response(result, "ui.clash_bot.unavailable")
	interaction_in_flight = false


func _load_training_options() -> Dictionary:
	return await GuildService.load_aether_clash_bot_options()


func _create_training_challenge(count: int, tier_id: String, access: String) -> Dictionary:
	return await GuildService.create_aether_clash_bot_challenge(count, tier_id, access)
