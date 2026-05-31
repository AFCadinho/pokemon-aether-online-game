extends RefCounted

class_name BattleState

var battle_id := ""
var format_id := ""
var players := {}
var requests := {}
var battle_log := []
var battle_status_api := {}


## Laadt een volledige battle response van de API in deze state.
func load_from_api_response(response: Dictionary) -> void:
	battle_id = str(response.get("battleId", ""))
	format_id = str(response.get("formatId", ""))
	players = response.get("players", {})
	requests = response.get("requests", {})
	battle_log = response.get("log", [])
	battle_status_api = response.get("state", {})

## Geeft de laatste request-state voor een speler terug.
func get_player_request(player_id: String = "p1") -> Dictionary:
	return requests.get(player_id, {})
	
## Geeft de side-data voor een speler terug.
func get_player_side(player_id: String = "p1") -> Dictionary:
	return get_player_request(player_id).get("side", {})
	
## Geeft alle Pokemon op de side van een speler terug.
func get_player_team(player_id: String = "p1") -> Array:
	return get_player_side(player_id).get("pokemon", [])
	
## Geeft de actieve Pokemon op de side van een speler terug.
func get_active_player_pokemon(player_id: String = "p1") -> Dictionary:
	for pokemon in get_player_team(player_id):
		if pokemon.get("active", false):
			return pokemon
			
	return {}
	
## Geeft de beschikbare moves voor een actieve Pokemon terug.
func get_available_moves(player_id: String = "p1", active_index=0) -> Array:
	var active_moves_slots: Array = get_player_request(player_id).get("active", [])
	
	if active_index >= active_moves_slots.size() or active_index < 0:
		return []
	
	return active_moves_slots[active_index].get("moves", [])

## Geeft terug of de speler nog in team preview zit.
func is_team_preview(player_id: String = "p1") -> bool:
	var request = get_player_request(player_id)
	return request.get("teamPreview", false)
	
## Geeft terug of de battle afgelopen is.
func is_battle_ended() -> bool:
	return bool(battle_status_api.get("ended", false))
	
## Geeft de winnaar terug als de battle afgelopen is.
func get_winner() -> String:
	return str(battle_status_api.get("winner", ""))
	
## Geeft de ident-string van de actieve Pokemon terug.
func get_active_pokemon_ident(player_id: String = "p1") -> String:
	return str(get_active_player_pokemon(player_id).get("ident", ""))
	
## Geeft de details-string van de actieve Pokemon terug.
func get_active_pokemon_details(player_id: String = "p1") -> String:
	return str(get_active_player_pokemon(player_id).get("details", ""))
	
## Geeft de condition-string van de actieve Pokemon terug.
func get_active_pokemon_condition(player_id: String = "p1") -> String:
	return str(get_active_player_pokemon(player_id).get("condition", ""))

## Geeft de speciesnaam van de actieve Pokemon terug.
func get_active_pokemon_species(player_id: String = "p1") -> String:
	var ident := get_active_pokemon_ident(player_id)
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()
		
	var details := get_active_pokemon_details(player_id)
	if details != "":
		return str(details.split(",")[0]).strip_edges()
	
	return ""
	
## Geeft het level van de actieve pokemon terug.
func get_active_pokemon_level(player_id: String) -> int:
	var details := get_active_pokemon_details(player_id)
	
	for part in details.split(","):
		var trimmed := str(part).strip_edges()
		if trimmed.begins_with("L"):
			return int(trimmed.substr(1))
	
	# Geen level betekent default 100
	return 100

## Geeft de huidige HP van de actieve Pokemon terug.
func get_active_pokemon_current_hp(player_id: String) -> int:
	var condition := get_active_pokemon_condition(player_id)
	
	if condition.contains("/"):
		return int(condition.split("/")[0])
	
	return 0

## Geef de huidige HP van de pokemon terug.
func get_active_pokemon_max_hp(player_id: String) -> int:
	var condition := get_active_pokemon_condition(player_id)
	
	if condition.contains("/"):
		var right := str(condition.split("/")[1])
		return int(right.split(" ")[0])
	
	return 0
	
	
