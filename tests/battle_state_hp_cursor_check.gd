extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	_check_historical_damage_does_not_rewind_an_undamaged_slot()
	_check_percentage_damage_survives_a_quiet_turn()
	_check_public_lead_switches_activate_team_preview_rosters()
	_check_public_base_ident_resolves_unique_preview_form()
	_check_public_hp_memory_is_scoped_per_player()
	_check_spectator_side_swap_resets_side_relative_hp_memory()
	quit(1 if failed else 0)


func _check_historical_damage_does_not_rewind_an_undamaged_slot() -> void:
	var state = BattleStateScript.new()

	var old_damage := _damage_event("p1a: Pikachu", "p1:slot:1", 1, 100, 70)
	var current_damage := _damage_event("p2a: Eevee", "p2:slot:1", 1, 100, 80)
	var response := {
		"success": true,
		"battleId": "hp-cursor-test",
		"eventSeq": 2,
		"requests": {
			"p1": {"side": {"pokemon": [_pokemon("p1: Pikachu", "p1:slot:1", 70)]}},
			"p2": {"side": {"pokemon": [_pokemon("p2: Eevee", "p2:slot:1", 80)]}},
		},
		"events": [old_damage, current_damage],
	}

	# The transport can return full history even though event 1 was already
	# rendered. Only event 2 may rewind visible state before its animation.
	state.load_from_api_response(response, false, 1)
	_check_equal(
		state.get_active_pokemon_current_hp("p1"),
		70,
		"historical damage does not reset an unchanged Pokemon to full HP"
	)
	_check_equal(
		state.get_active_pokemon_current_hp("p2"),
		100,
		"the current damage event still rewinds before animation"
	)

	state.apply_event_conditions([current_damage])
	_check_equal(
		state.get_active_pokemon_current_hp("p2"),
		80,
		"the current damage event reaches its authoritative HP after animation"
	)

func _check_percentage_damage_survives_a_quiet_turn() -> void:
	var state = BattleStateScript.new()
	var damage_event := _damage_event("p1a: Kingambit", "p1:slot:3", 3, 100, 32)
	var full_health_kingambit := {
		"ident": "p1: Kingambit",
		"species": "Kingambit",
		"active": true,
		"condition": "341/341",
		"hp": 341,
		"maxHp": 341,
		"fainted": false,
		"metadataSlot": 3,
		"pokemonKey": "p1:slot:3",
	}
	state.load_from_api_response({
		"success": true,
		"battleId": "percentage-hp-quiet-turn-test",
		"eventSeq": 0,
		"requests": {"p1": {"side": {"pokemon": [full_health_kingambit]}}},
		"events": [],
	})

	state.apply_event_conditions([damage_event])
	_check_equal(
		state.get_active_pokemon_current_hp("p1"),
		109,
		"public 32 percent damage is projected onto the known 341 max HP"
	)
	_check_equal(
		state.get_active_pokemon_max_hp("p1"),
		341,
		"percentage damage retains the known maximum HP"
	)

	var quiet_turn_response := {
		"success": true,
		"battleId": "percentage-hp-quiet-turn-test",
		"eventSeq": 1,
		"requests": {
			"p1": {
				"side": {
					"pokemon": [{
						"ident": "p1: Kingambit",
						"species": "Kingambit",
						"active": true,
						"condition": "32/100",
						"hp": 32,
						"maxHp": 100,
						"fainted": false,
						"metadataSlot": 3,
						"pokemonKey": "p1:slot:3",
					}],
				},
			},
		},
		"events": [damage_event],
	}
	state.load_from_api_response(quiet_turn_response, false, 1)
	_check_equal(
		state.get_active_pokemon_current_hp("p1"),
		109,
		"a later turn without damage does not visually heal Kingambit"
	)
	_check_equal(
		str(state.get_active_player_pokemon("p1").get("condition", "")),
		"109/341",
		"the canonical condition remains on the known HP scale"
	)


func _check_public_hp_memory_is_scoped_per_player() -> void:
	var state = BattleStateScript.new()
	var public_snapshot := {
		"success": true,
		"battleId": "spectator-cross-side-hp-test",
		"requests": {
			"p1": {"side": {"pokemon": [{
				"ident": "p1: Cinderace",
				"species": "Cinderace",
				"active": false,
				"condition": "100/100",
				"hp": 100,
				"maxHp": 100,
				"fainted": false,
			}]}},
			"p2": {"side": {"pokemon": [{
				"ident": "p2: Landorus-Therian",
				"species": "Landorus-Therian",
				"active": false,
				"condition": "0 fnt",
				"hp": 0,
				"maxHp": 100,
				"fainted": true,
			}]}},
		},
		"events": [],
	}

	# Public spectator rosters intentionally omit private Pokemon keys and party
	# slots. Reapplying a snapshot must still keep equal array positions on the
	# two opposing teams in separate HP-memory namespaces.
	state.load_from_api_response(public_snapshot, false)
	state.load_from_api_response(public_snapshot, false)
	var cinderace: Dictionary = state.get_player_team("p1")[0]
	var landorus: Dictionary = state.get_player_team("p2")[0]
	_check_equal(bool(cinderace.get("fainted", false)), false, "p1 Cinderace does not inherit p2 Landorus's faint")
	_check_equal(str(cinderace.get("condition", "")), "100/100", "p1 Cinderace retains its own public HP")
	_check_equal(bool(landorus.get("fainted", false)), true, "p2 Landorus remains fainted")


func _check_spectator_side_swap_resets_side_relative_hp_memory() -> void:
	var state = BattleStateScript.new()
	var original_view := {
		"success": true,
		"battleId": "spectator-side-swap-hp-test",
		"requests": {
			"p1": {"side": {"pokemon": [{
				"ident": "p1: Cinderace", "species": "Cinderace",
				"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
			}]}},
			"p2": {"side": {"pokemon": [{
				"ident": "p2: Landorus-Therian", "species": "Landorus-Therian",
				"condition": "0 fnt", "hp": 0, "maxHp": 100, "fainted": true,
			}]}},
		},
		"events": [],
	}
	state.load_from_api_response(original_view, false)

	var switched_view := {
		"success": true,
		"battleId": "spectator-side-swap-hp-test",
		"requests": {
			"p1": {"side": {"pokemon": [{
				"ident": "p1: Landorus-Therian", "species": "Landorus-Therian",
				"condition": "0 fnt", "hp": 0, "maxHp": 100, "fainted": true,
			}]}},
			"p2": {"side": {"pokemon": [{
				"ident": "p2: Cinderace", "species": "Cinderace",
				"condition": "100/100", "hp": 100, "maxHp": 100, "fainted": false,
			}]}},
		},
		"events": [],
	}
	state.reset_side_relative_presentation_memory()
	state.load_from_api_response(switched_view, false)

	var landorus: Dictionary = state.get_player_team("p1")[0]
	var cinderace: Dictionary = state.get_player_team("p2")[0]
	_check_equal(bool(landorus.get("fainted", false)), true, "switched p1 Landorus remains fainted")
	_check_equal(bool(cinderace.get("fainted", false)), false, "switched p2 Cinderace remains healthy")
	_check_equal(str(cinderace.get("condition", "")), "100/100", "switched Cinderace keeps its own HP")


func _check_public_lead_switches_activate_team_preview_rosters() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"success": true,
		"battleId": "spectator-lead-seed-test",
		"requests": {
			"p1": {"side": {"pokemon": [
				{"ident": "p1: Charizard", "species": "Charizard", "active": false, "condition": "100/100"},
				{"ident": "p1: Alomomola", "species": "Alomomola", "active": false, "condition": "100/100"},
			]}},
			"p2": {"side": {"pokemon": [
				{"ident": "p2: Slowking-Galar", "species": "Slowking-Galar", "active": false, "condition": "100/100"},
				{"ident": "p2: Gengar", "species": "Gengar", "active": false, "condition": "100/100"},
			]}},
		},
		"events": [],
	})

	state.apply_event_conditions([
		{
			"type": "switch",
			"toIdent": "p1a: Charizard",
			"details": "Charizard, M, shiny",
			"condition": "100/100",
			"shiny": true,
		},
		{
			"type": "switch",
			"toIdent": "p2a: Slowking",
			"details": "Slowking-Galar, L100",
			"condition": "100/100",
		},
	])

	_check_equal(
		str(state.get_active_player_pokemon("p1").get("species", "")),
		"Charizard",
		"public p1 lead switch activates the Team Preview roster entry"
	)
	_check_equal(
		str(state.get_active_player_pokemon("p2").get("species", "")),
		"Slowking-Galar",
		"public regional-form lead switch activates the exact Team Preview form"
	)
	_check_equal(
		str(state.get_active_player_pokemon("p2").get("ident", "")),
		"p2a: Slowking",
		"public lead switch stores the live battle ident"
	)
	_check_equal(
		bool(state.get_active_player_pokemon("p1").get("shiny", false)),
		true,
		"public lead switch preserves the shiny form"
	)

	state.apply_event_conditions([{
		"type": "mega",
		"target": "p1a: Charizard",
		"species": "Charizard-Mega-Y",
	}])
	_check_equal(
		str(state.get_active_player_pokemon("p1").get("displaySpecies", "")),
		"Charizard-Mega-Y",
		"public Mega event updates the active display form"
	)

	state.apply_event_conditions([{
		"type": "damage",
		"target": "p2a: Slowking",
		"condition": "63/100",
	}])
	_check_equal(
		state.get_active_pokemon_current_hp("p2"),
		63,
		"later public HP events resolve the seeded regional-form lead"
	)


func _check_public_base_ident_resolves_unique_preview_form() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"requests": {
			"p2": {
				"side": {
					"pokemon": [
						{
							"ident": "p2: Hatterene",
							"species": "Hatterene",
							"displaySpecies": "Hatterene",
							"condition": "100/100",
							"active": false,
						},
						{
							"ident": "p2: Landorus Therian",
							"species": "Landorus Therian",
							"displaySpecies": "Landorus Therian",
							"condition": "100/100",
							"active": false,
						},
					],
				},
			},
		},
		"events": [],
	})
	var inferred_event := state.build_public_switch_event_for_ident("p2", "p2a: Landorus")
	state.apply_event_conditions([inferred_event])
	_check_equal(
		str(state.get_active_player_pokemon("p2").get("displaySpecies", "")),
		"Landorus Therian",
		"a public base-form ident activates the unique Team Preview forme"
	)
	_check_equal(
		str(state.get_active_player_pokemon("p2").get("ident", "")),
		"p2a: Landorus",
		"the inferred public lead preserves the live battle ident"
	)


func _pokemon(ident: String, pokemon_key: String, hp: int) -> Dictionary:
	return {
		"ident": ident,
		"species": ident.split(": ")[1],
		"active": true,
		"condition": "%s/100" % hp,
		"hp": hp,
		"maxHp": 100,
		"fainted": false,
		"metadataSlot": 1,
		"pokemonKey": pokemon_key,
	}


func _damage_event(
	target: String,
	pokemon_key: String,
	metadata_slot: int,
	previous_hp: int,
	hp: int
) -> Dictionary:
	return {
		"type": "damage",
		"target": target,
		"pokemonKey": pokemon_key,
		"metadataSlot": metadata_slot,
		"previousCondition": "%s/100" % previous_hp,
		"condition": "%s/100" % hp,
		"previousHp": previous_hp,
		"hp": hp,
		"maxHp": 100,
	}


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return

	failed = true
	push_error("FAIL: %s (expected %s, got %s)" % [label, str(expected), str(actual)])
