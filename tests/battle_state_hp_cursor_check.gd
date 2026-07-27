extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	_check_historical_damage_does_not_rewind_an_undamaged_slot()
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
