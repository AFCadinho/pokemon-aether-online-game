extends RefCounted

class_name BattlePresentationState

var field: Dictionary = {"effects": []}
var has_field_snapshot := false
var turn := 0


func reset() -> void:
	field = {"effects": []}
	has_field_snapshot = false
	turn = 0


func sync_field_from_snapshot(field_snapshot: Variant, snapshot_turn := -1) -> void:
	if field_snapshot is Dictionary:
		field = (field_snapshot as Dictionary).duplicate(true)
	else:
		field = {"effects": []}

	if not (field.get("effects", []) is Array):
		field["effects"] = []

	has_field_snapshot = true
	if snapshot_turn >= 0:
		turn = snapshot_turn


func set_turn(next_turn: int) -> void:
	if next_turn > 0:
		turn = next_turn


func get_turn() -> int:
	return turn


func get_field_effects() -> Array:
	var effects_value: Variant = field.get("effects", [])
	if effects_value is Array:
		return effects_value as Array

	return []


func apply_event(event: Dictionary, current_turn := 0) -> bool:
	if str(event.get("type", "")) != "fieldEffect":
		return false

	var state := str(event.get("state", "")).to_lower()
	match state:
		"start":
			_apply_field_effect_start(event, current_turn)
			return true
		"end":
			_apply_field_effect_end(event)
			return true
		"upkeep":
			_apply_field_effect_upkeep(event)
			return true
		"swap":
			_swap_side_conditions()
			return true

	return false


func _apply_field_effect_start(event: Dictionary, current_turn: int) -> void:
	var effect_data := _field_effect_data_from_event(event, current_turn)
	if _is_weather_none_effect(effect_data):
		_remove_weather_effects()
		return

	var effect_type := str(effect_data.get("effectType", ""))
	match effect_type:
		"weather":
			_remove_weather_effects()
			_append_field_effect(effect_data)
		"fieldCondition":
			var effect_group := str(effect_data.get("effectGroup", ""))
			if effect_group != "":
				_remove_field_effect_group(effect_group)
			else:
				_remove_matching_field_effect(effect_data)
			_append_field_effect(effect_data)
		"sideCondition":
			_apply_side_condition_start(effect_data)
		_:
			_remove_matching_field_effect(effect_data)
			_append_field_effect(effect_data)


func _apply_side_condition_start(effect_data: Dictionary) -> void:
	var existing_index := _find_matching_field_effect_index(effect_data)
	if existing_index < 0:
		_append_field_effect(effect_data)
		return

	var effects := get_field_effects()
	var existing_value: Variant = effects[existing_index]
	if not (existing_value is Dictionary):
		effects[existing_index] = effect_data
		return

	var existing_effect: Dictionary = existing_value as Dictionary
	for key: Variant in effect_data.keys():
		if str(key) == "startedTurn" and existing_effect.has("startedTurn"):
			continue
		existing_effect[key] = effect_data[key]
	effects[existing_index] = existing_effect


func _apply_field_effect_end(event: Dictionary) -> void:
	var effect_data := _field_effect_data_from_event(event)
	if _is_weather_none_effect(effect_data):
		_remove_weather_effects()
		return

	match str(effect_data.get("effectType", "")):
		"weather":
			_remove_weather_effects()
		_:
			_remove_matching_field_effect(effect_data)


func _apply_field_effect_upkeep(event: Dictionary) -> void:
	var effect_data := _field_effect_data_from_event(event)
	var existing_index := _find_matching_field_effect_index(effect_data)
	if existing_index < 0:
		return

	var effects := get_field_effects()
	var existing_value: Variant = effects[existing_index]
	if not (existing_value is Dictionary):
		return

	var existing_effect: Dictionary = existing_value as Dictionary
	for key: Variant in effect_data.keys():
		if str(key) == "startedTurn" and existing_effect.has("startedTurn"):
			continue
		existing_effect[key] = effect_data[key]
	effects[existing_index] = existing_effect


func _swap_side_conditions() -> void:
	for effect_value: Variant in get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("scope", "")) != "side":
			continue
		if str(effect_data.get("effectType", "")) != "sideCondition":
			continue

		match str(effect_data.get("side", "")):
			"p1":
				effect_data["side"] = "p2"
			"p2":
				effect_data["side"] = "p1"


func _field_effect_data_from_event(event: Dictionary, current_turn := 0) -> Dictionary:
	var effect_data := event.duplicate(true)
	for key in [
		"type",
		"state",
		"source",
		"sourceTarget",
		"sourcePokemon",
		"actor",
		"target",
		"pokemon",
		"turn",
		"seq",
		"eventSeq",
		"batchSeq",
		"eventBatchId",
	]:
		effect_data.erase(key)

	if current_turn > 0 and not effect_data.has("startedTurn"):
		effect_data["startedTurn"] = current_turn

	return effect_data


func _append_field_effect(effect_data: Dictionary) -> void:
	var effects := get_field_effects()
	effects.append(effect_data.duplicate(true))
	field["effects"] = effects


func _remove_weather_effects() -> void:
	var filtered: Array = []
	for effect_value in get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("effectType", "")) == "weather":
			continue

		filtered.append(effect_data)

	field["effects"] = filtered


func _remove_field_effect_group(effect_group: String) -> void:
	var filtered: Array = []
	for effect_value in get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("effectGroup", "")) == effect_group:
			continue

		filtered.append(effect_data)

	field["effects"] = filtered


func _remove_matching_field_effect(effect_data: Dictionary) -> void:
	var filtered: Array = []
	for effect_value in get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var existing_effect: Dictionary = effect_value as Dictionary
		if _same_field_effect(existing_effect, effect_data):
			continue

		filtered.append(existing_effect)

	field["effects"] = filtered


func _find_matching_field_effect_index(effect_data: Dictionary) -> int:
	var effects := get_field_effects()
	for index in range(effects.size()):
		var effect_value: Variant = effects[index]
		if not (effect_value is Dictionary):
			continue

		if _same_field_effect(effect_value as Dictionary, effect_data):
			return index

	return -1


func _same_field_effect(left: Dictionary, right: Dictionary) -> bool:
	var left_effect_type := str(left.get("effectType", ""))
	var right_effect_type := str(right.get("effectType", ""))
	if left_effect_type != "" and right_effect_type != "" and left_effect_type != right_effect_type:
		return false

	if left_effect_type == "weather" or right_effect_type == "weather":
		return true

	var left_scope := str(left.get("scope", ""))
	var right_scope := str(right.get("scope", ""))
	if left_scope != "" and right_scope != "" and left_scope != right_scope:
		return false

	if left_scope == "side" or right_scope == "side":
		if str(left.get("side", "")) != str(right.get("side", "")):
			return false

	var left_group := str(left.get("effectGroup", ""))
	var right_group := str(right.get("effectGroup", ""))
	if left_group != "" and right_group != "" and left_group != right_group:
		return false

	return _field_effect_key(left) == _field_effect_key(right)


func _field_effect_key(effect_data: Dictionary) -> String:
	var effect_id := str(effect_data.get("effectId", "")).strip_edges()
	if effect_id != "":
		return _normalize_effect_key(effect_id)

	var effect := str(effect_data.get("effect", "")).strip_edges()
	if effect.contains(": "):
		effect = effect.split(": ")[1]

	return _normalize_effect_key(effect)


func _normalize_effect_key(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")


func _is_weather_none_effect(effect_data: Dictionary) -> bool:
	if str(effect_data.get("effectType", "")) != "weather":
		return false

	var effect_key := _field_effect_key(effect_data)
	return effect_key == "" or effect_key == "none"
