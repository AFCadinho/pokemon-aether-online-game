extends SceneTree

const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const ERROR_LOCALIZATION_PATH := "res://scripts/services/backend_error_localization_service.gd"
const WALLET_SERVICE_PATH := "res://scripts/services/player_wallet_service.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	_check(game_state != null, "Level-cap check can access GameState")
	if game_state != null:
		game_state.call("apply_pokemon_level_cap_state", {
			"region": "kanto",
			"stageId": "before-first-gym",
			"badgeCount": 0,
			"levelCap": 18,
			"tradeLevelCap": 5,
		})
		_check(int(game_state.get("pokemon_level_cap")) == 18, "GameState applies the server level cap")
		_check(int(game_state.get("pokemon_trade_level_cap")) == 5, "GameState applies the server trade level cap")
		game_state.call("reset_gameplay_runtime_state")
		_check(int(game_state.get("pokemon_level_cap")) == 100, "Gameplay reset clears the cached level cap")
		_check(int(game_state.get("pokemon_trade_level_cap")) == 100, "Gameplay reset clears the cached trade level cap")

	var party_service := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	_check(
		party_service.contains('body.get("pokemonLevelCap", {})')
		and party_service.contains("GameState.apply_pokemon_level_cap_state"),
		"Party responses project the server level cap into GameState"
	)
	var wallet_service := FileAccess.get_file_as_string(WALLET_SERVICE_PATH)
	_check(
		wallet_service.contains('party.get("pokemonLevelCap", {})')
		and wallet_service.contains("GameState.apply_pokemon_level_cap_state"),
		"Battle rewards immediately apply a newly unlocked badge cap"
	)

	var overlay := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(
		overlay.contains("GameState.pokemon_level_cap")
		and overlay.contains("player_level_cap - current_level"),
		"Bag EXP previews use the current player level cap"
	)
	_check(
		overlay.contains("func _create_trainer_card_caps_panel()")
		and overlay.contains("GameState.pokemon_trade_level_cap")
		and overlay.contains("_pokemon_exp_for_level(growth_rate, player_level_cap + 1) - 1"),
		"Trainer Card displays both progression caps"
	)

	var error_localization := FileAccess.get_file_as_string(ERROR_LOCALIZATION_PATH)
	_check(
		error_localization.contains('"pokemon_level_cap_reached"')
		and error_localization.contains('"pokemon_level_cap_party_ineligible"'),
		"Level-cap backend errors have localized mappings"
	)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
