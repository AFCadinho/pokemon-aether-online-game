extends SceneTree

const MOVE_DISPLAY_TYPE := preload("res://scripts/battle/battle_ui/move_display_type.gd")

var failed := false


func _init() -> void:
	_check_type(
		{
			"id": "hidden-power",
			"name": "Hidden Power Grass",
			"type": "normal",
			"hiddenPowerType": "grass",
		},
		"grass",
		"Hidden Power uses its explicit variant type",
	)
	_check_type(
		{"id": "hidden-power", "name": "Hidden Power Ice", "type": "normal"},
		"ice",
		"Hidden Power can recover its variant type from its display name",
	)
	_check_type(
		{"id": "hidden-power", "variantId": "hidden-power-fire", "type": "normal"},
		"fire",
		"Hidden Power can recover its variant type from its variant id",
	)
	_check_type(
		{"id": "thunderbolt", "name": "Thunderbolt", "type": "electric"},
		"electric",
		"Regular moves keep their catalog type",
	)
	_check_type(
		{"id": "hidden-power", "name": "Hidden Power", "type": "normal"},
		"normal",
		"Base Hidden Power safely keeps its fallback type",
	)
	quit(1 if failed else 0)


func _check_type(move_data: Dictionary, expected: String, message: String) -> void:
	var actual := MOVE_DISPLAY_TYPE.resolve(move_data)
	if actual == expected:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s (expected %s, got %s)" % [message, expected, actual])
