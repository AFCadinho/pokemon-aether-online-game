extends SceneTree

const ErrorRules := preload("res://scripts/services/wild_encounter_error_rules.gd")

var failed := false


func _init() -> void:
	_check_equal(
		ErrorRules.error_code({
			"success": false,
			"errorCode": "no_usable_pokemon",
			"error": "Player 1 has no usable Pokemon",
		}),
		"no_usable_pokemon",
		"structured no-usable-Pokemon error code"
	)
	_check_equal(
		ErrorRules.error_code({
			"success": false,
			"error": "Player 1 has no usable Pokemon",
		}),
		"no_usable_pokemon",
		"legacy no-usable-Pokemon error text"
	)
	_check_equal(
		ErrorRules.error_code({
			"detail": {"code": "fishing_rod_not_owned"},
		}),
		"fishing_rod_not_owned",
		"HTTP detail error code"
	)
	_check_equal(
		ErrorRules.message_lines({"errorCode": "no_usable_pokemon"}),
		[
			"None of your Pokemon are able to battle.",
			"Heal your party at a Pokemon Center before trying again.",
		],
		"no-usable-Pokemon guidance"
	)
	_check_equal(
		ErrorRules.message_lines({"error": "Unexpected backend failure"}),
		[],
		"unknown errors remain eligible for staff reporting"
	)
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
