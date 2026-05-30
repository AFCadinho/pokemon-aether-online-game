extends RefCounted

class_name BattleState

var battle_id := ""
var format_id := ""
var players := {}
var requests := {}
var battle_log := []
var battle_status_api := {}


func load_from_api_response(response: Dictionary) -> void:
	battle_id = str(response.get("battleId", ""))
	format_id = str(response.get("formatId", ""))
	players = response.get("players", {})
	requests = response.get("requests", {})
	battle_log = response.get("log", [])
	battle_status_api = response.get("state", {})

func get_player_request(player_id: String = "p1") -> Dictionary:
	return requests.get(player_id, {})
	
func get_player_side(player_id: String = "p1") -> Dictionary:
	return get_player_request(player_id).get("side", {})
	
func get_player_team(player_id: String = "p1") -> Array:
	return get_player_side(player_id).get("pokemon", [])
	
func get_active_player_pokemon(player_id: String = "p1") -> Dictionary:
	for pokemon in get_player_team():
		if pokemon.get("active", false):
			return pokemon
			
	return {}
	
func get_available_moves(player_id: String = "p1", active_index=0) -> Array:
	var active_moves_slots: Array = get_player_request(player_id).get("active", [])
	
	if active_index >= active_moves_slots.size() or active_index < 0:
		return []
	
	return active_moves_slots[active_index].get("moves", [])

func is_team_preview(player_id: String = "p1") -> bool:
	var request = get_player_request(player_id)
	return request.get("teamPreview", false)
	
func is_battle_ended() -> bool:
	return bool(battle_status_api.get("ended", false))
	
func get_winner() -> String:
	return str(battle_status_api.get("winner", ""))
