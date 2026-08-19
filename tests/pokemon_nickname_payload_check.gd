extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failures := 0


func _init() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"name": "Sparky",
		"species": "Pikachu",
		"ownedPokemonId": 42,
	})
	_check(pokemon != null, "Pokemon factory accepts imported nickname")
	if pokemon != null:
		_check_equal(pokemon.nickname, "Sparky", "legacy Showdown name maps to nickname")
		_check_equal(pokemon.to_battle_dict().get("name", ""), "Sparky", "battle payload exposes Showdown name")
		_check_equal(pokemon.to_battle_dict().get("nickname", ""), "Sparky", "battle payload preserves canonical nickname")
		_check_equal(pokemon.to_persistence_dict().get("nickname", ""), "Sparky", "persistence keeps nickname")
		_check(not pokemon.to_persistence_dict().has("name"), "persistence omits Showdown alias")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])
