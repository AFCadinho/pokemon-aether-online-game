extends RefCounted

class_name BattleSideConditionTracker

var debug_enabled := false
var active_side_condition_effects: Dictionary = {
	"p1": {},
	"p2": {},
}
var previous_side_condition_effects_before_response: Dictionary = {
	"p1": {},
	"p2": {},
}


func reset() -> void:
	active_side_condition_effects = {
		"p1": {},
		"p2": {},
	}
	previous_side_condition_effects_before_response = {
		"p1": {},
		"p2": {},
	}


func remember_from_response(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) != "fieldEffect":
			continue
		if not _is_side_condition_effect(event):
			continue

		var side_id: String = _get_side_condition_side_id(event)
		if not active_side_condition_effects.has(side_id):
			continue

		var effect_key: String = get_effect_key(event)
		if effect_key == "":
			continue

		var side_effects: Dictionary = active_side_condition_effects[side_id] as Dictionary
		var previous_side_effects_value: Variant = previous_side_condition_effects_before_response.get(side_id, {})
		var previous_side_effects: Dictionary = {}
		if previous_side_effects_value is Dictionary:
			previous_side_effects = previous_side_effects_value as Dictionary

		var state: String = str(event.get("state", ""))
		if state == "end":
			_debug("event end side=%s key=%s event=%s" % [
				side_id,
				effect_key,
				JSON.stringify(event),
			])
			side_effects.erase(effect_key)
		else:
			var current_layers_before_event: int = _get_side_condition_layer_count_from_value(side_effects.get(effect_key, {}))
			side_effects[effect_key] = _get_side_condition_effect_with_layers(
				event,
				previous_side_effects.get(effect_key, {}),
				side_effects.get(effect_key, {}),
				effect_key,
				state
			)
			_debug("event set side=%s key=%s state=%s previous=%s current=%s incoming=%s stored=%s event=%s" % [
				side_id,
				effect_key,
				state,
				_get_side_condition_layer_count_from_value(previous_side_effects.get(effect_key, {})),
				current_layers_before_event,
				_get_side_condition_layer_count(event),
				_get_side_condition_layer_count_from_value(side_effects.get(effect_key, {})),
				JSON.stringify(event),
			])


func remember_from_field_snapshot(field_effects: Array) -> void:
	var previous_side_condition_effects: Dictionary = {}
	for side_id in active_side_condition_effects.keys():
		var previous_side_effects_value: Variant = active_side_condition_effects.get(side_id, {})
		if previous_side_effects_value is Dictionary:
			previous_side_condition_effects[side_id] = (previous_side_effects_value as Dictionary).duplicate()
		else:
			previous_side_condition_effects[side_id] = {}

		active_side_condition_effects[side_id] = {}

	previous_side_condition_effects_before_response = previous_side_condition_effects.duplicate(true)

	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if not _is_side_condition_effect(effect_data):
			continue

		var side_id: String = _get_side_condition_side_id(effect_data)
		if not active_side_condition_effects.has(side_id):
			continue

		var effect_key: String = get_effect_key(effect_data)
		if effect_key == "":
			continue

		var side_effects: Dictionary = active_side_condition_effects[side_id] as Dictionary
		var previous_side_effects: Dictionary = previous_side_condition_effects.get(side_id, {}) as Dictionary
		side_effects[effect_key] = _get_side_condition_effect_with_preserved_layers(effect_data, previous_side_effects.get(effect_key, {}), effect_key)
		_debug("snapshot set side=%s key=%s previous=%s incoming=%s stored=%s effect=%s" % [
			side_id,
			effect_key,
			_get_side_condition_layer_count_from_value(previous_side_effects.get(effect_key, {})),
			_get_side_condition_layer_count(effect_data),
			_get_side_condition_layer_count_from_value(side_effects.get(effect_key, {})),
			JSON.stringify(effect_data),
		])


func get_active_effects(side_id: String, field_effect_started_turns: Dictionary) -> Array:
	var side_effects_value: Variant = active_side_condition_effects.get(side_id, {})
	if not (side_effects_value is Dictionary):
		return []

	var side_effects: Dictionary = side_effects_value as Dictionary
	var effects_with_started_turns: Array = []
	for effect_value in side_effects.values():
		if not (effect_value is Dictionary):
			effects_with_started_turns.append(effect_value)
			continue

		var effect_data: Dictionary = (effect_value as Dictionary).duplicate()
		var effect_key: String = get_field_effect_key(effect_data)
		if field_effect_started_turns.has(effect_key):
			effect_data["startedTurn"] = int(field_effect_started_turns.get(effect_key, effect_data.get("startedTurn", 0)))

		effects_with_started_turns.append(effect_data)

	return effects_with_started_turns


func get_field_effect_key(effect_data: Dictionary) -> String:
	var effect := get_normalized_field_effect_key(str(effect_data.get("effect", "")))
	if effect == "":
		return ""

	var key_parts := PackedStringArray([
		str(effect_data.get("side", "")),
		effect,
	])
	return "|".join(key_parts)


func get_normalized_field_effect_key(effect: String) -> String:
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


func get_effect_key(effect_data: Dictionary) -> String:
	var effect: String = str(effect_data.get("effect", ""))
	if effect == "":
		return ""

	if effect.contains(": "):
		effect = effect.split(": ")[1]

	return effect.to_lower().replace(" ", "").replace("_", "").replace("-", "")


func _is_side_condition_effect(effect_data: Dictionary) -> bool:
	var effect_type: String = str(effect_data.get("effectType", ""))
	if effect_type == "sideCondition":
		return true

	if str(effect_data.get("scope", "")) == "side":
		return true

	return _is_entry_hazard_effect(effect_data)


func _get_side_condition_side_id(effect_data: Dictionary) -> String:
	var side_id: String = str(effect_data.get("side", ""))
	if side_id == "p1" or side_id == "p2":
		return side_id

	var source_ident: String = str(effect_data.get("sourceTarget", effect_data.get("sourcePokemon", effect_data.get("actor", ""))))
	var source_player_id: String = _get_player_id_from_ident(source_ident)
	if source_player_id == "p1":
		return "p2"
	if source_player_id == "p2":
		return "p1"

	var target_ident: String = str(effect_data.get("target", ""))
	return _get_player_id_from_ident(target_ident)


func _is_entry_hazard_effect(effect_data: Dictionary) -> bool:
	match get_effect_key(effect_data):
		"stealthrock", "spikes", "toxicspikes", "stickyweb", "stickywebs":
			return true

	return false


func _get_side_condition_effect_with_layers(effect_data: Dictionary, previous_effect_value: Variant, current_effect_value: Variant, effect_key: String, state: String) -> Dictionary:
	var next_effect: Dictionary = _get_merged_side_condition_effect_data(effect_data, current_effect_value, false)
	if not _is_layered_side_condition_key(effect_key):
		return next_effect

	var max_layers: int = _get_side_condition_max_layers(effect_key)
	var previous_layers: int = _get_side_condition_layer_count_from_value(previous_effect_value)
	var current_layers: int = _get_side_condition_layer_count_from_value(current_effect_value)
	var incoming_layers: int = _get_side_condition_layer_count(effect_data)
	if state == "start":
		if incoming_layers > previous_layers:
			next_effect["layers"] = clamp(incoming_layers, 1, max_layers)
		else:
			next_effect["layers"] = clamp(previous_layers + 1, 1, max_layers)
		return next_effect

	if current_layers > 0:
		next_effect["layers"] = clamp(current_layers, 1, max_layers)
	elif incoming_layers > 0:
		next_effect["layers"] = clamp(incoming_layers, 1, max_layers)
	elif previous_layers > 0:
		next_effect["layers"] = clamp(previous_layers, 1, max_layers)
	else:
		next_effect["layers"] = 1

	return next_effect


func _get_side_condition_effect_with_preserved_layers(effect_data: Dictionary, previous_effect_value: Variant, effect_key: String) -> Dictionary:
	var next_effect: Dictionary = _get_merged_side_condition_effect_data(effect_data, previous_effect_value, true)
	if not _is_layered_side_condition_key(effect_key):
		return next_effect

	var incoming_layers: int = _get_side_condition_layer_count(effect_data)
	var previous_layers: int = _get_side_condition_layer_count_from_value(previous_effect_value)
	if previous_layers > 0:
		next_effect["layers"] = clamp(previous_layers, 1, _get_side_condition_max_layers(effect_key))
	elif incoming_layers > 0:
		next_effect["layers"] = clamp(incoming_layers, 1, _get_side_condition_max_layers(effect_key))

	return next_effect


func _get_merged_side_condition_effect_data(effect_data: Dictionary, previous_effect_value: Variant, preserve_layer_counts: bool = true) -> Dictionary:
	var next_effect: Dictionary = effect_data.duplicate()
	if not (previous_effect_value is Dictionary):
		return next_effect

	var previous_effect: Dictionary = previous_effect_value as Dictionary
	if preserve_layer_counts:
		for key in ["layers", "layer", "count"]:
			if not next_effect.has(key) and previous_effect.has(key):
				next_effect[key] = previous_effect.get(key)

	for key in [
		"startedTurn",
		"minDuration",
		"maxDuration",
		"duration",
		"minRemainingTurns",
		"maxRemainingTurns",
		"remainingTurns",
		"turns",
	]:
		if not next_effect.has(key) and previous_effect.has(key):
			next_effect[key] = previous_effect.get(key)

	return next_effect


func _is_layered_side_condition_key(effect_key: String) -> bool:
	match effect_key:
		"spikes", "toxicspikes":
			return true

	return false


func _get_side_condition_max_layers(effect_key: String) -> int:
	match effect_key:
		"spikes":
			return 3
		"toxicspikes":
			return 2

	return 1


func _get_side_condition_layer_count_from_value(effect_value: Variant) -> int:
	if not (effect_value is Dictionary):
		return 0

	return _get_side_condition_layer_count(effect_value as Dictionary)


func _get_side_condition_layer_count(effect_data: Dictionary) -> int:
	for key in ["layers", "layer", "count"]:
		if effect_data.has(key):
			return int(effect_data.get(key, 0))

	return 0


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""


func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()


func _debug(message: String) -> void:
	if debug_enabled:
		print("[side-effects] " + message)
