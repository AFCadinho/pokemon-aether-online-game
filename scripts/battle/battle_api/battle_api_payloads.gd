extends RefCounted

class_name BattleApiPayloads

static func from_player_save(player_save: PlayerData) -> Dictionary:
	return player_save.to_battle_dict()
