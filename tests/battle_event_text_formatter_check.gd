extends SceneTree

const BattleEventTextFormatterScript := preload("res://scripts/battle/battle_event_text_formatter.gd")

var formatter := BattleEventTextFormatterScript.new()
var failed := false


func _init() -> void:
	_check_equal(
		formatter.format_wild_battle_start_messages("Pikachu", "Pidgey"),
		["A wild Pidgey has appeared!", "Go! Pikachu!"],
		"wild battle start messages"
	)
	_check_equal(
		formatter.format_trainer_battle_start_messages("Pikachu", "Eevee", "Gary Oak"),
		["Gary Oak wants to battle!", "Gary Oak sent out Eevee!", "Go! Pikachu!"],
		"trainer battle start messages"
	)
	_check_equal(
		formatter.format_player_switch_log_message("Pikachu", "Charizard"),
		"Pikachu, come back!\nGo! Charizard!",
		"player switch log message"
	)
	_check_equal(
		formatter.format_player_switch_battle_message("Pikachu", "Charizard"),
		"Go! Charizard!",
		"player switch battle message"
	)
	_check_equal(
		formatter.format_action_prompt("Pikachu"),
		"What will Pikachu do?",
		"action prompt"
	)
	_check_equal(
		formatter.format_effectiveness_event({"effectiveness": "super"}),
		"It's super effective!",
		"super effective message"
	)
	_check_equal(
		formatter.format_effectiveness_event({"effectiveness": "resisted"}),
		"It's not very effective...",
		"resisted message"
	)
	_check_equal(
		formatter.format_direct_damage_message("Pikachu", 12, true, false),
		"(Pikachu lost 12% of its health!)",
		"direct damage message"
	)
	_check_equal(
		formatter.format_direct_damage_message("Pikachu", 0, false, true),
		"(Pikachu lost less than 1% of its health!)",
		"sub-percent damage message"
	)
	_check_equal(
		formatter.format_heal_event({"source": "Leftovers"}, "Pikachu", 50, 56, 6),
		"Pikachu restored HP using its Leftovers!",
		"leftovers heal message"
	)

	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
