extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	_check_explicit_happiness_survives_all_payloads()
	_check_friendship_alias_and_bounds()
	_check_default_happiness()

	quit(1 if failed else 0)


func _check_explicit_happiness_survives_all_payloads() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Lopunny",
		"level": 100,
		"happiness": 0,
		"moves": ["Frustration"],
	})

	_check_equal(pokemon.happiness, 0, "runtime happiness")
	_check_equal(pokemon.to_battle_dict().get("happiness", -1), 0, "battle payload happiness")
	_check_equal(pokemon.to_persistence_dict().get("happiness", -1), 0, "persistence payload happiness")


func _check_friendship_alias_and_bounds() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Pikachu",
		"friendship": 999,
	})

	_check_equal(pokemon.happiness, 255, "friendship alias clamps to maximum")


func _check_default_happiness() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({"species": "Eevee"})

	_check_equal(pokemon.happiness, 50, "modern default happiness")
	_check_equal(pokemon.to_battle_dict().get("happiness", -1), 50, "default battle happiness")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
