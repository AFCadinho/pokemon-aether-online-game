extends SceneTree

const BattleMessageTimingScript := preload("res://scripts/battle/battle_message_timing.gd")

var timing := BattleMessageTimingScript.new()
var failed := false


func _init() -> void:
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "move"}, "Pikachu used Thunderbolt!"),
		0.20,
		"move message keeps normal hold"
	)
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "switch"}, "Go! Charizard!"),
		0.32,
		"switch message keeps normal hold"
	)
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "heal", "source": "Leftovers"}, "Pikachu restored HP using its Leftovers!"),
		0.18,
		"leftovers heal uses residual hold"
	)
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "damage", "source": "brn"}, "Pikachu was hurt by its burn!"),
		0.18,
		"burn damage uses residual hold"
	)
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "fieldEffect", "effect": "Sandstorm", "state": "upkeep"}, "Sandstorm continues."),
		0.18,
		"weather upkeep uses residual hold"
	)
	_check_equal(
		timing.get_battle_message_hold_seconds({"type": "status", "status": "brn"}, "Pikachu was burned!"),
		0.32,
		"major status message keeps normal hold"
	)

	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
