extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "field-delta-battle",
		"field": {
			"effects": [
				{
					"scope": "field",
					"effectType": "weather",
					"effectId": "SunnyDay",
				},
				{
					"scope": "field",
					"effectType": "fieldCondition",
					"effectGroup": "terrain",
					"effectId": "ElectricTerrain",
				},
			],
		},
	}, false)

	state.load_from_api_response({
		"battleId": "field-delta-battle",
		"events": [],
	}, false)
	_check_equal(
		state.get_field_effects().size(),
		2,
		"a delta without field preserves active weather and terrain"
	)

	state.load_from_api_response({
		"battleId": "field-delta-battle",
		"field": {"effects": []},
	}, false)
	_check_equal(
		state.get_field_effects().size(),
		0,
		"an explicit empty field snapshot clears active effects"
	)

	state.load_from_api_response({
		"battleId": "field-delta-battle",
		"field": {
			"effects": [{
				"scope": "field",
				"effectType": "weather",
				"effectId": "RainDance",
			}],
		},
	}, false)
	state.load_from_api_response({
		"battleId": "next-battle-without-field",
	}, false)
	_check_equal(
		state.get_field_effects().size(),
		0,
		"a new battle cannot inherit the previous battle's field"
	)

	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS: %s" % message)
		return

	failed = true
	push_error("FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
