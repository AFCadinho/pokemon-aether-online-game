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
	clash_battle.action_flow.set_local_player_id("p1")
	# A battle-limit decision can overtake the already-submitted final-turn
	# acknowledgement. That transport update can never complete the turn after
	# the server has ended the battle and must not strand the terminal result.
	clash_battle.pvp_realtime_updates.append({
		"type": "pvp.battle_update",
		"action": "choose_move",
		"playerId": "p1",
		"response": {"success": true},
	})
	clash_battle._finish_pvp_authoritative_terminal({
		"type": "pvp.authoritative_terminal",
		"battleId": "clash-auto-continue",
		"winnerSide": "p1",
		"loserSide": "p2",
		"endReason": "battle_time_limit",
		"source": "BATTLE_LIMIT",
	})

	_check(clash_battle.battle_finished, "battle-limit terminal finishes an active client battle")
	_check(
		clash_battle.pvp_realtime_updates.is_empty(),
		"battle-limit terminal retires the superseded submitted-choice update"
	)
	_check(clash_battle.battle_result_overlay.visible, "battle-limit terminal opens the result overlay")
	_check(
		str(clash_battle.pending_battle_end_result.get("reason", "")) == "battle_time_limit",
		"battle-limit terminal preserves its canonical end reason"
	)
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
	_check(
		clash_battle._should_present_pvp_battle_result({"reason": "battle_time_limit_draw"}),
		"an exactly tied battle-limit result still receives a result screen"
	)
	_check(
		clash_battle._format_battle_result_reason("battle_time_limit") != "",
		"battle-limit result explains that the battle ended on time"
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
