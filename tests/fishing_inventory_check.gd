extends SceneTree

const FishingRodRulesScript := preload("res://scripts/services/fishing_rod_rules.gd")
const INVENTORY_SERVICE_PATH := "res://scripts/services/inventory_service.gd"
const GAME_STATE_PATH := "res://scripts/core/game_state.gd"

var failed := false


func _init() -> void:
	_check_equal(FishingRodRulesScript.resolve_tier([]), 0, "no rod disables fishing")
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "old-rod", "quantity": 1},
			{"itemId": "potion", "quantity": 10},
		]),
		1,
		"Old Rod grants tier one"
	)
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "old-rod", "quantity": 1},
			{"itemId": "good-rod", "quantity": 1},
			{"itemId": "super-rod", "quantity": 0},
		]),
		2,
		"highest owned positive-quantity rod wins"
	)
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "super-rod", "quantity": 1},
		]),
		3,
		"Super Rod grants tier three"
	)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_PATH)
	var game_state_source := FileAccess.get_file_as_string(GAME_STATE_PATH)
	_check(
		inventory_source.contains('const FISHING_PROGRESSION_ENDPOINT := "/game/fishing/progression"')
		and inventory_source.contains('const FISHING_SELECTION_ENDPOINT := "/game/fishing/selection"'),
		"fishing progression and selection use dedicated server endpoints"
	)
	_check(
		inventory_source.contains("GameState.fishing_unlocked = bool(progression.get(\"selectedRodUsable\", false))")
		and not inventory_source.contains("GameState.fishing_unlocked = tier > 0"),
		"server progression, not highest inventory tier, controls fishing access"
	)
	_check(
		game_state_source.contains("var fishing_level := 1")
		and game_state_source.contains("var selected_fishing_rod_item_id := \"\"")
		and game_state_source.contains("var fishing_rods: Array = []"),
		"game state tracks fishing level, selection, and rod availability"
	)
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
