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

	if player_id == "p1":
		var active_pokemon := battle_state.get_active_player_pokemon(player_id)
		var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
		if saved_pokemon != null:
			return saved_pokemon.species

	return battle_state.get_active_pokemon_species(player_id)


func get_active_pokemon_is_shiny(player_id: String) -> bool:
	if battle_state == null:
		return false

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id).duplicate()
	display_metadata.enrich_display_data(player_id, active_pokemon)
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
	for pokemon_data in team:
		if not (pokemon_data is Dictionary):
			display_team.append(pokemon_data)
			continue

		display_team.append(get_display_pokemon_data(player_id, pokemon_data as Dictionary))

	return display_team


func get_display_pokemon_data(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	var display_data := pokemon_data.duplicate()
	display_metadata.enrich_display_data(player_id, display_data)
	return display_data
