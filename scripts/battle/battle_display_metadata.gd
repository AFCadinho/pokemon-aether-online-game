extends RefCounted

class_name BattleDisplayMetadata

const BATTLE_TYPE_WILD := 0
const BATTLE_TYPE_TRAINER := 1

var battle_state: BattleState
var battle_type := BATTLE_TYPE_WILD
var active_enemy_pokemon: Pokemon
var trainer_enemy_team: Array = []


func setup(state: BattleState) -> void:
	battle_state = state


func set_battle_context(type_value: int, enemy_pokemon: Pokemon) -> void:
	battle_type = type_value
	active_enemy_pokemon = enemy_pokemon
	if battle_type != BATTLE_TYPE_TRAINER:
		trainer_enemy_team = []


func set_trainer_team(team: Array) -> void:
	trainer_enemy_team = team.duplicate(true)


func get_player_save_pokemon_for_battle_data(pokemon_data: Dictionary) -> Pokemon:
	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", "")))
	var saved_pokemon := get_player_save_pokemon_by_instance_id(instance_id)
	if saved_pokemon != null:
		return saved_pokemon

	saved_pokemon = get_player_save_pokemon_by_canonical_slot(pokemon_data)
	if saved_pokemon != null:
		return saved_pokemon

	saved_pokemon = get_unique_player_save_pokemon_by_battle_species(pokemon_data)
	if saved_pokemon != null:
		return saved_pokemon

	return null


func enrich_display_data(player_id: String, display_data: Dictionary) -> void:
	match player_id:
		"p1":
			_enrich_display_data_from_player_save(display_data)
		"p2":
			_enrich_display_data_from_wild_pokemon(display_data)
			_enrich_display_data_from_trainer_team(display_data)


func get_player_save_pokemon_by_instance_id(instance_id: String) -> Pokemon:
	if instance_id == "":
		return null

	for pokemon in PlayerSave.party:
		if pokemon.instance_id == instance_id:
			return pokemon

	return null


func get_player_save_pokemon_by_canonical_slot(pokemon_data: Dictionary) -> Pokemon:
	var canonical_slot := _get_canonical_party_slot(pokemon_data)
	if canonical_slot <= 0:
		return null

	var slot_index := canonical_slot - 1
	if slot_index < 0 or slot_index >= PlayerSave.party.size():
		return null

	return PlayerSave.party[slot_index] as Pokemon


func get_unique_player_save_pokemon_by_battle_species(pokemon_data: Dictionary) -> Pokemon:
	var battle_species := ""
	if battle_state != null:
		battle_species = battle_state.get_species_from_pokemon_data(pokemon_data)
	if battle_species == "":
		battle_species = str(pokemon_data.get("species", pokemon_data.get("displaySpecies", "")))

	var normalized_battle_species := normalize_species_for_compare(battle_species)
	if normalized_battle_species == "":
		return null

	var matched_pokemon: Pokemon = null
	for pokemon in PlayerSave.party:
		if not saved_species_is_compatible_with_battle_species(pokemon, battle_species):
			continue
		if matched_pokemon != null:
			return null
		matched_pokemon = pokemon

	return matched_pokemon


func saved_species_matches_battle_data(saved_pokemon: Pokemon, pokemon_data: Dictionary) -> bool:
	if battle_state == null:
		return false

	var battle_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if battle_species == "":
		return true

	return saved_species_is_compatible_with_battle_species(saved_pokemon, battle_species)


func saved_species_is_compatible_with_battle_species(saved_pokemon: Pokemon, battle_species: String) -> bool:
	if saved_pokemon == null:
		return false

	var normalized_saved_species := normalize_species_for_compare(saved_pokemon.species)
	var normalized_battle_species := normalize_species_for_compare(battle_species)
	if normalized_saved_species == "" or normalized_battle_species == "":
		return true
	if normalized_saved_species == normalized_battle_species:
		return true

	return normalize_species_base_for_compare(normalized_saved_species) == normalize_species_base_for_compare(normalized_battle_species)


func pokemon_data_has_shiny_value(pokemon_data: Dictionary) -> bool:
	return pokemon_data.has("shiny") or pokemon_data.has("isShiny") or pokemon_data.has("is_shiny")


func get_pokemon_data_shiny_value(pokemon_data: Dictionary) -> bool:
	for key in ["shiny", "isShiny", "is_shiny"]:
		if not pokemon_data.has(key):
			continue

		var value: Variant = pokemon_data.get(key)
		if value is bool:
			return bool(value)

		var text_value: String = str(value).strip_edges().to_lower()
		match text_value:
			"true", "yes", "1", "y":
				return true
			"false", "no", "0", "n":
				return false

	return false


func normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")


func normalize_species_base_for_compare(species: String) -> String:
	var normalized_species := normalize_species_for_compare(species)
	for suffix in [
		"-alola", "-galar", "-hisui", "-paldea",
		"-therian", "-incarnate", "-origin", "-altered",
		"-wash", "-heat", "-frost", "-fan", "-mow",
		"-sky", "-land", "-blade", "-shield",
	]:
		if normalized_species.ends_with(suffix):
			return normalized_species.substr(0, normalized_species.length() - suffix.length())

	return normalized_species


func _get_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var party_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["partySlot", "party_slot"])
	if party_slot > 0:
		return party_slot

	var metadata_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["metadataSlot", "metadata_slot"])
	if metadata_slot > 0:
		return metadata_slot

	return _get_pokemon_key_canonical_party_slot(pokemon_data)


func _get_pokemon_key_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	var slot_marker := ":slot:"
	if pokemon_key.contains(slot_marker):
		var slot_text := pokemon_key.split(slot_marker)[1]
		if slot_text.is_valid_int():
			var key_slot := int(slot_text)
			if key_slot > 0:
				return key_slot

	return -1


func _get_positive_slot_from_pokemon_data(pokemon_data: Dictionary, keys: Array) -> int:
	for key in keys:
		if not pokemon_data.has(key):
			continue

		var slot_value: Variant = pokemon_data.get(key)
		if slot_value == null or str(slot_value).strip_edges() == "":
			continue

		var slot := int(slot_value)
		if slot > 0:
			return slot

	return -1


func _enrich_display_data_from_player_save(display_data: Dictionary) -> void:
	var saved_pokemon := get_player_save_pokemon_for_battle_data(display_data)
	if saved_pokemon == null:
		return

	if _has_temporary_battle_display_form(display_data):
		display_data["shiny"] = saved_pokemon.shiny
		if not display_data.has("possibleAbilities"):
			display_data["possibleAbilities"] = saved_pokemon.possible_abilities
		return

	display_data["displaySpecies"] = saved_pokemon.species
	display_data["species"] = saved_pokemon.species
	display_data["shiny"] = saved_pokemon.shiny
	display_data["types"] = saved_pokemon.types
	display_data["possibleAbilities"] = saved_pokemon.possible_abilities

func _has_temporary_battle_display_form(display_data: Dictionary) -> bool:
	return (
		str(display_data.get("megaSpecies", "")) != ""
		or str(display_data.get("transformedSpecies", "")) != ""
	)


func _enrich_display_data_from_wild_pokemon(display_data: Dictionary) -> void:
	if battle_type != BATTLE_TYPE_WILD or active_enemy_pokemon == null:
		return
	if not saved_species_matches_battle_data(active_enemy_pokemon, display_data):
		return

	display_data["displaySpecies"] = active_enemy_pokemon.species
	display_data["species"] = active_enemy_pokemon.species
	display_data["shiny"] = active_enemy_pokemon.shiny
	display_data["types"] = active_enemy_pokemon.types
	display_data["possibleAbilities"] = active_enemy_pokemon.possible_abilities


func _enrich_display_data_from_trainer_team(display_data: Dictionary) -> void:
	if battle_type != BATTLE_TYPE_TRAINER or trainer_enemy_team.is_empty():
		return

	var trainer_pokemon := _find_trainer_team_pokemon_for_display_data(display_data)
	if trainer_pokemon.is_empty():
		return

	_copy_backend_pokemon_metadata(display_data, trainer_pokemon)


func _find_trainer_team_pokemon_for_display_data(display_data: Dictionary) -> Dictionary:
	var metadata_slot := int(display_data.get("metadataSlot", display_data.get("metadata_slot", 0)))
	if metadata_slot > 0:
		var trainer_pokemon_by_slot := _find_trainer_team_pokemon_by_metadata_slot(metadata_slot)
		if not trainer_pokemon_by_slot.is_empty():
			return trainer_pokemon_by_slot

	var display_species := battle_state.get_species_from_pokemon_data(display_data)
	var normalized_display_species := normalize_species_for_compare(display_species)
	if normalized_display_species == "":
		return {}

	for pokemon_value in trainer_enemy_team:
		if not (pokemon_value is Dictionary):
			continue

		var trainer_pokemon: Dictionary = pokemon_value as Dictionary
		var trainer_species := str(trainer_pokemon.get("species", trainer_pokemon.get("displaySpecies", "")))
		var normalized_trainer_species := normalize_species_for_compare(trainer_species)
		if normalized_trainer_species == normalized_display_species:
			return trainer_pokemon

	return {}


func _find_trainer_team_pokemon_by_metadata_slot(metadata_slot: int) -> Dictionary:
	for pokemon_value in trainer_enemy_team:
		if not (pokemon_value is Dictionary):
			continue

		var trainer_pokemon: Dictionary = pokemon_value as Dictionary
		if int(trainer_pokemon.get("metadataSlot", trainer_pokemon.get("metadata_slot", 0))) == metadata_slot:
			return trainer_pokemon

	return {}


func _copy_backend_pokemon_metadata(display_data: Dictionary, backend_pokemon: Dictionary) -> void:
	var species := str(backend_pokemon.get("species", backend_pokemon.get("displaySpecies", "")))
	if species != "" and not _has_temporary_battle_display_form(display_data):
		display_data["displaySpecies"] = species
		display_data["species"] = species

	for key in ["shiny", "types", "possibleAbilities"]:
		if backend_pokemon.has(key):
			display_data[key] = backend_pokemon.get(key)
