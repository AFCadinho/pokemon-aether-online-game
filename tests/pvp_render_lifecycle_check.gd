extends SceneTree

func _init() -> void:
	var service := PvpBattleRealtimeServiceNode.new()
	service.active_room_code = "ROOM"
	service.active_battle_id = "battle-1"
	service.active_player_id = "p1"
	service.connecting = true

	var progress_sent := service.send_render_status(
		"battle-1", "p1", "battle-1:23", 23, 108,
		"PROGRESS", 12, "rendering_events", 2, 3, 750
	)
	_check(not progress_sent, "an offline progress heartbeat is not reported as sent")
	_check(
		service.pending_render_ack_payload.is_empty(),
		"intermediate progress never replaces durable completion proof"
	)

	var completion_sent := service.send_render_ack(
		"battle-1", "p1", "battle-1:23", 23, 111,
		12, "rendering_events", 3, 3, 1000
	)
	_check(not completion_sent, "an offline completion is retained rather than reported as sent")
	var completion := service.pending_render_ack_payload
	_check(completion.get("renderProtocolVersion") == 2, "completion uses render protocol v2")
	_check(completion.get("renderState") == "COMPLETED", "completion is explicit")
	_check(completion.get("renderedEventCount") == 3, "completion carries rendered event count")
	_check(completion.get("totalEventCount") == 3, "completion carries total event count")
	_check(completion.get("observedDurationMs") == 1000, "completion carries observed duration")

	service.free()
	print("PASS pvp_render_lifecycle_check")
	quit(0)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	push_error(label)
	quit(1)
