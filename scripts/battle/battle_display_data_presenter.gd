extends RefCounted

class_name BattleDisplayDataPresenter

var battle_state: BattleState
var display_metadata := preload("res://scripts/battle/battle_display_metadata.gd").new()


func setup(state: BattleState) -> void:
	battle_state = state
	display_metadata.setup(state)


func set_battle_context(type_value: int, enemy_pokemon: Pokemon) -> void:
	display_metadata.set_battle_context(type_value, enemy_pokemon)


func set_trainer_team(team: Array) -> void:
	display_metadata.set_trainer_team(team)


func get_active_display_species(player_id: String) -> String:
	if battle_state == null:
		return ""

	var active_pokemon := battle_state.get_active_player_pokemon(player_id)
	var transformed_species := str(active_pokemon.get("transformedSpecies", active_pokemon.get("displaySpecies", "")))
	if transformed_species != "":
		return transformed_species

	if player_id == "p1":
		var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
		if saved_pokemon != null:
			return saved_pokemon.species

	return battle_state.get_active_pokemon_species(player_id)


func get_active_pokemon_is_shiny(player_id: String) -> bool:
	if battle_state == null:
		return false

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id).duplicate()
	display_metadata.enrich_display_data(player_id, active_pokemon)
	if player_id == "p1":
		var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
		var saved_by_instance: Pokemon = display_metadata.get_player_save_pokemon_by_instance_id(instance_id)
		if saved_by_instance != null:
			return saved_by_instance.shiny

	var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
	if saved_pokemon != null:
		return saved_pokemon.shiny

	if display_metadata.pokemon_data_has_shiny_value(active_pokemon):
		return display_metadata.get_pokemon_data_shiny_value(active_pokemon)

	return false


func get_display_team_data(player_id: String) -> Array:
	if battle_state == null:
		return []

	var team := battle_state.get_player_team(player_id)
	var display_team: Array = []
	for index in range(team.size()):
		var pokemon_data: Variant = team[index]
		if not (pokemon_data is Dictionary):
			display_team.append(pokemon_data)
			continue

		var display_data: Dictionary = get_display_pokemon_data(player_id, pokemon_data as Dictionary)
		if player_id == "p1":
			_enrich_player_display_slot_from_save(display_data, index)
		display_team.append(display_data)

	return display_team


func get_display_pokemon_data(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	var display_data := pokemon_data.duplicate()
	display_metadata.enrich_display_data(player_id, display_data)
	return display_data

func _enrich_player_display_slot_from_save(display_data: Dictionary, index: int) -> void:
	if index < 0 or index >= PlayerSave.party.size():
		return

	var saved_pokemon: Pokemon = PlayerSave.party[index] as Pokemon
	if saved_pokemon == null:
		return

	var types_value: Variant = display_data.get("types", [])
	if not display_data.has("types") or not (types_value is Array) or (types_value as Array).is_empty():
		display_data["types"] = saved_pokemon.types
	if not display_data.has("possibleAbilities"):
		display_data["possibleAbilities"] = saved_pokemon.possible_abilities
	if not display_data.has("shiny"):
		display_data["shiny"] = saved_pokemon.shiny
	if not display_data.has("instanceId") and saved_pokemon.instance_id != "":
		display_data["instanceId"] = saved_pokemon.instance_id
