extends RefCounted

class_name BattleFieldEffectTracker

var known_field_effect_keys := {}
var field_effect_started_turns := {}
var pending_field_start_events: Array[Dictionary] = []


func reset() -> void:
	known_field_effect_keys.clear()
	field_effect_started_turns.clear()
	pending_field_start_events.clear()


func get_known_keys() -> Dictionary:
	return known_field_effect_keys.duplicate()


func get_started_turns() -> Dictionary:
	return field_effect_started_turns


func remember_start_turns_from_response(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	var event_turn: int = _get_initial_event_turn(response, events)
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type == "turn":
			event_turn = max(int(event.get("turn", event_turn)), 1)
			continue

		if event_type != "fieldEffect":
			continue

		var event_key: String = get_effect_key(event)
		if event_key == "":
			continue

		var state: String = str(event.get("state", ""))
		if state == "start":
			field_effect_started_turns[event_key] = max(event_turn, 1)
		elif state == "end":
			field_effect_started_turns.erase(event_key)


func queue_missing_start_events(field_effects: Array, previous_field_effect_keys: Dictionary, current_turn: int) -> void:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var effect_key: String = get_effect_key(effect_data)
		if effect_key == "" or previous_field_effect_keys.has(effect_key):
			continue

		var start_event: Dictionary = effect_data.duplicate()
		start_event["type"] = "fieldEffect"
		start_event["state"] = "start"
		var started_turn: int = max(current_turn - 1, 1)
		start_event["startedTurn"] = started_turn
		field_effect_started_turns[effect_key] = started_turn
		pending_field_start_events.append(start_event)


func remember_current(field_effects: Array) -> void:
	known_field_effect_keys.clear()
	var active_field_effect_keys: Dictionary = {}

	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var effect_key: String = get_effect_key(effect_data)
		if effect_key != "":
			known_field_effect_keys[effect_key] = true
			active_field_effect_keys[effect_key] = true

	for effect_key in field_effect_started_turns.keys():
		if not active_field_effect_keys.has(effect_key):
			field_effect_started_turns.erase(effect_key)


func get_effects_with_started_turns(field_effects: Array) -> Array:
	var effects_with_started_turns: Array = []
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			effects_with_started_turns.append(effect_value)
			continue

		var effect_data: Dictionary = (effect_value as Dictionary).duplicate()
		var effect_key: String = get_effect_key(effect_data)
		if field_effect_started_turns.has(effect_key):
			effect_data["startedTurn"] = int(field_effect_started_turns.get(effect_key, effect_data.get("startedTurn", 0)))

		effects_with_started_turns.append(effect_data)

	return effects_with_started_turns


func remove_pending_start_event(event: Dictionary) -> void:
	if str(event.get("state", "")) != "start":
		return

	var event_key: String = get_effect_key(event)
	if event_key == "":
		return

	for idx in range(pending_field_start_events.size() - 1, -1, -1):
		if get_effect_key(pending_field_start_events[idx]) == event_key:
			pending_field_start_events.remove_at(idx)


func consume_pending_start_events() -> Array[Dictionary]:
	var events := pending_field_start_events.duplicate()
	pending_field_start_events.clear()
	return events


func get_active_weather_effect(field_effects: Array) -> String:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = get_normalized_effect_key(str(effect_data.get("effect", "")))
		if str(effect_data.get("effectType", "")) != "weather" and not _is_weather_effect_key(normalized_effect):
			continue

		return normalized_effect

	return ""


func get_active_terrain_effect(field_effects: Array) -> String:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = get_normalized_effect_key(str(effect_data.get("effect", "")))
		var is_terrain_group: bool = str(effect_data.get("effectGroup", "")) == "terrain"
		if not is_terrain_group and not _is_terrain_effect_key(normalized_effect):
			continue

		return normalized_effect

	return ""


func is_trick_room_active(field_effects: Array) -> bool:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = get_normalized_effect_key(str(effect_data.get("effect", "")))
		if normalized_effect == "TrickRoom":
			return true

	return false


func get_effect_key(effect_data: Dictionary) -> String:
	var effect := get_normalized_effect_key(str(effect_data.get("effect", "")))
	if effect == "":
		return ""

	var key_parts := PackedStringArray([
		str(effect_data.get("side", "")),
		effect,
	])
	return "|".join(key_parts)


func get_normalized_effect_key(effect: String) -> String:
	var cleaned: String = _normalize_event_source(effect)
	cleaned = cleaned.replace(" ", "")

	match cleaned:
		"Rain", "RainDance":
			return "RainDance"
		"Sun", "SunnyDay":
			return "SunnyDay"
		"GrassyTerrain":
			return "GrassyTerrain"
		"ElectricTerrain":
			return "ElectricTerrain"
		"MistyTerrain":
			return "MistyTerrain"
		"PsychicTerrain":
			return "PsychicTerrain"
		"TrickRoom":
			return "TrickRoom"

	return cleaned


func _get_initial_event_turn(response: Dictionary, events: Array) -> int:
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) == "turn":
			return max(int(event.get("turn", 1)) - 1, 1)

	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary:
		var state: Dictionary = state_value as Dictionary
		return max(int(state.get("turn", 1)) - 1, 1)

	return 1


func _is_weather_effect_key(effect_key: String) -> bool:
	return effect_key in ["RainDance", "SunnyDay", "Sandstorm", "Hail", "Snow"]


func _is_terrain_effect_key(effect_key: String) -> bool:
	return effect_key in ["GrassyTerrain", "ElectricTerrain", "MistyTerrain", "PsychicTerrain"]


func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()
