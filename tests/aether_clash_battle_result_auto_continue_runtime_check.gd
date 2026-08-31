extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

var failed := false
var emitted_results: Array[Dictionary] = []


func _ready() -> void:
	var clash_battle := BATTLE_SCENE.instantiate()
	add_child(clash_battle)
	await get_tree().process_frame
	clash_battle.battle_ended.connect(_capture_result)
	clash_battle.pvp_room_code = "clash-auto-continue"
	clash_battle.pvp_battle_purpose = "aether_clash"
	clash_battle.pending_battle_end_result = {
		"winner": "p1",
		"reason": "win",
		"localPartyDefeated": false,
	}
	clash_battle.battle_result_overlay.visible = true
	clash_battle._start_battle_result_auto_continue()

	_check(
		clash_battle.battle_result_auto_continue_seconds_remaining == 5,
		"Aether Clash result starts at five seconds"
	)
	_check(
		clash_battle.battle_result_continue_button.text.ends_with("(5)"),
		"Continue button shows the initial countdown"
	)
	_check(
		not clash_battle.battle_result_auto_continue_timer.is_stopped(),
		"Aether Clash result countdown timer is running"
	)

	for _tick in range(4):
		clash_battle._on_battle_result_auto_continue_tick()
	_check(
		clash_battle.battle_result_continue_button.text.ends_with("(1)"),
		"Continue button counts down to one"
	)
	_check(emitted_results.is_empty(), "battle remains open before countdown reaches zero")

	clash_battle._on_battle_result_auto_continue_tick()
	_check(emitted_results.size() == 1, "countdown automatically completes the battle result")
	_check(
		not clash_battle.battle_result_overlay.visible,
		"automatic Continue closes the result overlay"
	)
	_check(
		clash_battle.battle_result_auto_continue_timer.is_stopped(),
		"automatic Continue stops the countdown timer"
	)
	_check(
		str(emitted_results[0].get("winner", "")) == "p1",
		"automatic Continue preserves the terminal battle result"
	)

	remove_child(clash_battle)
	clash_battle.free()
	emitted_results.clear()

	var casual_battle := BATTLE_SCENE.instantiate()
	add_child(casual_battle)
	await get_tree().process_frame
	casual_battle.battle_ended.connect(_capture_result)
	casual_battle.pvp_room_code = "casual-result"
	casual_battle.pvp_battle_purpose = "casual"
	casual_battle.pending_battle_end_result = {
		"winner": "p2",
		"reason": "win",
	}
	casual_battle.battle_result_overlay.visible = true
	casual_battle._start_battle_result_auto_continue()
	_check(
		casual_battle.battle_result_auto_continue_timer.is_stopped(),
		"ordinary PvP result does not auto-continue"
	)
	_check(
		not casual_battle.battle_result_continue_button.text.contains("("),
		"ordinary PvP keeps the normal Continue label"
	)
	casual_battle._on_battle_result_continue_pressed()
	_check(emitted_results.size() == 1, "ordinary PvP still completes when Continue is pressed")

	remove_child(casual_battle)
	casual_battle.free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)


func _capture_result(result: Dictionary) -> void:
	emitted_results.append(result.duplicate(true))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
