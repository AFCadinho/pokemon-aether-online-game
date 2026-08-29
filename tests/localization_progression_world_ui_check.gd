extends SceneTree

const FISHING_SCRIPT_PATH := "res://scripts/ui/fishing_action_controller.gd"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"

var failed := false
var localization_manager: Node
var game_state: Node
var settings_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	game_state = root.get_node_or_null("GameState")
	settings_manager = root.get_node_or_null("SettingsManager")
	_check(localization_manager != null, "Progression localization check can access LocalizationManager")
	_check(game_state != null, "Progression localization check can access GameState")
	_check(settings_manager != null, "Progression localization check can access SettingsManager")
	if localization_manager == null or game_state == null or settings_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var original_content_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	var original_rod := str(game_state.get("selected_fishing_rod_item_id"))
	var original_region := str(game_state.get("fishing_region"))
	_check_runtime_copy()
	_check_source_contracts()
	game_state.set("selected_fishing_rod_item_id", original_rod)
	game_state.set("fishing_region", original_region)
	settings_manager.set("content_name_language", original_content_name_language)
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_runtime_copy() -> void:
	var fishing_script := load(FISHING_SCRIPT_PATH) as Script
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	_check(fishing_script != null and overlay_script != null and world_script != null, "Progression scripts load")
	if fishing_script == null or overlay_script == null or world_script == null:
		return

	var fishing: Node = fishing_script.new()
	var overlay: Node = overlay_script.new()
	var world: Node = world_script.new()
	var unavailable_rod := {
		"itemId": "old-rod",
		"name": "Old Rod",
		"owned": false,
		"usable": false,
		"levelRequirementMet": true,
		"badgeRequirementMet": true,
		"requiredLevel": 1,
		"requiredBadges": 0,
	}
	game_state.set("selected_fishing_rod_item_id", "")
	game_state.set("fishing_region", "kanto")

	localization_manager.call("set_locale", "nl")
	var system_messages: Array = world.call("_story_reward_item_messages", [{
		"alreadyGranted": false,
		"grants": [{"itemId": "tm-rock-slide", "quantity": 1}],
	}])
	_check(
		system_messages == ["Je hebt 1 × TM-rotsglijbaan ontvangen!"],
		"Story item rewards name the localized Rock Slide TM in the Dutch System message"
	)
	var replay_messages: Array = world.call("_story_reward_item_messages", [{
		"alreadyGranted": true,
		"grants": [{"itemId": "tm-rock-slide", "quantity": 1}],
	}])
	_check(replay_messages.is_empty(), "Replayed story rewards do not duplicate System messages")
	_check(fishing.call("_rod_button_text", unavailable_rod) == "Old Rod — Niet in bezit", "Fishing rod state renders in Dutch")
	_check(
		fishing.call("_rod_tooltip", unavailable_rod) == "Vislevel 1 • 0 regionale badges",
		"Fishing requirements render in Dutch"
	)
	_check(
		overlay.call("_move_learn_prompt_move_name", {"moveId": "flamethrower", "name": "Flamethrower"}) == "Vlammenwerper",
		"Move-learning names render in Dutch"
	)
	_check(world.call("_format_effort_stat_label", "spe") == "SNELHEID", "Reward stat labels render in Dutch")
	_check(
		localization_manager.call("text", "ui.reward_card.level_up") == "Level omhoog"
		and localization_manager.call("text", "ui.reward_card.caught") == "Gevangen",
		"Pokemon reward-card events render in Dutch"
	)
	var reward_identity: Dictionary = overlay.call("_pokemon_reward_identity", {
		"species": "Pikachu",
		"nickname": "Sparky",
		"shiny": true,
	})
	_check(
		str(reward_identity.get("title", "")) == "Sparky"
		and str(reward_identity.get("species", "")) == "Pikachu"
		and bool(reward_identity.get("shiny", false)),
		"Pokemon reward cards preserve nickname, species, and Shiny identity"
	)
	_check(
		localization_manager.call("text", "ui.evolution.available", {"from": "Pidgey", "to": "Pidgeotto"})
			== "Pidgey kan evolueren in Pidgeotto.",
		"Evolution prompt renders in Dutch"
	)
	_check(
		localization_manager.call("text", "ui.skills.unlock.old_rod_tentacool")
			== "Level 5 Tentacool met de Old Rod",
		"Old Rod Tentacool unlock is not tied to Pallet Town"
	)

	localization_manager.call("set_locale", "pt_BR")
	_check(fishing.call("_rod_button_text", unavailable_rod) == "Vara Velha — Não possuída", "Fishing rod state updates to Portuguese")
	_check(
		overlay.call("_move_learn_prompt_move_name", {"moveId": "flamethrower", "name": "Flamethrower"}) == "Lança-Chamas",
		"Move-learning names update to Portuguese"
	)
	_check(world.call("_localized_gym_badge_name", "boulder") == "Insígnia da Rocha", "Gym Badge rewards update to Portuguese")
	_check(
		localization_manager.call("text", "ui.skills.unlock.old_rod_tentacool")
			== "Tentacool de nível 5 com a Vara Velha",
		"Old Rod Tentacool unlock stays location-independent in Portuguese"
	)
	_check(
		localization_manager.call("text", "ui.world.capture.caught_party", {"pokemon": "Pikachu"})
			== "Você capturou Pikachu! Adicionado à sua equipe.",
		"Capture feedback updates to Portuguese"
	)
	_check(
		localization_manager.call("text", "ui.reward_card.level_up") == "Subiu de nível"
		and localization_manager.call("text", "ui.reward_card.caught") == "Capturado",
		"Pokemon reward-card events update to Portuguese"
	)

	fishing.free()
	overlay.free()
	world.free()


func _check_source_contracts() -> void:
	var fishing_source := FileAccess.get_file_as_string(FISHING_SCRIPT_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(fishing_source.contains('"ui.fishing.rod.badges_required"'), "Fishing requirements use semantic keys")
	_check(fishing_source.contains("LocalizationManager.locale_changed.connect"), "Fishing UI supports live locale switching")
	_check(overlay_source.contains('"ui.evolution.overlay.complete"'), "Evolution overlay uses semantic keys")
	_check(overlay_source.contains('"ui.move_learning.result.replaced"'), "Move-learning result uses semantic keys")
	_check(world_source.contains('"ui.world.blackout.respawned"'), "Blackout feedback uses semantic keys")
	_check(world_source.contains('"ui.world.reward.level_up"'), "Progression rewards use semantic keys")


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
