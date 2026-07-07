extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BATTLE_ACTION_FLOW_PATH := "res://scripts/battle/battle_action_flow.gd"

var failed := false


func _init() -> void:
	_check_damage_response_is_display_deferred()
	_check_deferred_damage_load_rewinds_to_previous_hp()
	_check_status_event_normalizes_badly_poisoned()
	quit(1 if failed else 0)


func _check_damage_response_is_display_deferred() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_ACTION_FLOW_PATH)
	var function_index := source.find("func _response_has_deferred_display_event")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(
		function_source.contains("event_type == \"damage\""),
		true,
		"damage responses defer display-state application"
	)


func _check_deferred_damage_load_rewinds_to_previous_hp() -> void:
	var state = BattleStateScript.new()
	var damage_event := {
		"type": "damage",
		"target": "p2a: Garchomp",
		"pokemonKey": "p2:slot:6",
		"metadataSlot": 6,
		"previousCondition": "100/100",
		"condition": "0 fnt",
		"previousHp": 100,
		"hp": 0,
		"maxHp": 100,
	}

	state.load_from_api_response({
		"success": true,
		"battleId": "deferred-hp-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2: Garchomp",
						"species": "Garchomp",
						"active": true,
						"condition": "0 fnt",
						"hp": 0,
						"maxHp": 100,
						"fainted": true,
						"metadataSlot": 6,
						"pokemonKey": "p2:slot:6",
					}],
				},
			},
		},
		"events": [damage_event],
	}, false)

	_check_equal(state.get_active_pokemon_current_hp("p2"), 100, "deferred load restores previous active HP")
	_check_equal(state.is_active_pokemon_fainted("p2"), false, "deferred load clears premature faint")

	state.apply_event_conditions([damage_event])
	_check_equal(state.get_active_pokemon_current_hp("p2"), 0, "damage event applies final HP")
	_check_equal(state.is_active_pokemon_fainted("p2"), true, "damage event applies fainted state")


func _check_status_event_normalizes_badly_poisoned() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "status-normalization-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2: Magikarp",
						"species": "Magikarp",
						"active": true,
						"condition": "100/100",
						"hp": 100,
						"maxHp": 100,
						"metadataSlot": 1,
						"pokemonKey": "p2:slot:1",
					}],
				},
			},
		},
		"events": [],
	}, false)

	state.apply_event_conditions([{
		"type": "status",
		"target": "p2a: Magikarp",
		"status": "Badly Poisoned",
		"state": "start",
	}])

	_check_equal(state.get_active_pokemon_status("p2"), "tox", "badly poisoned status normalizes to tox")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
