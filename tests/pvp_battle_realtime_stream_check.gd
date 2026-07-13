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
	_check_equal(payload.get("timerContractVersions"), [1], "join advertises timer contract v1")
	_check_equal(payload.get("decisionContractVersions"), [1], "join advertises decision contract v1")
	_check_equal(payload.get("battleCommandContractVersions"), [1], "join advertises command contract v1")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"afterBattleEventSeq": 3,
		"battleEventLatestSeq": 5,
		"events": [],
	})
	_check_equal(service.battle_event_latest_seq, 5, "empty events still update latest seq")
	_check_equal(service.last_battle_event_seq, 3, "remote latest does not skip unapplied pages")
	_check_equal(service.received_battle_event_count, 3, "empty events do not increase received count")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"battleEventLatestSeq": "7",
		"events": [
			{"battleEventSeq": "6", "type": "battle.choice_submitted"},
			{"battleEventSeq": "4", "type": "battle.timer_sync", "payload": {"timerRevision": 1}},
			{"battleEventSeq": "5", "type": "battle.turn_resolved"},
			{"battleEventSeq": "4", "type": "duplicate"},
			{"battleEventSeq": -1, "type": "bad"},
			{"type": "missing-seq"},
			"not-an-event",
		],
	})
	_check_equal(service.battle_event_latest_seq, 7, "string latest seq is accepted")
	_check_equal(service.last_battle_event_seq, 6, "out-of-order page is applied in canonical sequence")
	_check_equal(service.received_battle_event_count, 6, "duplicates and malformed events are ignored safely")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"battleEventLatestSeq": 9,
		"events": [{"battleEventSeq": 8, "type": "battle.turn_resolved"}],
	})
	_check_equal(service.last_battle_event_seq, 6, "gap never advances the local canonical cursor")

	service.timer_projection.apply_snapshot({"timerContractVersion": 1, "authority": "BATTLE_BANK_V1_SHADOW"})
	service.connect_room("OTHER", "p2", "battle-2", "match-2")
	_check_equal(service.last_battle_event_seq, 0, "new battle resets local cursor")
	_check_equal(service.battle_event_latest_seq, 0, "new battle resets latest seq")
	_check_equal(service.received_battle_event_count, 0, "new battle resets debug count")
	_check_equal(service.timer_projection.contract_enabled, false, "new battle clears stale timer projection")

	service.free()
	print("PASS pvp_battle_realtime_stream_check")
	quit(0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
	quit(1)
