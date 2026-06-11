extends RefCounted

class_name BattleDisplayDataPresenter

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


func get_active_display_species(player_id: String) -> String:
	if battle_state == null:
		return ""

	if player_id == "p1":
		var active_pokemon := battle_state.get_active_player_pokemon(player_id)
		var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
		var saved_pokemon := get_player_save_pokemon_by_instance_id(instance_id)
		if saved_pokemon != null and saved_species_matches_battle_data(saved_pokemon, active_pokemon):
			return saved_pokemon.species

	return battle_state.get_active_pokemon_species(player_id)


func get_active_pokemon_is_shiny(player_id: String) -> bool:
	if battle_state == null:
		return false

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var instance_id: String = str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
	var saved_pokemon: Pokemon = get_player_save_pokemon_by_instance_id(instance_id)
	if saved_pokemon != null and saved_species_matches_battle_data(saved_pokemon, active_pokemon):
		return saved_pokemon.shiny

	if pokemon_data_has_shiny_value(active_pokemon):
		return get_pokemon_data_shiny_value(active_pokemon)

	if player_id == "p2" and battle_type == BATTLE_TYPE_WILD and active_enemy_pokemon != null:
		if saved_species_matches_battle_data(active_enemy_pokemon, active_pokemon):
			return active_enemy_pokemon.shiny

	return false


func get_display_team_data(player_id: String) -> Array:
	if battle_state == null:
		return []

	var team := battle_state.get_player_team(player_id)
	var display_team: Array = []
	for pokemon_data in team:
		if not (pokemon_data is Dictionary):
			display_team.append(pokemon_data)
			continue

		display_team.append(get_display_pokemon_data(player_id, pokemon_data as Dictionary))

	return display_team


func get_display_pokemon_data(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	var display_data := pokemon_data.duplicate()
	match player_id:
		"p1":
			_enrich_display_data_from_player_save(display_data)
		"p2":
			_enrich_display_data_from_wild_pokemon(display_data)
			_enrich_display_data_from_trainer_team(display_data)

	return display_data


func _enrich_display_data_from_player_save(display_data: Dictionary) -> void:
	var instance_id := str(display_data.get("instanceId", display_data.get("instance_id", "")))
	var saved_pokemon := get_player_save_pokemon_by_instance_id(instance_id)
	if saved_pokemon == null or not saved_species_matches_battle_data(saved_pokemon, display_data):
		return

	display_data["displaySpecies"] = saved_pokemon.species
	display_data["species"] = saved_pokemon.species
	display_data["shiny"] = saved_pokemon.shiny
	display_data["types"] = saved_pokemon.types
	display_data["possibleAbilities"] = saved_pokemon.possible_abilities


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
	var display_species := battle_state.get_species_from_pokemon_data(display_data)
	var normalized_display_species := normalize_species_for_compare(display_species)
	if normalized_display_species == "":
		return {}

	for pokemon_value in trainer_enemy_team:
		if not (pokemon_value is Dictionary):
			continue

		var trainer_pokemon: Dictionary = pokemon_value as Dictionary
		var trainer_species := str(trainer_pokemon.get("species", trainer_pokemon.get("displaySpecies", "")))
		if normalize_species_for_compare(trainer_species) == normalized_display_species:
			return trainer_pokemon

	return {}


func _copy_backend_pokemon_metadata(display_data: Dictionary, backend_pokemon: Dictionary) -> void:
	var species := str(backend_pokemon.get("species", backend_pokemon.get("displaySpecies", "")))
	if species != "":
		display_data["displaySpecies"] = species
		display_data["species"] = species

	for key in ["shiny", "types", "possibleAbilities"]:
		if backend_pokemon.has(key):
			display_data[key] = backend_pokemon.get(key)


func get_player_save_pokemon_by_instance_id(instance_id: String) -> Pokemon:
	if instance_id == "":
		return null

	for pokemon in PlayerSave.party:
		if pokemon.instance_id == instance_id:
			return pokemon

	return null


func saved_species_matches_battle_data(saved_pokemon: Pokemon, pokemon_data: Dictionary) -> bool:
	if battle_state == null:
		return false

	var battle_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if battle_species == "":
		return true

	return normalize_species_for_compare(saved_pokemon.species) == normalize_species_for_compare(battle_species)


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
