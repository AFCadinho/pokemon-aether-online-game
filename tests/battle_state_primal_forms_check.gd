extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	_check_primal_form("Groudon", "Red Orb", "Groudon-Primal")
	_check_primal_form("Kyogre", "Blue Orb", "Kyogre-Primal")
	_check_event_species_is_preserved("Groudon-Primal")
	_check_event_species_is_preserved("Kyogre-Primal")

	quit(1 if failed else 0)


func _check_primal_form(base_species: String, item: String, expected_species: String) -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "primal-form-test",
		"requests": {
			"p1": {
				"active": [{"canMegaEvo": true}],
				"side": {
					"pokemon": [{
						"ident": "p1a: %s" % base_species,
						"species": base_species,
						"item": item,
						"active": true,
					}],
				},
			},
		},
	}, false)

	_check_equal(
		state.resolve_active_mega_species("p1"),
		expected_species,
		"%s resolves from %s" % [expected_species, item]
	)

	state.apply_event_conditions([{
		"type": "mega",
		"target": "p1a: %s" % base_species,
	}])
	_check_equal(
		state.get_active_pokemon_species("p1"),
		expected_species,
		"%s active display species after event" % expected_species
	)


func _check_event_species_is_preserved(expected_species: String) -> void:
	var base_species := expected_species.replace("-Primal", "")
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "primal-event-species-test",
		"requests": {
			"p1": {
				"active": [{}],
				"side": {
					"pokemon": [{
						"ident": "p1a: %s" % base_species,
						"species": base_species,
						"active": true,
					}],
				},
			},
		},
	}, false)

	state.apply_event_conditions([{
		"type": "mega",
		"target": "p1a: %s" % base_species,
		"species": expected_species,
	}])
	_check_equal(
		state.get_active_pokemon_species("p1"),
		expected_species,
		"%s event species is preserved" % expected_species
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
