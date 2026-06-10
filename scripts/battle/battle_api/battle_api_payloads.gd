extends RefCounted

class_name BattleApiPayloads

static func from_player_save(player_save: PlayerData) -> Dictionary:
	return player_save.to_battle_dict()

static func from_wild_pokemon(wild_pokemon: Pokemon) -> Dictionary:
	return {
		"name": "Wild " + wild_pokemon.species,
		"team": [wild_pokemon.to_battle_dict()]
	}
