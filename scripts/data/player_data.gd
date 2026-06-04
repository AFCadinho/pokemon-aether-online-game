extends Node

class_name PlayerData # PlayerSave Autoload

signal party_changed

var player_name := "Player"
var is_staff := true
var party: Array[Pokemon] = []
var money := 0
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
		var hp_data := _parse_battle_condition(str(pokemon_data.get("condition", "")))

		pokemon.current_hp = int(hp_data.get("current_hp", pokemon.current_hp))
		pokemon.max_hp = int(hp_data.get("max_hp", pokemon.max_hp))
		pokemon.has_saved_hp_state = true

	party_changed.emit()

func _parse_battle_condition(condition: String) -> Dictionary:
	var result := {}

	if condition.contains("/"):
		var parts := condition.split("/")
		result["current_hp"] = int(parts[0])
		result["max_hp"] = max(int(str(parts[1]).split(" ")[0]), 1)
	elif condition.contains("fnt"):
		result["current_hp"] = 0

	return result
