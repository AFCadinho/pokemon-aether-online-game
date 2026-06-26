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

	var mega_species := str(active_pokemon.get("megaSpecies", ""))
	if mega_species != "":
		return mega_species

	var persisted_mega_species := battle_state.resolve_persisted_mega_species_for_ident(str(active_pokemon.get("ident", "")))
	if persisted_mega_species != "":
		return persisted_mega_species

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

	return _sort_display_team_by_canonical_party_slot(display_team)


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

func _sort_display_team_by_canonical_party_slot(display_team: Array) -> Array:
	if display_team.size() <= 1:
		return display_team

	var by_slot: Dictionary = {}
	for pokemon_value: Variant in display_team:
		if not (pokemon_value is Dictionary):
			return display_team

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var slot := _get_canonical_party_slot(pokemon_data)
		if slot <= 0 or by_slot.has(slot):
			return display_team

		by_slot[slot] = pokemon_data

	var sorted_team: Array = []
	var sorted_slots: Array = by_slot.keys()
	sorted_slots.sort()
	for slot_value: Variant in sorted_slots:
		sorted_team.append(by_slot.get(slot_value))

	return sorted_team

func _get_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	var slot_marker := ":slot:"
	if pokemon_key.contains(slot_marker):
		var slot_text := pokemon_key.split(slot_marker)[1]
		if slot_text.is_valid_int():
			var key_slot := int(slot_text)
			if key_slot > 0:
				return key_slot

	for key in ["partySlot", "party_slot", "metadataSlot", "metadata_slot"]:
		if not pokemon_data.has(key):
			continue

		var slot_value: Variant = pokemon_data.get(key)
		if slot_value is int and int(slot_value) > 0:
			return int(slot_value)
		if slot_value is float and int(slot_value) > 0:
			return int(slot_value)

		var explicit_slot_text := str(slot_value).strip_edges()
		if explicit_slot_text.is_valid_int():
			var parsed_slot := int(explicit_slot_text)
			if parsed_slot > 0:
				return parsed_slot

	return -1
