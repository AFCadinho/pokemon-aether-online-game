extends SceneTree


func _init() -> void:
	var service := PvpBattleRealtimeServiceNode.new()

	service.active_room_code = "ROOM"
	service.active_player_id = "p1"
	service.active_battle_id = "battle-1"
	service.active_match_id = "match-1"
	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"afterBattleEventSeq": 0,
		"battleEventLatestSeq": 3,
		"events": [
			{"battleEventSeq": 1, "type": "battle.created"},
			{"battleEventSeq": 2, "type": "battle.choice_submitted"},
			{"battleEventSeq": 3, "type": "battle.turn_resolved"},
		],
	})
	_check_equal(service.battle_event_latest_seq, 3, "tracks latest stream seq")
	_check_equal(service.last_battle_event_seq, 3, "tracks last local stream seq")
	_check_equal(service.received_battle_event_count, 3, "counts valid received events")

	var payload := service._build_join_payload()
	_check_equal(payload.get("lastBattleEventSeq"), 3, "join payload includes lastBattleEventSeq")
	_check_equal(payload.get("matchId"), "match-1", "join payload still includes matchId")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"afterBattleEventSeq": 3,
		"battleEventLatestSeq": 5,
		"events": [],
	})
	_check_equal(service.battle_event_latest_seq, 5, "empty events still update latest seq")
	_check_equal(service.last_battle_event_seq, 5, "empty events still advance local cursor")
	_check_equal(service.received_battle_event_count, 3, "empty events do not increase received count")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"battleEventLatestSeq": "7",
		"events": [
			{"battleEventSeq": "6", "type": "battle.choice_submitted"},
			{"battleEventSeq": -1, "type": "bad"},
			{"type": "missing-seq"},
			"not-an-event",
		],
	})
	_check_equal(service.battle_event_latest_seq, 7, "string latest seq is accepted")
	_check_equal(service.last_battle_event_seq, 7, "latest seq remains authoritative over event seq")
	_check_equal(service.received_battle_event_count, 4, "malformed events are ignored safely")

	service.connect_room("OTHER", "p2", "battle-2", "match-2")
	_check_equal(service.last_battle_event_seq, 0, "new battle resets local cursor")
	_check_equal(service.battle_event_latest_seq, 0, "new battle resets latest seq")
	_check_equal(service.received_battle_event_count, 0, "new battle resets debug count")

	service.free()
	print("PASS pvp_battle_realtime_stream_check")
	quit(0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
	quit(1)
