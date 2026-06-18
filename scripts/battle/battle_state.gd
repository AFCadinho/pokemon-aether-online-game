extends RefCounted

class_name BattleState

var battle_id := ""
var format_id := ""
var players := {}
var requests := {}
var battle_log := []
var battle_status_api := {}
var field: Dictionary = {}
var hp_event_helper := BattleHpEventHelper.new()
var transformed_species_by_ident: Dictionary = {}


## Laadt een volledige battle response van de API in deze state.
func load_from_api_response(response: Dictionary, apply_event_conditions: bool = true) -> void:
	var next_battle_id := str(response.get("battleId", ""))
	if battle_id != "" and next_battle_id != battle_id:
		transformed_species_by_ident.clear()

	battle_id = next_battle_id
	format_id = str(response.get("formatId", ""))
	players = response.get("players", {})
	requests = response.get("requests", {})
	battle_log = response.get("log", [])
	battle_status_api = response.get("state", {})
	field = response.get("field", {})
	if apply_event_conditions:
		_apply_transformed_species_to_requests()
		_apply_event_conditions_to_requests(response.get("events", []))
	else:
		_remove_deferred_transform_fields_from_requests(response.get("events", []))

func apply_event_conditions(events: Array) -> void:
	_apply_event_conditions_to_requests(events)

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
		if event_type == "switch":
			_clear_transform_event_from_requests(event)
			continue

		if event_type == "transform":
			_apply_transform_event_to_requests(event)
			continue

		if event_type == "faint":
			_clear_transformed_species_for_ident(str(event.get("target", "")))

		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident := str(event.get("target", ""))
		var condition := _get_condition_from_event(event)
		if target_ident == "" or condition == "":
			continue

		_set_pokemon_condition(target_ident, condition)

func _get_condition_from_event(event: Dictionary) -> String:
	if _has_percentage_only_condition(event):
		return ""

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

func _has_percentage_only_condition(event: Dictionary) -> bool:
	if event.has("hp"):
		return false

	return hp_event_helper.is_percentage_only_condition_event(event, false)

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
			_apply_condition_fields(pokemon_data, condition)
			return

func _apply_transform_event_to_requests(event: Dictionary) -> void:
	var target_ident := str(event.get("target", ""))
	var species := str(event.get("species", ""))
	if target_ident == "" or species == "":
		return

	var transform_key := _get_transform_key_from_ident(target_ident)
	if transform_key != "":
		transformed_species_by_ident[transform_key] = species

	var pokemon_data := _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		return

	pokemon_data["displaySpecies"] = species
	pokemon_data["transformedSpecies"] = species

func _remove_deferred_transform_fields_from_requests(events_value: Variant) -> void:
	if not (events_value is Array):
		return

	for event_value in events_value:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) != "transform":
			continue

		var target_ident := str(event.get("target", ""))
		var original_species := _get_original_species_from_ident(target_ident)
		var pokemon_data := _get_side_pokemon_by_ident(target_ident)
		if pokemon_data.is_empty():
			continue

		pokemon_data.erase("transformedSpecies")
		pokemon_data.erase("displaySpecies")
		if original_species != "":
			pokemon_data["species"] = original_species

func _clear_transform_event_from_requests(event: Dictionary) -> void:
	_clear_transformed_species_for_ident(str(event.get("fromIdent", "")))
	_clear_transformed_species_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))

func _clear_transformed_species_for_ident(ident: String) -> void:
	var transform_key := _get_transform_key_from_ident(ident)
	if transform_key == "":
		return

	var transformed_species := str(transformed_species_by_ident.get(transform_key, ""))
	var pokemon_data := _get_side_pokemon_by_transform_key(transform_key)
	if not pokemon_data.is_empty():
		pokemon_data.erase("transformedSpecies")
		if transformed_species != "" and str(pokemon_data.get("displaySpecies", "")) == transformed_species:
			pokemon_data.erase("displaySpecies")

	transformed_species_by_ident.erase(transform_key)

func _apply_transformed_species_to_requests() -> void:
	for transform_key in transformed_species_by_ident.keys():
		var species := str(transformed_species_by_ident.get(transform_key, ""))
		if species == "":
			continue

		var pokemon_data := _get_side_pokemon_by_transform_key(str(transform_key))
		if pokemon_data.is_empty():
			continue

		pokemon_data["displaySpecies"] = species
		pokemon_data["transformedSpecies"] = species

func _get_side_pokemon_by_ident(target_ident: String) -> Dictionary:
	var player_id := _get_player_id_from_ident(target_ident)
	var target_name := _get_pokemon_name_from_ident(target_ident)
	if player_id == "" or target_name == "":
		return {}

	var request_value: Variant = requests.get(player_id, {})
	if not (request_value is Dictionary):
		return {}

	var request: Dictionary = request_value as Dictionary
	var side_value: Variant = request.get("side", {})
	if not (side_value is Dictionary):
		return {}

	var side: Dictionary = side_value as Dictionary
	var team_value: Variant = side.get("pokemon", [])
	if not (team_value is Array):
		return {}

	var team: Array = team_value as Array
	for pokemon_value in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_name_from_ident(str(pokemon_data.get("ident", ""))) == target_name:
			return pokemon_data

	return {}

func _get_side_pokemon_by_transform_key(transform_key: String) -> Dictionary:
	for player_id in ["p1", "p2"]:
		var request_value: Variant = requests.get(player_id, {})
		if not (request_value is Dictionary):
			continue

		var request: Dictionary = request_value as Dictionary
		var side_value: Variant = request.get("side", {})
		if not (side_value is Dictionary):
			continue

		var side: Dictionary = side_value as Dictionary
		var team_value: Variant = side.get("pokemon", [])
		if not (team_value is Array):
			continue

		var team: Array = team_value as Array
		for pokemon_value in team:
			if not (pokemon_value is Dictionary):
				continue

			var pokemon_data: Dictionary = pokemon_value as Dictionary
			if _get_transform_key_from_ident(str(pokemon_data.get("ident", ""))) == transform_key:
				return pokemon_data

	return {}

func _get_transform_key_from_ident(ident: String) -> String:
	var player_id := _get_player_id_from_ident(ident)
	var pokemon_name := _get_pokemon_name_from_ident(ident)
	if player_id == "" or pokemon_name == "":
		return ""

	return "%s:%s" % [player_id, pokemon_name]

func _get_original_species_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges()

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

func get_active_pokemon_status(player_id: String = "p1") -> String:
	var pokemon_data := get_active_player_pokemon(player_id)
	return str(pokemon_data.get("status", ""))

func get_active_pokemon_gender(player_id: String = "p1") -> String:
	var pokemon_data := get_active_player_pokemon(player_id)
	return str(pokemon_data.get("gender", ""))

## Geeft de speciesnaam van de actieve Pokemon terug.
func get_active_pokemon_species(player_id: String = "p1") -> String:
	return get_species_from_pokemon_data(get_active_player_pokemon(player_id))

func get_species_from_pokemon_data(pokemon_data: Dictionary) -> String:
	var display_species := str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var species := str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return ""

## Geeft het level van de actieve pokemon terug.
func get_active_pokemon_level(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("level"):
		return int(pokemon_data.get("level", 100))

	return 100

## Geeft de huidige HP van de actieve Pokemon terug.
func get_active_pokemon_current_hp(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("hp"):
		return int(pokemon_data.get("hp", 0))

	return 0

## Geef de huidige HP van de pokemon terug.
func get_active_pokemon_max_hp(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("maxHp"):
		return int(pokemon_data.get("maxHp", 0))

	return 0

func is_active_pokemon_fainted(player_id: String = "p1") -> bool:
	var pokemon_data := get_active_player_pokemon(player_id)
	return bool(pokemon_data.get("fainted", false))

func _apply_condition_fields(pokemon_data: Dictionary, condition: String) -> void:
	hp_event_helper.apply_condition_fields(pokemon_data, condition)

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
