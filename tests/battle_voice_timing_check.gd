extends SceneTree

const BattleVoiceTimingScript := preload("res://scripts/battle/battle_voice_timing.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_bounded_read_times()
	_check_renderer_waits_at_presentation_boundary()
	_check_switch_waits_before_recall()
	quit(1 if failed else 0)


func _check_bounded_read_times() -> void:
	_check_close(
		BattleVoiceTimingScript.get_minimum_read_seconds("move", "Pikachu, use Tackle!"),
		0.40,
		"short move command receives its base lead"
	)
	_check_close(
		BattleVoiceTimingScript.get_minimum_read_seconds("dodge", "Garchomp, dodge!"),
		0.70,
		"true-miss dodge receives an exclusive readable lead"
	)
	var long_switch := BattleVoiceTimingScript.get_minimum_read_seconds(
		"switch",
		"Not bad! Let's see how you handle this. Go, Rhyhorn!"
	)
	_check(long_switch > 0.45, "long contextual switch receives extra read time")
	_check(long_switch <= 0.80, "long contextual switch read time stays bounded")


func _check_renderer_waits_at_presentation_boundary() -> void:
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	var function_start := source.find("func _show_trainer_move_commands(")
	var function_end := source.find("\nfunc ", function_start + 1)
	var function_source := source.substr(function_start, function_end - function_start)
	var move_call_index := function_source.find('"kind": "move"')
	var move_wait_index := function_source.find("await _wait(_get_command_minimum_read_seconds", move_call_index)
	var dodge_call_index := function_source.find('"kind": "dodge"', move_wait_index)
	var dodge_wait_index := function_source.find("await _wait(_get_command_minimum_read_seconds", dodge_call_index)
	_check(move_wait_index > move_call_index, "move callout lead is awaited before attack presentation")
	_check(dodge_wait_index > dodge_call_index, "dodge callout lead is awaited before miss presentation")
	_check(source.contains("func _command_was_shown(result: Variant) -> bool:"), "renderer accepts legacy boolean and timed command callbacks")


func _check_switch_waits_before_recall() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var command_index := source.find("await _show_switch_trainer_command(event_data, switch_player_id)")
	var recall_index := source.find("await _play_switch_recall_for_event(event_data, switch_player_id)", command_index)
	_check(command_index >= 0, "switch callout presentation is awaited")
	_check(recall_index > command_index, "switch minimum read time completes before recall")
	_check(source.contains("BATTLE_VOICE_TIMING.get_minimum_read_seconds"), "localized command length determines bounded read time")


func _check_close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.001, "%s expected=%s actual=%s" % [label, expected, actual])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
