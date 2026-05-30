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
