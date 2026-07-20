extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BattleForceSwitchFlowScript := preload("res://scripts/battle/battle_force_switch_flow.gd")
const BATTLE_ACTION_FLOW_PATH := "res://scripts/battle/battle_action_flow.gd"

var failed := false


func _init() -> void:
	_check_damage_response_is_display_deferred()
	_check_deferred_damage_load_rewinds_to_previous_hp()
	_check_newer_damage_and_faint_override_hp_memory()
	_check_stale_switch_event_does_not_revive_canonical_faint()
	_check_pursuit_faint_keeps_pending_iron_treads_available()
	_check_historical_switch_renders_before_its_faint()
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


func _check_newer_damage_and_faint_override_hp_memory() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response(_single_pokemon_response("hp-memory-test", "68/100", 68, false), false)

	state.load_from_api_response(_single_pokemon_response("hp-memory-test", "40/100", 40, false), false)
	_check_equal(state.get_active_pokemon_current_hp("p1"), 40, "newer lower HP overrides remembered HP")

	state.load_from_api_response(_single_pokemon_response("hp-memory-test", "0 fnt", 0, true), false)
	_check_equal(state.get_active_pokemon_current_hp("p1"), 0, "newer faint overrides remembered HP")
	_check_equal(state.is_active_pokemon_fainted("p1"), true, "newer faint remains authoritative")


func _single_pokemon_response(battle_id: String, condition: String, hp: int, fainted: bool) -> Dictionary:
	return {
		"success": true,
		"battleId": battle_id,
		"requests": {
			"p1": {
				"side": {
					"pokemon": [{
						"ident": "p1: Tyranitar", "species": "Tyranitar", "active": true,
						"condition": condition, "hp": hp, "maxHp": 100, "fainted": fainted,
						"metadataSlot": 1, "pokemonKey": "p1:slot:1",
					}],
				},
			},
		},
		"events": [],
	}


func _check_stale_switch_event_does_not_revive_canonical_faint() -> void:
	var state = BattleStateScript.new()
	# Prime the presentation memory with the state that existed before Pursuit
	# interrupted the switch. This is the production sequence that used to
	# overwrite the next canonical faint snapshot.
	state.load_from_api_response({
		"success": true,
		"battleId": "pursuit-switch-faint-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Ceruledge", "species": "Ceruledge", "active": true,
							"condition": "72/100", "hp": 72, "maxHp": 100, "fainted": false,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
						{
							"ident": "p1: Mawile", "species": "Mawile", "active": false,
							"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
							"metadataSlot": 3, "pokemonKey": "p1:slot:3",
						},
					],
				},
			},
		},
		"events": [],
	}, true)

	state.load_from_api_response({
		"success": true,
		"battleId": "pursuit-switch-faint-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Ceruledge", "species": "Ceruledge", "active": false,
							"condition": "0 fnt", "hp": 0, "maxHp": 100, "fainted": true,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
						{
							"ident": "p1: Mawile", "species": "Mawile", "active": true,
							"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
							"metadataSlot": 3, "pokemonKey": "p1:slot:3",
						},
					],
				},
			},
		},
		"events": [{
			"type": "switch", "pokemon": "p1a: Ceruledge", "condition": "72/100",
			"metadataSlot": 2, "pokemonKey": "p1:slot:2",
		}],
	}, true)

	var team: Array = state.get_player_team("p1")
	_check_equal(bool((team[0] as Dictionary).get("fainted", false)), true, "stale Pursuit switch event keeps Ceruledge fainted")
	_check_equal(int((team[0] as Dictionary).get("hp", -1)), 0, "stale Pursuit switch event keeps Ceruledge at zero HP")
	_check_equal(bool((team[0] as Dictionary).get("active", true)), false, "stale Pursuit switch event cannot reactivate Ceruledge")
	_check_equal(bool((team[1] as Dictionary).get("active", false)), true, "canonical active Pokemon remains active")


func _check_pursuit_faint_keeps_pending_iron_treads_available() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "pursuit-pending-switch-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Ceruledge", "species": "Ceruledge", "active": true,
							"condition": "72/100", "hp": 72, "maxHp": 100, "fainted": false,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
						{
							"ident": "p1: Iron Treads", "species": "Iron Treads", "active": false,
							"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
							"metadataSlot": 6, "pokemonKey": "p1:slot:6",
						},
					],
				},
			},
		},
		"events": [],
	}, true)

	var pursuit_events: Array = [
		{
			"type": "damage", "target": "p1a: Ceruledge",
			"previousCondition": "72/100", "condition": "0 fnt",
			"previousHp": 72, "hp": 0, "maxHp": 100,
			"metadataSlot": 2, "pokemonKey": "p1:slot:2",
			"targetRef": {"metadataSlot": 2, "pokemonKey": "p1:slot:2"},
		},
		{
			"type": "faint", "target": "p1a: Ceruledge", "condition": "0 fnt",
			"metadataSlot": 2, "pokemonKey": "p1:slot:2",
			"targetRef": {"metadataSlot": 2, "pokemonKey": "p1:slot:2"},
		},
	]
	state.load_from_api_response({
		"success": true,
		"battleId": "pursuit-pending-switch-test",
		"requests": {
			"p1": {
				"forceSwitch": [true],
				"side": {
					"pokemon": [
						{
							"ident": "p1: Ceruledge", "species": "Ceruledge", "active": true,
							"condition": "0 fnt", "hp": 0, "maxHp": 100, "fainted": true,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
						{
							"ident": "p1: Iron Treads", "species": "Iron Treads", "active": false,
							"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
							"metadataSlot": 6, "pokemonKey": "p1:slot:6",
						},
					],
				},
			},
		},
		"events": pursuit_events,
	}, false)
	state.apply_event_conditions(pursuit_events)

	var team: Array = state.get_player_team("p1")
	_check_equal(bool((team[0] as Dictionary).get("fainted", false)), true, "Pursuit faints Ceruledge")
	_check_equal(bool((team[1] as Dictionary).get("fainted", true)), false, "Pursuit never faints pending Iron Treads")
	_check_equal(int((team[1] as Dictionary).get("hp", 0)), 100, "pending Iron Treads keeps its HP")
	var force_switch_flow = BattleForceSwitchFlowScript.new()
	force_switch_flow.setup(state)
	_check_equal(force_switch_flow.can_switch_to_slot(2, "p1"), true, "pending Iron Treads remains selectable after Pursuit")


func _check_historical_switch_renders_before_its_faint() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "switch-then-faint-render-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Alomomola", "species": "Alomomola", "active": false,
							"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
						{
							"ident": "p1: Cinderace", "species": "Cinderace", "active": false,
							"condition": "0 fnt", "hp": 0, "maxHp": 100, "fainted": true,
							"metadataSlot": 6, "pokemonKey": "p1:slot:6",
						},
					],
				},
			},
		},
		"events": [],
	}, false)

	state.apply_event_conditions([{
		"type": "switch", "pokemon": "p1a: Cinderace", "condition": "100/100",
		"metadataSlot": 6, "pokemonKey": "p1:slot:6",
	}])
	var team_after_switch: Array = state.get_player_team("p1")
	_check_equal(bool((team_after_switch[1] as Dictionary).get("active", false)), true, "historical switch activates Cinderace during rendering")
	_check_equal(int((team_after_switch[1] as Dictionary).get("hp", -1)), 100, "historical switch restores its pre-faint HP during rendering")

	state.apply_event_conditions([{
		"type": "faint", "target": "p1a: Cinderace", "condition": "0 fnt",
		"metadataSlot": 6, "pokemonKey": "p1:slot:6",
	}])
	var team_after_faint: Array = state.get_player_team("p1")
	_check_equal(bool((team_after_faint[1] as Dictionary).get("fainted", false)), true, "later faint event re-applies Cinderace faint")
	_check_equal(int((team_after_faint[1] as Dictionary).get("hp", -1)), 0, "later faint event restores zero HP")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
