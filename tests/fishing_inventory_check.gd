extends SceneTree

const INVENTORY_SERVICE_PATH := "res://scripts/services/inventory_service.gd"
const GAME_STATE_PATH := "res://scripts/core/game_state.gd"

var failed := false


func _init() -> void:
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_PATH)
	var game_state_source := FileAccess.get_file_as_string(GAME_STATE_PATH)
	_check(
		inventory_source.contains('const FISHING_PROGRESSION_ENDPOINT := "/game/fishing/progression"')
		and inventory_source.contains('const FISHING_SELECTION_ENDPOINT := "/game/fishing/selection"'),
		"fishing progression and selection use dedicated server endpoints"
	)
	_check(
		inventory_source.contains('GameState.fishing_skill_unlocked = bool(progression.get("unlocked", false))')
		and game_state_source.contains("var fishing_skill_unlocked := false"),
		"Fishing skill unlock is tracked separately from the selected rod"
	)
	_check(
		inventory_source.contains("GameState.fishing_unlocked = bool(progression.get(\"selectedRodUsable\", false))")
		and inventory_source.contains('GameState.fishing_rods = _array_from_value(progression.get("rods", []))')
		and inventory_source.contains('get_tree().call_group("player", "refresh_fishing_prompt")')
		and not inventory_source.contains("_set_fishing_access_from_items"),
		"server progression, not highest inventory tier, controls fishing access"
	)
	_check(
		not inventory_source.contains('return {"success": false, "error": "Missing fishing rod item id."}')
		and inventory_source.contains('"itemId": normalized_item_id'),
		"an empty fishing rod selection can be persisted as fishing inactive"
	)
	_check(
		not inventory_source.contains('preload("res://scripts/services/fishing_rod_rules.gd")'),
		"inventory no longer carries legacy client-side fishing rod rules"
	)
	_check(
		game_state_source.contains("var fishing_level := 1")
		and game_state_source.contains("var selected_fishing_rod_item_id := \"\"")
		and game_state_source.contains("var fishing_rods: Array = []"),
		"game state tracks fishing level, selection, and rod availability"
	)
	_check(
		not game_state_source.contains("fishing_owned_rod_item_ids"),
		"owned rod state is not duplicated outside the authoritative rod list"
	)
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
