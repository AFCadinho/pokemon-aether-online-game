extends Node

class_name PlayerData # PlayerSave Autoload

signal party_changed

var player_name := "Player"
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

	party.append(pokemon)
	party_changed.emit()

func apply_battle_team_state(team: Array) -> void:
	for idx in range(min(party.size(), team.size())):
		var pokemon_data = team[idx]
		if not (pokemon_data is Dictionary):
			continue

		var hp_data := _parse_battle_condition(str(pokemon_data.get("condition", "")))
		party[idx].current_hp = int(hp_data.get("current_hp", party[idx].current_hp))
		party[idx].max_hp = int(hp_data.get("max_hp", party[idx].max_hp))

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
