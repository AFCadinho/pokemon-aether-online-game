extends SceneTree

const BattlePresentationStateScript := preload("res://scripts/battle/battle_presentation_state.gd")

var failed := false


func _init() -> void:
	_check_stealth_rock_start_waits_for_field_effect()
	_check_spikes_layer_update()
	_check_hazard_removal()
	_check_weather_start_and_end()
	_check_terrain_replacement_and_end()
	_check_screen_start()
	_check_snapshot_direct_sync_for_reconnect()

	quit(1 if failed else 0)


func _check_stealth_rock_start_waits_for_field_effect() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({"effects": []})

	_check_equal(
		_find_effect(state.get_field_effects(), "stealthrock").is_empty(),
		true,
		"stealth rock absent before fieldEffect"
	)

	state.apply_event({
		"type": "fieldEffect",
		"scope": "side",
		"side": "p2",
		"effectType": "sideCondition",
		"effect": "move: Stealth Rock",
		"effectId": "stealthrock",
		"state": "start",
	}, 3)

	_check_equal(
		_find_effect(state.get_field_effects(), "stealthrock").is_empty(),
		false,
		"stealth rock appears at fieldEffect"
	)


func _check_spikes_layer_update() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({
		"effects": [{
			"scope": "side",
			"side": "p2",
			"effectType": "sideCondition",
			"effect": "move: Spikes",
			"effectId": "spikes",
			"layers": 1,
			"startedTurn": 2,
		}],
	})

	state.apply_event({
		"type": "fieldEffect",
		"scope": "side",
		"side": "p2",
		"effectType": "sideCondition",
		"effect": "move: Spikes",
		"effectId": "spikes",
		"layers": 2,
		"state": "start",
	}, 4)

	var spikes := _find_effect(state.get_field_effects(), "spikes")
	_check_equal(int(spikes.get("layers", 0)), 2, "spikes layer updates at fieldEffect")
	_check_equal(int(spikes.get("startedTurn", 0)), 2, "spikes layer update preserves started turn")
	_check_equal(_count_effects(state.get_field_effects(), "spikes"), 1, "spikes layer update does not duplicate effect")


func _check_hazard_removal() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({
		"effects": [{
			"scope": "side",
			"side": "p1",
			"effectType": "sideCondition",
			"effect": "move: Stealth Rock",
			"effectId": "stealthrock",
		}],
	})

	state.apply_event({
		"type": "fieldEffect",
		"scope": "side",
		"side": "p1",
		"effectType": "sideCondition",
		"effect": "move: Stealth Rock",
		"effectId": "stealthrock",
		"state": "end",
	})

	_check_equal(
		_find_effect(state.get_field_effects(), "stealthrock").is_empty(),
		true,
		"hazard removal hides effect at fieldEffect end"
	)


func _check_weather_start_and_end() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({"effects": []})

	state.apply_event({
		"type": "fieldEffect",
		"scope": "field",
		"effectType": "weather",
		"effect": "RainDance",
		"effectId": "RainDance",
		"state": "start",
	}, 5)

	_check_equal(
		_find_effect(state.get_field_effects(), "raindance").is_empty(),
		false,
		"weather start appears at fieldEffect"
	)

	state.apply_event({
		"type": "fieldEffect",
		"scope": "field",
		"effectType": "weather",
		"effect": "none",
		"effectId": "none",
		"state": "end",
	})

	_check_equal(
		_find_effect(state.get_field_effects(), "raindance").is_empty(),
		true,
		"weather end hides weather at fieldEffect"
	)


func _check_terrain_replacement_and_end() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({"effects": []})

	state.apply_event({
		"type": "fieldEffect",
		"scope": "field",
		"effectType": "fieldCondition",
		"effectGroup": "terrain",
		"effect": "move: Electric Terrain",
		"effectId": "electricterrain",
		"state": "start",
	}, 6)
	state.apply_event({
		"type": "fieldEffect",
		"scope": "field",
		"effectType": "fieldCondition",
		"effectGroup": "terrain",
		"effect": "move: Grassy Terrain",
		"effectId": "grassyterrain",
		"state": "start",
	}, 7)

	_check_equal(
		_find_effect(state.get_field_effects(), "electricterrain").is_empty(),
		true,
		"new terrain replaces previous terrain"
	)
	_check_equal(
		_find_effect(state.get_field_effects(), "grassyterrain").is_empty(),
		false,
		"terrain start appears at fieldEffect"
	)

	state.apply_event({
		"type": "fieldEffect",
		"scope": "field",
		"effectType": "fieldCondition",
		"effectGroup": "terrain",
		"effect": "move: Grassy Terrain",
		"effectId": "grassyterrain",
		"state": "end",
	})

	_check_equal(
		_find_effect(state.get_field_effects(), "grassyterrain").is_empty(),
		true,
		"terrain end hides terrain at fieldEffect"
	)


func _check_screen_start() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({"effects": []})

	state.apply_event({
		"type": "fieldEffect",
		"scope": "side",
		"side": "p1",
		"effectType": "sideCondition",
		"effect": "move: Light Screen",
		"effectId": "lightscreen",
		"state": "start",
	}, 8)

	_check_equal(
		_find_effect(state.get_field_effects(), "lightscreen").is_empty(),
		false,
		"screen start appears at fieldEffect"
	)


func _check_snapshot_direct_sync_for_reconnect() -> void:
	var state = BattlePresentationStateScript.new()
	state.sync_field_from_snapshot({
		"effects": [
			{
				"scope": "side",
				"side": "p2",
				"effectType": "sideCondition",
				"effect": "move: Stealth Rock",
				"effectId": "stealthrock",
			},
			{
				"scope": "field",
				"effectType": "weather",
				"effect": "SunnyDay",
				"effectId": "SunnyDay",
			},
		],
	})

	_check_equal(
		_find_effect(state.get_field_effects(), "stealthrock").is_empty(),
		false,
		"snapshot direct sync shows hazard without animation batch"
	)
	_check_equal(
		_find_effect(state.get_field_effects(), "sunnyday").is_empty(),
		false,
		"snapshot direct sync shows weather without animation batch"
	)


func _find_effect(effects: Array, effect_key: String) -> Dictionary:
	var normalized_key := _normalize_effect_key(effect_key)
	for effect_value in effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if _effect_key(effect_data) == normalized_key:
			return effect_data

	return {}


func _count_effects(effects: Array, effect_key: String) -> int:
	var count := 0
	var normalized_key := _normalize_effect_key(effect_key)
	for effect_value in effects:
		if not (effect_value is Dictionary):
			continue

		if _effect_key(effect_value as Dictionary) == normalized_key:
			count += 1

	return count


func _effect_key(effect_data: Dictionary) -> String:
	var effect_id := str(effect_data.get("effectId", "")).strip_edges()
	if effect_id != "":
		return _normalize_effect_key(effect_id)

	var effect := str(effect_data.get("effect", "")).strip_edges()
	if effect.contains(": "):
		effect = effect.split(": ")[1]

	return _normalize_effect_key(effect)


func _normalize_effect_key(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
