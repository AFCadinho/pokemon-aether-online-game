extends SceneTree

const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	var pokemon = PokemonFactoryScript.create_pokemon_from_backend_payload({
		"species": "Absol",
		"speciesId": "absol",
		"showdownId": "absol",
		"level": 50,
		"item": "absolite-z",
		"ability": "pressure",
		"possibleAbilities": ["pressure", "super-luck", "justified"],
		"nature": "Jolly",
		"happiness": 50,
		"evs": {"hp": 0, "atk": 252, "def": 0, "spa": 0, "spd": 4, "spe": 252},
		"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"stats": {"hp": 140, "atk": 200, "def": 80, "spa": 95, "spd": 81, "spe": 139},
		"moves": ["Sucker Punch", "Play Rough"],
		"types": ["dark"],
		"currentHp": 140,
		"maxHp": 140,
		"shiny": true,
	})

	_check(pokemon != null, "normalized backend payload creates a runtime Pokemon")
	if pokemon != null:
		_check(pokemon.species == "Absol", "runtime identity remains the base form")
		_check(pokemon.item == "absolite-z", "runtime Pokemon retains the activation stone")
		_check(pokemon.ability == "pressure", "runtime Pokemon retains the base ability")
		_check(pokemon.types == ["dark"], "runtime Pokemon retains base-form types")
		_check(pokemon.max_hp == 140 and pokemon.current_hp == 140, "runtime Pokemon uses the recomputed base HP")
		var battle_payload: Dictionary = pokemon.to_battle_dict()
		var persistence_payload: Dictionary = pokemon.to_persistence_dict()
		_check(battle_payload.get("species") == "Absol", "battle payload starts from the base form")
		_check(battle_payload.get("item") == "absolite-z", "battle payload includes the activation stone")
		_check(persistence_payload.get("species") == "Absol", "persistence payload stores the base form")
		_check(persistence_payload.get("item") == "absolite-z", "persistence payload stores the activation stone")

	if failed:
		quit(1)
		return
	print("PASS mega_champions_phase4_generator_payload_check")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL: %s" % message)

