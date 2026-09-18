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
	_check_cry_path(
		"Pikachu",
		true,
		"%s/PIKACHU.ogg" % PokemonCryResolver.ANIME_POKEMON_CRY_DIR,
		"anime cry is selected when enabled"
	)
	_check_cry_path(
		"Sprigatito",
		true,
		"%s/SPRIGATITO.ogg" % PokemonCryResolver.POKEMON_CRY_DIR,
		"current cry remains the fallback outside the anime collection"
	)

	quit(1 if failed else 0)


func _check_cry_key(species: String, expected: String, label: String) -> void:
	var actual: String = resolver.get_cry_key(species)
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, expected, actual])


func _check_cry_path(species: String, prefer_anime_cry: bool, expected: String, label: String) -> void:
	var actual := resolver.get_cry_path(species, prefer_anime_cry)
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, expected, actual])
