extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BattleForceSwitchFlowScript := preload("res://scripts/battle/battle_force_switch_flow.gd")
const BATTLE_ACTION_FLOW_PATH := "res://scripts/battle/battle_action_flow.gd"

var failed := false


func _init() -> void:
	_check_damage_response_is_display_deferred()
	_check_forme_change_response_is_display_deferred()
	_check_deferred_damage_load_rewinds_to_previous_hp()
	_check_deferred_mimikyu_forme_change_keeps_disguise_until_event()
	_check_newer_damage_and_faint_override_hp_memory()
	_check_stale_switch_event_does_not_revive_canonical_faint()
	_check_pursuit_faint_keeps_pending_iron_treads_available()
	_check_historical_switch_renders_before_its_faint()
	_check_double_faint_switch_restores_public_opponent_level()
	_check_entry_hazard_faint_preserves_chained_force_switch()
	_check_pivot_ko_waiting_player_does_not_infer_force_switch()
	_check_status_event_normalizes_badly_poisoned()
	_check_public_mimikyu_status_updates_disguised_roster_entry()
	_check_public_mimikyu_forme_change_updates_active_sprite_species()
	_check_mimikyu_disguise_state_labels()
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


func _check_forme_change_response_is_display_deferred() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_ACTION_FLOW_PATH)
	var function_index := source.find("func _response_has_deferred_display_event")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(
		function_source.contains("event_type == \"formeChange\""),
		true,
		"forme changes defer display-state application"
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


func _check_deferred_mimikyu_forme_change_keeps_disguise_until_event() -> void:
	var state = BattleStateScript.new()
	var forme_change_event := {
		"type": "formeChange",
		"target": "p2a: Mimikyu-Busted",
		"species": "Mimikyu-Busted",
	}
	state.load_from_api_response({
		"success": true,
		"battleId": "deferred-mimikyu-forme-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2: Mimikyu",
						"species": "Mimikyu-Disguised",
						"displaySpecies": "Mimikyu-Disguised",
						"active": true,
						"condition": "100/100",
					}],
				},
			},
		},
		"events": [],
	}, true)

	state.load_from_api_response({
		"success": true,
		"battleId": "deferred-mimikyu-forme-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2: Mimikyu-Busted",
						"species": "Mimikyu-Busted",
						"displaySpecies": "Mimikyu-Busted",
						"active": true,
						"condition": "100/100",
					}],
				},
			},
		},
		"events": [forme_change_event],
	}, false)

	_check_equal(state.get_active_pokemon_species("p2"), "Mimikyu-Disguised", "deferred response preserves the actually visible Mimikyu form even when the new ident is already Busted")
	state.apply_event_conditions([forme_change_event])
	_check_equal(state.get_active_pokemon_species("p2"), "Mimikyu-Busted", "ordered forme event reveals Mimikyu's busted form")


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


func _check_public_mimikyu_status_updates_disguised_roster_entry() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "mimikyu-public-form-status-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [{
						"ident": "p1: Mimikyu Disguised",
						"species": "Mimikyu Disguised",
						"displaySpecies": "Mimikyu Disguised",
						"active": true,
						"condition": "100/100",
						"hp": 100,
						"maxHp": 100,
					}],
				},
			},
		},
		"events": [],
	}, false)

	state.apply_event_conditions([{
		"type": "status",
		"target": "p1a: Mimikyu",
		"status": "par",
		"state": "start",
	}])

	var mimikyu: Dictionary = state.get_player_team("p1")[0]
	_check_equal(mimikyu.get("status", ""), "par", "public base Mimikyu status updates disguised roster form")
	_check_equal(mimikyu.get("condition", ""), "100/100 par", "Mimikyu roster condition retains public paralysis")

	state.apply_event_conditions([{
		"type": "switch",
		"target": "p1a: Mimikyu",
		"species": "Mimikyu-Busted",
		"displaySpecies": "Mimikyu-Busted",
		"condition": "88/100 par",
	}])
	mimikyu = state.get_player_team("p1")[0]
	_check_equal(mimikyu.get("displaySpecies", ""), "Mimikyu-Busted", "public busted form keeps the same roster entry")
	_check_equal(mimikyu.get("status", ""), "par", "public busted switch condition retains paralysis")


func _check_public_mimikyu_forme_change_updates_active_sprite_species() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "mimikyu-public-forme-change-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Mimikyu",
							"species": "Mimikyu-Disguised",
							"displaySpecies": "Mimikyu-Disguised",
							"active": true,
							"condition": "100/100",
						},
					],
				},
			},
		},
	}, true)
	state.apply_event_conditions([
		{
			"type": "formeChange",
			"target": "p1a: Mimikyu",
			"species": "Mimikyu-Busted",
		},
	])

	_check_equal(state.get_active_pokemon_species("p1"), "Mimikyu-Busted", "ordered forme change updates active Mimikyu display species")


func _check_mimikyu_disguise_state_labels() -> void:
	_check_equal(BattleStateScript.get_mimikyu_disguise_state_for_species("Mimikyu-Disguised"), "active", "disguised Mimikyu exposes an active Disguise state")
	_check_equal(BattleStateScript.get_mimikyu_disguise_state_for_species("Mimikyu-Busted"), "inactive", "busted Mimikyu exposes an inactive Disguise state")
	_check_equal(BattleStateScript.get_mimikyu_disguise_state_for_species("Pikachu"), "", "non-Mimikyu species do not expose a Disguise state")


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


func _check_double_faint_switch_restores_public_opponent_level() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "double-faint-npc-switch-level-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [
						{
							"ident": "p1: Mankey", "species": "Mankey", "level": 11,
							"active": true, "condition": "1/28 psn", "hp": 1, "maxHp": 28,
							"metadataSlot": 1, "pokemonKey": "p1:slot:1",
						},
						{
							"ident": "p1: Pikipek", "species": "Pikipek", "level": 11,
							"active": false, "condition": "29/29", "hp": 29, "maxHp": 29,
							"metadataSlot": 2, "pokemonKey": "p1:slot:2",
						},
					],
				},
			},
			"p2": {
				"side": {
					"pokemon": [
						{
							"ident": "p2: Weedle", "species": "Weedle", "level": 6,
							"active": true, "condition": "1/18", "hp": 1, "maxHp": 18,
							"metadataSlot": 1, "pokemonKey": "p2:slot:1",
						},
						{
							"ident": "p2: Caterpie", "species": "Caterpie",
							"active": false, "condition": "18/18", "hp": 18, "maxHp": 18,
							"metadataSlot": 2, "pokemonKey": "p2:slot:2",
						},
					],
				},
			},
		},
		"events": [],
	}, true)

	state.apply_event_conditions([
		{
			"type": "damage", "target": "p2a: Weedle", "condition": "0 fnt",
			"hp": 0, "maxHp": 18, "metadataSlot": 1, "pokemonKey": "p2:slot:1",
		},
		{
			"type": "faint", "target": "p2a: Weedle", "condition": "0 fnt",
			"metadataSlot": 1, "pokemonKey": "p2:slot:1",
		},
		{
			"type": "damage", "target": "p1a: Mankey", "condition": "0 fnt",
			"hp": 0, "maxHp": 28, "metadataSlot": 1, "pokemonKey": "p1:slot:1",
		},
		{
			"type": "faint", "target": "p1a: Mankey", "condition": "0 fnt",
			"metadataSlot": 1, "pokemonKey": "p1:slot:1",
		},
		{
			"type": "switch", "pokemon": "p1a: Pikipek", "details": "Pikipek, L11",
			"condition": "29/29", "metadataSlot": 2, "pokemonKey": "p1:slot:2",
		},
		{
			"type": "switch", "pokemon": "p2a: Caterpie", "details": "Caterpie, L6",
			"condition": "18/18", "metadataSlot": 2, "pokemonKey": "p2:slot:2",
		},
	])

	_check_equal(state.get_active_pokemon_species("p2"), "Caterpie", "double faint activates the NPC replacement")
	_check_equal(state.get_active_pokemon_level("p2"), 6, "NPC switch details restore the public level before HUD refresh")

func _check_entry_hazard_faint_preserves_chained_force_switch() -> void:
	_check_equal(
		BattleForceSwitchFlowScript.should_preserve_chained_request(
			"awaiting_force_switch",
			true
		),
		true,
		"a hazard KO keeps the newly issued forced-switch request"
	)
	_check_equal(
		BattleForceSwitchFlowScript.should_preserve_chained_request(
			"turn_open",
			true
		),
		false,
		"a completed forced switch does not keep its old request"
	)
	_check_equal(
		BattleForceSwitchFlowScript.should_preserve_chained_request(
			"awaiting_force_switch",
			false
		),
		false,
		"an opponent-only forced switch does not retain a local request"
	)


func _check_pivot_ko_waiting_player_does_not_infer_force_switch() -> void:
	_check_equal(
		BattleForceSwitchFlowScript.should_infer_pvp_force_switch_from_fainted_active(
			"awaiting_force_switch",
			true,
			false,
			true
		),
		false,
		"a fainted pivot target with wait=true cannot open a simultaneous switch prompt"
	)
	_check_equal(
		BattleForceSwitchFlowScript.should_infer_pvp_force_switch_from_fainted_active(
			"awaiting_force_switch",
			false,
			false,
			true
		),
		false,
		"a LOCKED fainted pivot target cannot open a simultaneous switch prompt"
	)
	_check_equal(
		BattleForceSwitchFlowScript.should_infer_pvp_force_switch_from_fainted_active(
			"awaiting_force_switch",
			false,
			true,
			true
		),
		true,
		"an ACTIVE fainted participant may recover a missing force-switch request"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
