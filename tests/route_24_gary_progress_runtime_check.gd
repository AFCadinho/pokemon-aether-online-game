extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _new_gary() -> Node:
	var npc := (load("res://scenes/npcs/trainer_npc.tscn") as PackedScene).instantiate()
	npc.set_script(load("res://tests/support/route_24_gary_progress_probe.gd"))
	return npc


func _settle_requests() -> void:
	for frame in range(6):
		await process_frame


func _run() -> void:
	var completed := _new_gary()
	completed.progress_response = {"success": true, "progress": {"state": "completed"}}
	completed.starter_response = {"success": false}
	root.add_child(completed)
	await _settle_requests()
	_check(not is_instance_valid(completed), "Existing victory removes Gary even when starter lookup would fail")

	for failed_projection in [{"success": false}, {"success": true, "progress": {}}]:
		var npc := _new_gary()
		npc.progress_response = failed_projection
		root.add_child(npc)
		await _settle_requests()
		_check(not npc.visible and not npc.trainer_progress_loaded, "Unknown progress never exposes a first encounter")
		_check(not npc._can_auto_challenge() and not npc._can_start_manual_interaction(), "Unknown progress blocks both battle triggers")
		_check(npc.starter_requests == 0, "Progress is checked before selecting Gary's team")
		npc.progress_response = {"success": true, "progress": {"state": "completed"}}
		npc._progress_retry.start(0.02)
		await create_timer(0.08).timeout
		await _settle_requests()
		_check(not is_instance_valid(npc), "Automatic retry removes an already defeated Gary")

	var first := _new_gary()
	first.starter_response = {"success": false}
	root.add_child(first)
	await _settle_requests()
	_check(first.trainer_id.is_empty(), "Failed starter lookup never selects Bulbasaur")
	_check(not first.visible and not first._can_auto_challenge() and not first._can_start_manual_interaction(), "Failed starter lookup keeps Gary inactive")
	first.starter_response = {"success": true, "rivalStarterSpeciesId": "", "rivalTrainerId": "invalid"}
	await first._load_trainer_progress()
	_check(first.trainer_id.is_empty() and not first.trainer_progress_loaded, "Malformed starter data also stays inactive")
	first.starter_response = {"success": true, "rivalStarterSpeciesId": "squirtle"}
	first._progress_retry.start(0.02)
	await create_timer(0.08).timeout
	await _settle_requests()
	_check(first.trainer_id == "kanto_route_24_gary_squirtle", "Retry recovers the correct starter variant")
	_check(first.visible and first.trainer_progress_loaded and first._can_auto_challenge(), "First encounter becomes playable after recovery")
	_check(not first.vision_collision_shape.disabled and first.vision_collision_shape.shape.size.x == first.challenge_width_tiles * first.TILE_SIZE, "Recovered encounter guards the full bridge after deferred sensor updates")
	first.finish_trainer_battle(first.trainer_id, true)
	first.progress_response = {"success": true, "progress": {"state": "completed"}}
	await first._load_trainer_progress()
	_check(not first.is_queued_for_deletion() and first.visible, "Victory keeps Gary's outro available during this map visit")
	_check(not first._can_auto_challenge(), "Won encounter cannot automatically restart")
	first.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
