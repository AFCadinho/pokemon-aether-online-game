extends SceneTree

const HoverLevel := preload("res://scripts/battle/battle_pokemon_hover_level.gd")

var failed := false


func _init() -> void:
	_check(HoverLevel.from_pokemon_data({"level": 50}) == 50, "Hover level accepts integers")
	_check(HoverLevel.from_pokemon_data({"level": 75.0}) == 75, "Hover level accepts integral JSON floats")
	_check(HoverLevel.from_pokemon_data({"level": " 42 "}) == 42, "Hover level accepts integer strings")
	_check(HoverLevel.from_pokemon_data({"level": {"current": 50}}) == 100, "Hover level rejects dictionaries safely")
	_check(HoverLevel.from_pokemon_data({"level": [50]}) == 100, "Hover level rejects arrays safely")
	_check(HoverLevel.from_pokemon_data({"level": 50.5}) == 100, "Hover level rejects fractional values")
	_check(HoverLevel.from_pokemon_data({"level": 0}) == 100, "Hover level rejects zero")
	_check(HoverLevel.from_pokemon_data({"level": 101}) == 100, "Hover level rejects values above the level cap")
	_check(HoverLevel.from_pokemon_data({"level": 120}) == 120, "Hover level accepts the Hard boss level")
	_check(HoverLevel.from_pokemon_data({}) == 100, "Hover level defaults missing values")
	_check(HoverLevel.from_pokemon_data({"details": "Pikachu, L37, M"}) == 37, "Spectator details preserve the actual public level")
	_check(HoverLevel.from_pokemon_data({"details": "Rattata, F, L5, shiny"}) == 5, "Public level parsing tolerates details order")
	_check(HoverLevel.from_pokemon_data({"level": 50, "details": "Pikachu, L37"}) == 50, "Explicit valid levels retain precedence")
	_check(HoverLevel.from_pokemon_data({"details": "Pikachu, M"}) == 100, "Showdown omitted level means level 100")
	_check(HoverLevel.from_pokemon_data({"details": "Mewtwo, L120"}) == 120, "Public details support the Hard boss level")
	for details: Variant in ["Pikachu, L0", "Pikachu, L101", "Pikachu, L37.5", "Pikachu, LNaN", {}, []]:
		_check(HoverLevel.from_pokemon_data({"details": details}) == 100, "Invalid details safely retain the default: %s" % str(details))

	if not failed:
		print("PASS battle_pokemon_hover_level_check")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
