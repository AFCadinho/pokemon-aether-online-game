extends SceneTree

func _init() -> void:
	var service := PvpBattleRealtimeServiceNode.new()
	var invalid := {"count": 0}
	service.session_invalid.connect(func(_reason): invalid["count"] += 1)
	service.should_reconnect = true
	service.last_battle_event_seq = 42
	for status_code in [408, 425, 429, 500, 502, 503, 504]:
		service._handle_join_error({"code": "pvp_identity_resolution_failed", "status": status_code})
		assert(service.should_reconnect)
		assert(invalid["count"] == 0)
		assert(service.last_battle_event_seq == 42)
	service._handle_join_error({"code": "pvp_identity_resolution_failed", "status": 403})
	assert(not service.should_reconnect and not service.joined and not service.room_is_ready)
	assert(invalid["count"] == 1)
	service._invalidate_session("duplicate close")
	assert(invalid["count"] == 1)
	service.free()
	print("PASS pvp_identity_recovery_check")
	quit(0)
