extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	_check_base_experience_survives_battle_payload()

	quit(1 if failed else 0)


func _check_base_experience_survives_battle_payload() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Rattata",
		"level": 7,
		"baseExperience": 51,
	})

	_check_equal(pokemon.base_experience, 51, "runtime base experience")
	_check_equal(pokemon.to_battle_dict().get("baseExperience", 0), 51, "battle payload base experience")
	_check_equal(pokemon.to_persistence_dict().get("baseExperience", 0), 51, "persistence payload base experience")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
