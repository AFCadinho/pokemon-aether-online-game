extends Node

var failed := false

func check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)

func _ready() -> void:
	var path := OS.get_environment("POKEAETHER_LIVE_FIXTURE_PATH")
	if path.is_empty():
		push_error("POKEAETHER_LIVE_FIXTURE_PATH is required")
		get_tree().quit(1)
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".gateway.json"))
	var frames: Array = fixture.frames
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	var initial: Dictionary = frames[1]
	battle.battle_type = 1
	battle.pvp_room_code = "AI-" + str(initial.battleId).to_upper()
	battle.pvp_match_id = "ai:" + str(initial.battleId)
	battle.pvp_viewer_role = "spectator"
	battle.pvp_battle_purpose = "training"
	battle.action_flow.set_local_player_id("p1")
	battle._prepare_battle_setup(1, battle._build_spectator_active_pokemon(initial, "p1"), null)
	battle.battle_state.load_from_api_response(initial, false)
	battle._show_pvp_trainers(initial)
	battle._restore_battle_log_from_history_response(initial)
	check(battle._apply_spectator_late_join_snapshot(initial), "Late join snapshot accepted")
	battle.pvp_response_order.reset(initial)
	check(battle._is_spectator_battle(), "AI live viewer is read-only")
	for index in range(2, frames.size()):
		var response: Dictionary = frames[index].duplicate(true)
		response.pvpServerSeq = index
		battle._on_pvp_realtime_battle_update({"type": "pvp.render_batch", "viewerRole": "spectator", "roomCode": battle.pvp_room_code,
			"battleId": initial.battleId, "serverSeq": index, "response": response})
		for tick in range(1500):
			await get_tree().create_timer(0.01).timeout
			if battle.battle_finished or (not battle.pvp_event_queue.is_rendering and battle.pvp_event_queue.last_rendered_seq >= int(response.eventSeq)):
				break
		check(battle.pvp_event_queue.last_rendered_seq >= int(response.eventSeq) or battle.battle_finished, "Live events rendered through cursor %s" % response.eventSeq)
	battle._on_pvp_realtime_battle_update({"type": "pvp.match_ended", "roomCode": battle.pvp_room_code, "reason": "ended", "winnerSide": ""})
	for tick in range(300):
		await get_tree().create_timer(0.01).timeout
		if battle.battle_finished:
			break
	check(battle.battle_finished, "Final live frame finishes spectator battle")
	remove_child(battle)
	battle.free()
	await get_tree().process_frame
	print("AI Sparring live renderer: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
