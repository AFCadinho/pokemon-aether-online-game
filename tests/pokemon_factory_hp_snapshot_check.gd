extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	_check_percent_hp_snapshot_uses_stat_hp()
	_check_partial_percent_hp_snapshot_uses_stat_hp()
	_check_absolute_hp_payload_remains_absolute()
	_check_payload_without_stat_hp_remains_absolute()

	quit(1 if failed else 0)


func _check_percent_hp_snapshot_uses_stat_hp() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Tapu Koko",
		"stats": {"hp": 282},
		"currentHp": 100,
		"maxHp": 100,
	})

	_check_equal(pokemon.max_hp, 282, "percent snapshot max HP")
	_check_equal(pokemon.current_hp, 282, "percent snapshot current HP")
	_check_equal(pokemon.has_saved_hp_state, true, "percent snapshot saved HP state")


func _check_partial_percent_hp_snapshot_uses_stat_hp() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Tapu Koko",
		"stats": {"hp": 282},
		"currentHp": 50,
		"maxHp": 100,
	})

	_check_equal(pokemon.max_hp, 282, "partial percent snapshot max HP")
	_check_equal(pokemon.current_hp, 141, "partial percent snapshot current HP")


func _check_absolute_hp_payload_remains_absolute() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Chansey",
		"stats": {"hp": 100},
		"currentHp": 75,
		"maxHp": 100,
	})

	_check_equal(pokemon.max_hp, 100, "absolute max HP")
	_check_equal(pokemon.current_hp, 75, "absolute current HP")


func _check_payload_without_stat_hp_remains_absolute() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Rattata",
		"currentHp": 100,
		"maxHp": 100,
	})

	_check_equal(pokemon.max_hp, 100, "no stat HP absolute max HP")
	_check_equal(pokemon.current_hp, 100, "no stat HP absolute current HP")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
