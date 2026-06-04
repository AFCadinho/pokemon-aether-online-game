extends RefCounted

class_name BattleState

var battle_id := ""
var format_id := ""
var players := {}
var requests := {}
var battle_log := []
var battle_status_api := {}
var field: Dictionary = {}


## Laadt een volledige battle response van de API in deze state.
func load_from_api_response(response: Dictionary) -> void:
	battle_id = str(response.get("battleId", ""))
	format_id = str(response.get("formatId", ""))
	players = response.get("players", {})
	requests = response.get("requests", {})
	battle_log = response.get("log", [])
	battle_status_api = response.get("state", {})
	field = response.get("field", {})
	_apply_event_conditions_to_requests(response.get("events", []))

## Geeft de laatste request-state voor een speler terug.
func get_player_request(player_id: String = "p1") -> Dictionary:
	return requests.get(player_id, {})

## Geeft de side-data voor een speler terug.
func get_player_side(player_id: String = "p1") -> Dictionary:
	return get_player_request(player_id).get("side", {})

func _apply_event_conditions_to_requests(events_value: Variant) -> void:
	if not (events_value is Array):
		return

	for event_value in events_value:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident := str(event.get("target", ""))
		var condition := _get_condition_from_event(event)
		if target_ident == "" or condition == "":
			continue

		_set_pokemon_condition(target_ident, condition)

func _get_condition_from_event(event: Dictionary) -> String:
	var event_condition := str(event.get("condition", ""))
	if event_condition != "":
		return event_condition

	if str(event.get("type", "")) == "faint":
		return "0 fnt"

	if event.has("hp") and event.has("maxHp"):
		var hp := int(event.get("hp", 0))
		var max_hp: int = max(int(event.get("maxHp", 1)), 1)
		if hp <= 0:
			return "0 fnt"

		return "%s/%s" % [hp, max_hp]

	return ""

func _set_pokemon_condition(target_ident: String, condition: String) -> void:
	var player_id := _get_player_id_from_ident(target_ident)
	var target_name := _get_pokemon_name_from_ident(target_ident)
	if player_id == "" or target_name == "":
		return

	var request_value: Variant = requests.get(player_id, {})
	if not (request_value is Dictionary):
		return

	var request: Dictionary = request_value as Dictionary
	var side_value: Variant = request.get("side", {})
	if not (side_value is Dictionary):
		return

	var side: Dictionary = side_value as Dictionary
	var team_value: Variant = side.get("pokemon", [])
	if not (team_value is Array):
		return

	var team: Array = team_value as Array
	for pokemon_value in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_name_from_ident(str(pokemon_data.get("ident", ""))) == target_name:
			pokemon_data["condition"] = condition
			return

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""

func _get_pokemon_name_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()

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
	return get_species_from_pokemon_data(get_active_player_pokemon(player_id))

func get_species_from_pokemon_data(pokemon_data: Dictionary) -> String:
	var details := str(pokemon_data.get("details", ""))
	if details != "":
		return str(details.split(",")[0]).strip_edges()

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

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

## Geeft huidige turn terug
func get_turn() -> int:
	return int(battle_status_api.get("turn", 0))

func get_field_effects() -> Array:
	var effects: Variant = field.get("effects", [])
	if effects is Array:
		return effects as Array

	return []

func is_active_trapped(player_id: String = "p1", active_index: int = 0) -> bool:
	var active_slots: Array = get_player_request(player_id).get("active", [])

	if active_index < 0 or active_index >= active_slots.size():
		return false

	var active_data: Dictionary = active_slots[active_index]
	return bool(active_data.get("trapped", false))

func is_active_maybe_trapped(player_id: String = "p1", active_index: int = 0) -> bool:
	var active_slots: Array = get_player_request(player_id).get("active", [])

	if active_index < 0 or active_index >= active_slots.size():
		return false

	var active_data: Dictionary = active_slots[active_index]
	return bool(active_data.get("maybeTrapped", false))

func needs_force_switch(player_id: String = "p1", active_index: int = 0) -> bool:
	var force_switch: Array = get_player_request(player_id).get("forceSwitch", [])

	if active_index < 0 or active_index >= force_switch.size():
		return false

	return bool(force_switch[active_index])
