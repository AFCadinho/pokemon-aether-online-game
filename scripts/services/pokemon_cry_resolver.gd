extends RefCounted

const POKEMON_CRY_DIR := "res://assets/audio/sfx/pokemon_cries"
const ANIME_POKEMON_CRY_DIR := "res://assets/audio/sfx/pokemon_anime_cries"


func get_cry_key(species: String) -> String:
	var sound_path := get_cry_path(species, false)
	return sound_path.get_file().get_basename()


func get_cry_path(species: String, prefer_anime_cry: bool) -> String:
	var species_key := _normalize_species_id(species)
	if species_key == "":
		return ""

	var direct_key := _species_id_to_cry_key(species_key)
	var direct_path := _get_cry_path(direct_key, prefer_anime_cry)
	if direct_path != "":
		return direct_path

	var base_species_key := _get_base_species_id(species_key)
	var base_key := _species_id_to_cry_key(base_species_key)
	var base_path := _get_cry_path(base_key, prefer_anime_cry)
	if base_path != "":
		return base_path

	return ""


func _get_cry_path(cry_key: String, prefer_anime_cry: bool) -> String:
	var anime_path := "%s/%s.ogg" % [ANIME_POKEMON_CRY_DIR, cry_key]
	if prefer_anime_cry and ResourceLoader.exists(anime_path):
		return anime_path

	var default_path := "%s/%s.ogg" % [POKEMON_CRY_DIR, cry_key]
	return default_path if ResourceLoader.exists(default_path) else ""


func _normalize_species_id(species: String) -> String:
	var normalized := species.strip_edges().to_lower()
	normalized = normalized.replace("’", "")
	normalized = normalized.replace("'", "")
	normalized = normalized.replace(".", "")
	normalized = normalized.replace(":", "")
	normalized = normalized.replace(" ", "-")
	normalized = normalized.replace("_", "-")
	return normalized


func _get_base_species_id(species_key: String) -> String:
	var form_suffixes := [
		"-mega-x",
		"-mega-y",
		"-mega",
		"-gmax",
		"-gigantamax",
		"-alola",
		"-alolan",
		"-galar",
		"-galarian",
		"-hisui",
		"-hisuian",
		"-paldea",
		"-paldean",
		"-primal",
		"-origin",
		"-altered",
		"-therian",
		"-incarnate",
		"-sky",
		"-land",
		"-east",
		"-west",
		"-female",
		"-male",
	]

	for suffix in form_suffixes:
		if species_key.ends_with(suffix):
			return species_key.substr(0, species_key.length() - suffix.length())

	return species_key


func _species_id_to_cry_key(species_key: String) -> String:
	match species_key:
		"nidoran-f":
			return "NIDORANfE"
		"nidoran-m":
			return "NIDORANmA"

	return species_key.to_upper().replace("-", "")
