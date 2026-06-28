extends RefCounted

const POKEMON_CRY_DIR := "res://assets/audio/sfx/pokemon_cries"


func get_cry_key(species: String) -> String:
	var species_key := _normalize_species_id(species)
	if species_key == "":
		return ""

	var direct_key := _species_id_to_cry_key(species_key)
	if ResourceLoader.exists("%s/%s.ogg" % [POKEMON_CRY_DIR, direct_key]):
		return direct_key

	var base_species_key := _get_base_species_id(species_key)
	var base_key := _species_id_to_cry_key(base_species_key)
	if ResourceLoader.exists("%s/%s.ogg" % [POKEMON_CRY_DIR, base_key]):
		return base_key

	return ""


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
