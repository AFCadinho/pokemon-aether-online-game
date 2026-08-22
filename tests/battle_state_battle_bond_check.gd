extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BattleDisplayDataPresenterScript := preload("res://scripts/battle/battle_display_data_presenter.gd")
const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	_check_battle_bond_identity_survives_frontend_persistence()
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "battle-bond-cosmetic-test",
		"requests": {
			"p1": {
				"active": [{}],
				"side": {
					"pokemon": [
						{
							"ident": "p1a: Greninja",
							"species": "Greninja",
							"ability": "Battle Bond",
							"active": true,
						},
						{
							"ident": "p1b: Pikachu",
							"species": "Pikachu",
							"active": false,
						},
					],
				},
			},
		},
	}, false)

	state.apply_event_conditions([{
		"type": "formeChange",
		"target": "p1a: Greninja",
		"species": "Greninja-Ash",
		"source": "ability: Battle Bond",
		"cosmeticOnly": true,
	}])

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	_check_equal(
		state.get_active_pokemon_species("p1"),
		"Greninja",
		"Battle Bond cosmetic does not change the mechanical species"
	)
	_check_equal(
		presenter.get_active_display_species("p1"),
		"Greninja-Ash",
		"Battle Bond activation displays Ash-Greninja"
	)

	state.apply_event_conditions([{
		"type": "switch",
		"fromIdent": "p1a: Greninja",
		"toIdent": "p1a: Pikachu",
		"pokemon": "p1a: Pikachu",
		"details": "Pikachu, L50",
		"condition": "100/100",
	}])
	state.apply_event_conditions([{
		"type": "switch",
		"fromIdent": "p1a: Pikachu",
		"toIdent": "p1a: Greninja",
		"pokemon": "p1a: Greninja",
		"details": "Greninja, L50",
		"condition": "100/100",
	}])
	_check_equal(
		presenter.get_active_display_species("p1"),
		"Greninja",
		"Battle Bond cosmetic stays inactive after Greninja switches back in"
	)

	quit(1 if failed else 0)


func _check_battle_bond_identity_survives_frontend_persistence() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Greninja",
		"speciesId": "greninja-bond",
		"showdownId": "greninjabond",
		"ability": "battle-bond",
		"possibleAbilities": ["battle-bond"],
		"specialLineage": "battle-bond",
	})
	var persisted: Dictionary = pokemon.to_persistence_dict()
	_check_equal(persisted.get("species"), "Greninja", "Battle Bond uses the normal stored display species")
	_check_equal(persisted.get("speciesId"), "greninja-bond", "Battle Bond keeps its internal species id")
	_check_equal(persisted.get("showdownId"), "greninjabond", "Battle Bond keeps its Showdown id")
	_check_equal(persisted.get("specialLineage"), "battle-bond", "Battle Bond keeps its special lineage")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
