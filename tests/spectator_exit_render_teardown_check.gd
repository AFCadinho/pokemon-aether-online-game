extends SceneTree

const BATTLE_PATH := "res://scripts/battle/battle.gd"
const QUEUE_SCRIPT := preload("res://scripts/battle/battle_event_queue.gd")
const MINI_FEED_SCRIPT := preload("res://scripts/battle/battle_ui/mini_battle_feed.gd")

var failures := 0


func _init() -> void:
	_check_pending_queue_discard_preserves_active_render_state()
	_check_spectator_exit_waits_for_render_shutdown()
	_check_detached_feed_localization_is_safe()
	print("spectator_exit_render_teardown_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check_pending_queue_discard_preserves_active_render_state() -> void:
	var queue := QUEUE_SCRIPT.new()
	queue.is_rendering = true
	queue.current_event_batch_id = "battle-1:6"
	queue.enqueue_response({"eventBatchId": "battle-1:7", "events": [{"type": "turn"}]}, "test")

	queue.discard_pending()

	_check(not queue.has_pending(), "spectator teardown discards queued render batches")
	_check(queue.is_rendering, "discarding pending batches does not hide the active render coroutine")
	_check(
		queue.current_event_batch_id == "battle-1:6",
		"discarding pending batches preserves the active batch until it unwinds"
	)


func _check_spectator_exit_waits_for_render_shutdown() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_PATH)
	var leave_start := source.find("func _leave_spectator_battle() -> void:")
	var next_function := source.find("\nfunc ", leave_start + 1)
	var leave_block := source.substr(leave_start, next_function - leave_start)
	var render_loop_start := source.find("for event_index: int in range(ordered_events.size()):")
	var render_event_call := source.find("await event_renderer.render_event", render_loop_start)

	_check(leave_start >= 0, "spectator leave handler exists")
	_check(
		leave_block.find("PvpBattleRealtimeService.disconnect_room()")
			< leave_block.find("pvp_event_queue.discard_pending()"),
		"spectator exit disconnects transport before discarding queued events"
	)
	_check(
		leave_block.find("event_renderer.cancel_render()")
			< leave_block.find("await get_tree().process_frame"),
		"spectator exit cancels presentation before waiting for the render loop"
	)
	_check(
		leave_block.find("await get_tree().process_frame") < leave_block.find("_finish_battle({"),
		"spectator exit keeps the battle scene alive until active rendering stops"
	)
	_check(
		source.find("if spectator_exit_in_progress:", render_loop_start) < render_event_call,
		"the render loop refuses to start another event during spectator teardown"
	)
	_check(
		source.contains("func _exit_tree() -> void:")
			and source.contains("# Any non-standard teardown must also invalidate"),
		"unexpected battle teardown also invalidates renderer continuations"
	)


func _check_detached_feed_localization_is_safe() -> void:
	var feed := MINI_FEED_SCRIPT.new()
	var translated: String = str(feed.call("_t", "battle.test.detached", {}))
	_check(translated == "battle.test.detached", "a detached mini feed does not call get_tree")
	feed.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
