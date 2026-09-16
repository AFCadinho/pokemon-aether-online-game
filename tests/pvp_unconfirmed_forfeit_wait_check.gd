extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for force_switch: bool in [false, true]:
		var battle = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(battle)
		await process_frame
		battle.pvp_room_code = "LOCAL-FORFEIT-CHECK"
		battle.action_flow.set_local_player_id("p1")
		battle.pvp_last_phase = "rendering_events"
		battle.pvp_event_queue.is_rendering = true
		battle.pvp_realtime_updates.append({
			"type": "pvp.battle_update",
			"action": "forfeit",
			"playerId": "p2",
			"response": {"success": false, "state": {"ended": true}} if force_switch else {"success": true, "state": {"ended": false}},
		})
		var finished := {"value": false}
		_wait_for_opponent(battle, force_switch, finished)
		var deadline := Time.get_ticks_msec() + 1000
		while not battle.pvp_realtime_updates.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(battle.pvp_realtime_updates.is_empty(), "The %s waiter consumed the unconfirmed update" % ("switch" if force_switch else "choice"))
		_check(not battle.battle_finished, "An unconfirmed %s forfeit cannot finish the battle" % ("switch" if force_switch else "choice"))
		_check(battle.pvp_room_code == "LOCAL-FORFEIT-CHECK", "An unconfirmed %s forfeit keeps the room attached" % ("switch" if force_switch else "choice"))
		battle.battle_finished = true
		deadline = Time.get_ticks_msec() + 1000
		while not bool(finished.value) and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(bool(finished.value), "The %s waiter exits before Battle teardown" % ("switch" if force_switch else "choice"))
		battle.pvp_event_queue.is_rendering = false
		battle.queue_free()
		await process_frame
		await process_frame
	quit(1 if failures else 0)

func _wait_for_opponent(battle: Node, force_switch: bool, finished: Dictionary) -> void:
	if force_switch:
		await battle._wait_for_pvp_opponent_force_switch_and_render()
	else:
		await battle._wait_for_pvp_opponent_choice_and_render()
	finished.value = true

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
