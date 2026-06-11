extends RefCounted

class_name BattleDisplayDataPresenter

const BATTLE_TYPE_WILD := 0

var battle_state: BattleState
var battle_type := BATTLE_TYPE_WILD
var active_enemy_pokemon: Pokemon


func setup(state: BattleState) -> void:
	battle_state = state


func set_battle_context(type_value: int, enemy_pokemon: Pokemon) -> void:
	battle_type = type_value
	active_enemy_pokemon = enemy_pokemon


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

	return display_data


func _enrich_display_data_from_player_save(display_data: Dictionary) -> void:
	var instance_id := str(display_data.get("instanceId", display_data.get("instance_id", "")))
	var saved_pokemon := get_player_save_pokemon_by_instance_id(instance_id)
	if saved_pokemon == null or not saved_species_matches_battle_data(saved_pokemon, display_data):
		return

	display_data["displaySpecies"] = saved_pokemon.species
	display_data["shiny"] = saved_pokemon.shiny
	display_data["types"] = saved_pokemon.types
	display_data["possibleAbilities"] = saved_pokemon.possible_abilities


func _enrich_display_data_from_wild_pokemon(display_data: Dictionary) -> void:
	if battle_type != BATTLE_TYPE_WILD or active_enemy_pokemon == null:
		return
	if not saved_species_matches_battle_data(active_enemy_pokemon, display_data):
		return

	display_data["displaySpecies"] = active_enemy_pokemon.species
	display_data["shiny"] = active_enemy_pokemon.shiny
	display_data["types"] = active_enemy_pokemon.types
	display_data["possibleAbilities"] = active_enemy_pokemon.possible_abilities


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
