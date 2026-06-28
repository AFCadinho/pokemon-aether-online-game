extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	_check_explicit_ball_metadata()
	_check_legacy_caught_with_fallback()
	_check_origin_ball_fallback()
	_check_default_summon_ball()

	quit(1 if failed else 0)


func _check_explicit_ball_metadata() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Rattata",
		"ballItemId": "dream-ball",
		"caughtBallItemId": "poke-ball",
	})

	_check_equal(pokemon.ball_item_id, "dream-ball", "explicit current ball")
	_check_equal(pokemon.caught_ball_item_id, "poke-ball", "explicit caught ball")
	_check_equal(pokemon.to_battle_dict().get("ballItemId", ""), "dream-ball", "battle payload current ball")
	_check_equal(pokemon.to_persistence_dict().get("caughtBallItemId", ""), "poke-ball", "persistence caught ball")


func _check_legacy_caught_with_fallback() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Pidgey",
		"caughtWith": "Great Ball",
	})

	_check_equal(pokemon.ball_item_id, "great-ball", "legacy caughtWith current ball")
	_check_equal(pokemon.caught_ball_item_id, "great-ball", "legacy caughtWith caught ball")


func _check_origin_ball_fallback() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Caterpie",
		"origin": {
			"ball": "ultra_ball",
		},
	})

	_check_equal(pokemon.ball_item_id, "ultra-ball", "origin ball current ball")
	_check_equal(pokemon.caught_ball_item_id, "ultra-ball", "origin ball caught ball")


func _check_default_summon_ball() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Bulbasaur",
	})

	_check_equal(pokemon.ball_item_id, "poke-ball", "default current ball")
	_check_equal(pokemon.caught_ball_item_id, "", "default caught ball remains empty")
	_check_equal(pokemon.to_battle_dict().get("ballItemId", ""), "poke-ball", "default battle payload current ball")
	_check_equal(pokemon.to_persistence_dict().has("caughtBallItemId"), false, "default persistence omits caught ball")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
