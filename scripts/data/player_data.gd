extends Node

class_name PlayerData # PlayerSave Autoload

signal party_changed

var player_name := "Player"
var player_id := ""
var is_staff := true
var party: Array[Pokemon] = []
var money := 0
var appearance_body_id: String = CharacterAppearanceService.DEFAULT_BODY_ID
var flags := {}

func to_battle_dict() -> Dictionary:
	return {
		"name": player_name,
		"team": _party_to_battle_team()
	}

func _party_to_battle_team() -> Array:
	var battle_team := []

	for pokemon in party:
		battle_team.append(pokemon.to_battle_dict())

	return battle_team

func add_pokemon(pokemon: Pokemon) -> void:
	if party.size() >= 6:
		return

	pokemon.ensure_instance_id()
	party.append(pokemon)
	party_changed.emit()

func to_party_state() -> Dictionary:
	var party_data: Array = []
	for pokemon in party:
		if pokemon == null:
			continue
		party_data.append(pokemon.to_persistence_dict())

	return {
		"party": party_data,
	}

func replace_party_from_state(party_data: Array) -> void:
	var loaded_party: Array[Pokemon] = []
	for pokemon_value: Variant in party_data:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
		if pokemon == null:
			push_warning("PlayerSave: skipped persisted Pokemon: %s" % PokemonFactory.last_error_message)
			continue

		pokemon.ensure_instance_id()
		loaded_party.append(pokemon)
		if loaded_party.size() >= 6:
			break

	party = loaded_party
	party_changed.emit()

func apply_battle_team_state(team: Array) -> void:
	var party_by_instance_id := {}

	for pokemon in party:
		pokemon.ensure_instance_id()
		party_by_instance_id[pokemon.instance_id] = pokemon

	for pokemon_data in team:
		if not (pokemon_data is Dictionary):
			continue

		var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", "")))
		if instance_id == "":
			continue

		if not party_by_instance_id.has(instance_id):
			continue

		var pokemon: Pokemon = party_by_instance_id[instance_id]
		var hp_data := _get_battle_hp_data(pokemon_data)
		if hp_data.is_empty():
			continue

		_apply_hp_data_to_pokemon(pokemon, hp_data)

	party_changed.emit()

func _apply_hp_data_to_pokemon(pokemon: Pokemon, hp_data: Dictionary) -> void:
	var current_hp := int(hp_data.get("current_hp", pokemon.current_hp))
	var max_hp := int(hp_data.get("max_hp", pokemon.max_hp))

	if current_hp <= 0 and max_hp == 1:
		pokemon.current_hp = 0
		pokemon.has_saved_hp_state = true
		return

	if max_hp == 100 and pokemon.max_hp != 100:
		var hp_percent := int(clamp(current_hp, 0, 100))
		pokemon.current_hp = int(round((float(hp_percent) / 100.0) * float(pokemon.max_hp)))
	else:
		pokemon.max_hp = max(max_hp, 1)
		pokemon.current_hp = int(clamp(current_hp, 0, pokemon.max_hp))

	pokemon.has_saved_hp_state = true

func _get_battle_hp_data(pokemon_data: Dictionary) -> Dictionary:
	if pokemon_data.has("hp"):
		return {
			"current_hp": int(pokemon_data.get("hp", 0)),
			"max_hp": int(pokemon_data.get("maxHp", 1)),
		}

	if bool(pokemon_data.get("fainted", false)):
		return {
			"current_hp": 0,
		}

	return {}
