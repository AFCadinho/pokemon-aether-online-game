extends SceneTree

const BattleBanterPresenterScript := preload("res://scripts/battle/battle_banter_presenter.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_data_driven_triggers_are_one_shot()
	_check_unconfigured_trainers_stay_silent()
	_check_battle_integration_contract()
	quit(1 if failed else 0)


func _check_data_driven_triggers_are_one_shot() -> void:
	var presenter = BattleBanterPresenterScript.new()
	presenter.configure({
		"battle_banter": {
			"version": 1,
			"cues": [
				{
					"id": "opening",
					"trigger": {"type": "battle_start"},
					"speaker": "opponent",
					"text_key": "battle.banter.test.opening",
				},
				{
					"id": "onix_sent_out",
					"trigger": {"type": "pokemon_sent_out", "side": "opponent", "species": "Onix"},
					"speaker": "opponent",
					"text_key": "battle.banter.test.onix",
				},
				{
					"id": "onix_low_hp",
					"trigger": {"type": "hp_below", "side": "opponent", "species": "Onix", "at_or_below_percent": 50},
					"speaker": "opponent",
					"text_key": "battle.banter.test.low_hp",
				},
				{
					"id": "turn_three",
					"trigger": {"type": "turn_start", "turn": 3},
					"speaker": "opponent",
					"text_key": "battle.banter.test.turn",
				},
			],
		},
	})

	_check_equal(presenter.take_battle_start_cues().size(), 1, "battle-start cue is selected")
	_check_equal(presenter.take_battle_start_cues().size(), 0, "battle-start cue is consumed once")
	_check_equal(presenter.take_cues_for_event({
		"type": "switch",
		"playerId": "p1",
		"to": "Onix",
		"toIdent": "p1a: Onix",
	}).size(), 0, "side filters keep opponent banter off the player side")
	_check_equal(presenter.take_cues_for_event({
		"type": "switch",
		"playerId": "p2",
		"to": "Onix",
		"toIdent": "p2a: Onix",
	}).size(), 1, "opponent Onix send-out selects its cue")
	_check_equal(presenter.take_cues_for_event({
		"type": "damage",
		"target": "p2a: Rocky",
		"targetRef": {"species": "Onix"},
		"hp": 51,
		"maxHp": 100,
	}).size(), 0, "HP cue waits above its configured threshold")
	_check_equal(presenter.take_cues_for_event({
		"type": "damage",
		"target": "p2a: Rocky",
		"targetRef": {"species": "Onix"},
		"hp": 50,
		"maxHp": 100,
	}).size(), 1, "HP cue resolves at its configured threshold")
	_check_equal(presenter.take_cues_for_event({"type": "turn", "turn": 2}).size(), 0, "turn cue ignores other turns")
	_check_equal(presenter.take_cues_for_event({"type": "turn", "turn": 3}).size(), 1, "turn cue resolves on its exact turn")


func _check_unconfigured_trainers_stay_silent() -> void:
	var presenter = BattleBanterPresenterScript.new()
	presenter.configure({"id": "ordinary_trainer"})
	_check_equal(presenter.take_battle_start_cues().size(), 0, "ordinary trainers have no battle banter")
	_check_equal(presenter.take_cues_for_event({"type": "turn", "turn": 1}).size(), 0, "ordinary trainer events stay silent")


func _check_battle_integration_contract() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(source.contains("battle_banter_presenter.configure(trainer_data)"), "trainer metadata configures battle banter")
	_check(source.contains("battle_banter_presenter.take_battle_start_cues()"), "trainer intro renders battle-start banter")
	_check(source.contains("battle_banter_presenter.take_cues_for_event(event_data)"), "ordered battle events drive banter")
	_check(source.contains('source != "initial_battle_events" and not _is_pvp_battle()'), "initial lead history and PvP cannot trigger NPC banter")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
