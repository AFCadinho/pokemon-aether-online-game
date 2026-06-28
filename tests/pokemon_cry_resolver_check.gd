extends SceneTree

const PokemonCryResolver := preload("res://scripts/services/pokemon_cry_resolver.gd")

var failed := false
var resolver := PokemonCryResolver.new()


func _init() -> void:
	_check_cry_key("Pikachu", "PIKACHU", "plain species")
	_check_cry_key("Tapu Koko", "TAPUKOKO", "spaced species")
	_check_cry_key("Mr. Mime", "MRMIME", "punctuated species")
	_check_cry_key("Ho-Oh", "HOOH", "hyphenated species")
	_check_cry_key("Type: Null", "TYPENULL", "colon species")
	_check_cry_key("Charizard-Mega-X", "CHARIZARD", "mega form fallback")
	_check_cry_key("Nidoran-F", "NIDORANfE", "female nidoran")

	quit(1 if failed else 0)


func _check_cry_key(species: String, expected: String, label: String) -> void:
	var actual: String = resolver.get_cry_key(species)
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, expected, actual])
