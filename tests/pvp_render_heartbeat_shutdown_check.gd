extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var context := {"event_batch_id": "shutdown-fixture:1", "batch_seq": 1}
	battle._begin_pvp_render_progress(context, 2)
	await process_frame
	await process_frame
	var timer: Timer = battle.pvp_render_progress_timer
	var held: WeakRef = weakref(timer)
	_check(timer.get_parent() == battle and not timer.is_stopped(), "Battle owns the active heartbeat timer")
	_check(timer.wait_time == 1.0 and timer.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Heartbeat retains its one-second, process-always timing")
	battle._mark_pvp_render_event_completed(1)
	battle._finish_pvp_render_progress(context, false)
	_check(context.get("rendered_event_count") == 1, "Canceled batch retains its partial progress")
	_check(timer.is_stopped(), "Batch completion immediately stops its heartbeat")
	var next_context := {"event_batch_id": "shutdown-fixture:2", "batch_seq": 2}
	battle._begin_pvp_render_progress(context, 2)
	battle._begin_pvp_render_progress(next_context, 3)
	await process_frame
	await process_frame
	_check(battle.pvp_render_progress_timer == timer and not timer.is_stopped(), "Replacement reuses one owned timer")
	battle._finish_pvp_render_progress(context, true)
	_check(not timer.is_stopped(), "Stale batch completion cannot stop the current heartbeat")
	battle._finish_pvp_render_progress(next_context, true)
	_check(next_context.get("rendered_event_count") == 3 and timer.is_stopped(), "Successful batch reports full progress and stops")
	battle._begin_pvp_render_progress(next_context, 3)
	await process_frame
	await process_frame
	timer = null
	battle.queue_free()
	await process_frame
	await process_frame
	_check(held.get_ref() == null, "Battle teardown destroys its active heartbeat timer")
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
