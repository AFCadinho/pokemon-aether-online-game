extends SceneTree

const BattleEventPresentationScript := preload("res://scripts/battle/battle_event_presentation.gd")
const BattleEventTextFormatterScript := preload("res://scripts/battle/battle_event_text_formatter.gd")
const BattleHpEventHelperScript := preload("res://scripts/battle/battle_hp_event_helper.gd")

var failed := false


func _init() -> void:
	_check_previous_condition_uses_visible_scale()
	_check_full_hp_reveal_damage_has_no_damage_target()
	_check_real_damage_keeps_damage_target()
	quit(1 if failed else 0)


func _make_presentation():
	var presentation = BattleEventPresentationScript.new()
	presentation.setup(
		BattleEventTextFormatterScript.new(),
		BattleHpEventHelperScript.new(),
		Callable(self, "_format_actor"),
		Callable(self, "_get_player_display_name")
	)
	return presentation


func _check_previous_condition_uses_visible_scale() -> void:
	var helper = BattleHpEventHelperScript.new()
	var snapshot: Dictionary = helper.get_event_hp_snapshot({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "100/100",
		"condition": "357/357",
		"previousHp": 100,
		"hp": 357,
		"maxHp": 357,
	}, true)

	_check_equal(snapshot.get("hp", 0), 100, "previous snapshot keeps visible HP")
	_check_equal(snapshot.get("max_hp", 0), 100, "previous snapshot keeps visible max HP")


func _check_full_hp_reveal_damage_has_no_damage_target() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "100/100",
		"condition": "357/357",
		"previousHp": 100,
		"hp": 357,
		"maxHp": 357,
	})

	_check_equal(str(result.get("damage_target_ident", "")), "", "full HP reveal does not animate damage")
	_check_equal(str(result.get("log_message", "")), "", "full HP reveal has no damage log")


func _check_real_damage_keeps_damage_target() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "357/357",
		"condition": "0 fnt",
		"previousHp": 357,
		"hp": 0,
		"maxHp": 357,
	})

	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Garchomp", "real damage still animates")


func _format_actor(ident: String, _prefer_player_name := true) -> String:
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()
	return ident


func _get_player_display_name(player_id: String) -> String:
	return player_id


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
