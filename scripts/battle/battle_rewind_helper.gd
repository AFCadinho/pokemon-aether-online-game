extends RefCounted

class_name BattleRewindHelper


func get_rewound_team_data_for_events(player_id: String, team: Array, events: Array) -> Array:
	var previous_conditions_by_name: Dictionary = get_previous_conditions_by_pokemon_name_for_events(player_id, events)
	if previous_conditions_by_name.is_empty():
		return team

	var rewound_team: Array = []
	for pokemon_value in team:
		if not (pokemon_value is Dictionary):
			rewound_team.append(pokemon_value)
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate()
		var pokemon_name: String = get_ident_pokemon_name(str(pokemon_data.get("ident", "")))
		if previous_conditions_by_name.has(pokemon_name):
			pokemon_data["condition"] = str(previous_conditions_by_name.get(pokemon_name, pokemon_data.get("condition", "")))

		rewound_team.append(pokemon_data)

	return rewound_team


func get_previous_conditions_by_pokemon_name_for_events(player_id: String, events: Array) -> Dictionary:
	var previous_conditions_by_name: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		if _get_player_id_from_ident(target_ident) != player_id:
			continue

		var pokemon_name: String = get_ident_pokemon_name(target_ident)
		var previous_condition: String = str(event.get("previousCondition", ""))
		if pokemon_name == "" or previous_condition == "" or previous_conditions_by_name.has(pokemon_name):
			continue

		previous_conditions_by_name[pokemon_name] = previous_condition

	return previous_conditions_by_name


func get_ident_pokemon_name(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
