extends RefCounted

class_name BattlePartySlotResolver

const FORM_SUFFIXES := [
	"megax", "megay", "mega", "primal",
	"alola", "galar", "hisui", "paldea",
	"therian", "incarnate", "origin", "altered",
	"wellspring", "hearthflame", "cornerstone", "teal",
	"wash", "heat", "frost", "fan", "mow",
	"sky", "land", "blade", "shield",
]


static func resolve_selected_slot(selected_data: Dictionary, canonical_roster: Array) -> int:
	if selected_data.is_empty() or canonical_roster.is_empty():
		return -1

	var selected_species := _species_key(selected_data)
	var selected_owned_id := _stable_id(selected_data, [
		"ownedPokemonId", "owned_pokemon_id", "pokemonId", "pokemon_id",
	])
	var selected_instance_id := _stable_id(selected_data, ["instanceId", "instance_id"])

	if selected_owned_id != "":
		var owned_slot := _find_unique_identity_slot(
			canonical_roster,
			selected_species,
			selected_owned_id,
			["ownedPokemonId", "owned_pokemon_id", "pokemonId", "pokemon_id"]
		)
		if owned_slot > 0:
			return owned_slot

	if selected_instance_id != "":
		var instance_slot := _find_unique_identity_slot(
			canonical_roster,
			selected_species,
			selected_instance_id,
			["instanceId", "instance_id"]
		)
		if instance_slot > 0:
			return instance_slot

	var species_slot := _find_unique_species_slot(canonical_roster, selected_species)
	if species_slot > 0:
		return species_slot

	var declared_slot := get_canonical_slot(selected_data)
	if declared_slot > 0:
		var declared_pokemon := get_roster_pokemon_for_slot(canonical_roster, declared_slot)
		if not declared_pokemon.is_empty() and _selection_matches_roster_entry(selected_data, declared_pokemon):
			return declared_slot

	return -1


static func get_canonical_slot(pokemon_data: Dictionary) -> int:
	for key in [
		"canonicalPartySlot", "canonical_party_slot",
		"partySlot", "party_slot",
		"metadataSlot", "metadata_slot",
	]:
		var slot := _positive_int(pokemon_data.get(key, null))
		if slot > 0:
			return slot

	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	if pokemon_key.contains(":slot:"):
		return _positive_int(pokemon_key.rsplit(":slot:", true, 1)[1])

	return -1


static func get_roster_pokemon_for_slot(canonical_roster: Array, canonical_slot: int) -> Dictionary:
	for pokemon_value: Variant in canonical_roster:
		if not (pokemon_value is Dictionary):
			continue
		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if get_canonical_slot(pokemon_data) == canonical_slot:
			return pokemon_data
	return {}


static func _find_unique_identity_slot(
	canonical_roster: Array,
	selected_species: String,
	selected_id: String,
	identity_keys: Array
) -> int:
	var matched_slot := -1
	for pokemon_value: Variant in canonical_roster:
		if not (pokemon_value is Dictionary):
			continue
		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _stable_id(pokemon_data, identity_keys) != selected_id:
			continue
		if not _species_are_compatible(selected_species, _species_key(pokemon_data)):
			continue
		var slot := get_canonical_slot(pokemon_data)
		if slot <= 0 or matched_slot > 0:
			return -1
		matched_slot = slot
	return matched_slot


static func _find_unique_species_slot(canonical_roster: Array, selected_species: String) -> int:
	if selected_species == "":
		return -1

	var matched_slot := -1
	for pokemon_value: Variant in canonical_roster:
		if not (pokemon_value is Dictionary):
			continue
		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if not _species_are_compatible(selected_species, _species_key(pokemon_data)):
			continue
		var slot := get_canonical_slot(pokemon_data)
		if slot <= 0 or matched_slot > 0:
			return -1
		matched_slot = slot
	return matched_slot


static func _selection_matches_roster_entry(selected_data: Dictionary, roster_data: Dictionary) -> bool:
	var selected_species := _species_key(selected_data)
	var roster_species := _species_key(roster_data)
	if not _species_are_compatible(selected_species, roster_species):
		return false

	for keys in [
		["ownedPokemonId", "owned_pokemon_id", "pokemonId", "pokemon_id"],
		["instanceId", "instance_id"],
	]:
		var selected_id := _stable_id(selected_data, keys)
		var roster_id := _stable_id(roster_data, keys)
		if selected_id != "" and roster_id != "":
			return selected_id == roster_id

	return selected_species != "" and roster_species != ""


static func _species_are_compatible(left: String, right: String) -> bool:
	if left == "" or right == "":
		return false
	if left == right:
		return true
	return _base_species_key(left) == _base_species_key(right)


static func _base_species_key(species_key: String) -> String:
	for suffix in FORM_SUFFIXES:
		if species_key.ends_with(suffix) and species_key.length() > suffix.length():
			return species_key.left(species_key.length() - suffix.length())
	return species_key


static func _species_key(pokemon_data: Dictionary) -> String:
	var species := ""
	for key in ["species", "details", "displaySpecies"]:
		species = str(pokemon_data.get(key, "")).strip_edges()
		if species != "":
			break
	if species.contains(","):
		species = species.split(",")[0].strip_edges()
	if species == "":
		var ident := str(pokemon_data.get("ident", "")).strip_edges()
		if ident.contains(": "):
			species = str(ident.split(": ")[1]).strip_edges()
	return species.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")


static func _stable_id(pokemon_data: Dictionary, keys: Array) -> String:
	for key in keys:
		var value: Variant = pokemon_data.get(key, null)
		if value == null:
			continue
		var normalized := str(value).strip_edges()
		if normalized != "" and normalized != "0":
			return normalized
	return ""


static func _positive_int(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if value is float and int(value) > 0:
		return int(value)
	var text := str(value).strip_edges()
	if text.is_valid_int() and int(text) > 0:
		return int(text)
	return -1
