extends SceneTree

func _init() -> void:
	var service := PvpBattleRealtimeServiceNode.new()
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	var realtime_source := FileAccess.get_file_as_string("res://scripts/services/pvp_battle_realtime_service.gd")
	var action_wait_start := battle_source.find("func _send_pvp_realtime_action_and_wait")
	var show_moves_start := battle_source.find("func _show_moves() -> void:")
	var show_moves_decision_guard := battle_source.find("not _pvp_local_decision_allows_choice()", show_moves_start)
	var timer_control_start := battle_source.find("func _pvp_timer_allows_control() -> bool:")
	var timer_decision_guard := battle_source.find("not _pvp_local_decision_allows_choice()", timer_control_start)
	var request_control_start := battle_source.find("func _pvp_local_request_allows_choice")
	var request_decision_guard := battle_source.find("not _pvp_local_decision_allows_choice(local_state_player_id)", request_control_start)
	var queue_cursor_position := battle_source.find("var queue_start := pvp_realtime_updates.size()", action_wait_start)
	var local_decision_position := battle_source.find("battle_state.get_active_decision(_get_local_state_player_id())", action_wait_start)
	var decision_kind_position := battle_source.find('str(decision.get("decisionKind", ""))', action_wait_start)
	var send_position := battle_source.find("var request_id := PvpBattleRealtimeService.send_action", action_wait_start)
	var update_handler_start := battle_source.find("func _on_pvp_realtime_battle_update(message: Dictionary) -> void:")
	var immediate_terminal_position := battle_source.find("if _should_apply_pvp_realtime_end_immediately(message):", update_handler_start)
	var normal_queue_position := battle_source.find("pvp_realtime_updates.append(message.duplicate(true))", update_handler_start)
	var opponent_force_wait_start := battle_source.find("func _wait_for_pvp_opponent_force_switch_and_render() -> bool:")
	var opponent_force_wait_lock_position := battle_source.find("_show_pvp_opponent_force_switch_wait()", opponent_force_wait_start)
	var opponent_force_wait_loop_position := battle_source.find("while true:", opponent_force_wait_start)
	var preview_drain_position := battle_source.find("await _drain_pvp_team_preview_completion_updates()")
	var initial_render_position := battle_source.rfind("await _render_initial_battle_events(lead_response)", preview_drain_position)
	var initial_controls_position := battle_source.find("_show_battle_controls_after_initial_events()", preview_drain_position)
	_check_equal(action_wait_start >= 0, true, "realtime action wait implementation exists")
	_check_equal(
		show_moves_decision_guard >= show_moves_start and show_moves_decision_guard < timer_control_start,
		true,
		"move controls stay closed while the local decision is locked"
	)
	_check_equal(
		timer_decision_guard >= timer_control_start and timer_decision_guard < request_control_start,
		true,
		"PvP submissions reject locked decisions"
	)
	_check_equal(
		request_decision_guard >= request_control_start,
		true,
		"stale request data cannot make a locked decision actionable"
	)
	_check_equal(queue_cursor_position >= 0 and queue_cursor_position < send_position, true, "realtime response queue cursor is captured before sending")
	_check_equal(
		local_decision_position >= action_wait_start and local_decision_position < send_position,
		true,
		"realtime actions use the normalized local decision identity"
	)
	_check_equal(
		decision_kind_position >= local_decision_position and decision_kind_position > send_position,
		true,
		"realtime actions include the authoritative decision kind"
	)
	_check_equal(
		immediate_terminal_position >= update_handler_start and immediate_terminal_position < normal_queue_position,
		true,
		"confirmed terminal actions finish before they can fall into the ordinary realtime queue"
	)
	_check_equal(
		opponent_force_wait_lock_position >= opponent_force_wait_start \
			and opponent_force_wait_lock_position < opponent_force_wait_loop_position,
		true,
		"opponent force-switch waiting locks and hides battle controls before polling"
	)
	_check_equal(
		preview_drain_position > initial_render_position \
			and preview_drain_position < initial_controls_position \
			and battle_source.contains("PvpBattleRealtimeService.is_team_preview_completion_update(") \
			and battle_source.contains('"post_team_preview_unapplied_lead"'),
		true,
		"late privacy-projected Team Preview batches render before participant controls open"
	)
	_check_equal(
		battle_source.contains("func _capture_pvp_team_preview_completion_while_picker_open(message: Dictionary) -> bool:") \
			and battle_source.contains('if str(message.get("requestId", "")).strip_edges() != "":') \
			and battle_source.contains("pvp_pending_team_preview_completion = response.duplicate(true)") \
			and battle_source.contains("player_party_grid.party_selected.emit(0)"),
		true,
		"an actionless final Team Preview batch wakes a timer-blocked party selector"
	)
	_check_equal(
		battle_source.contains('bool(response.get("requiresBattleResync", false)) or str(response.get("code", "")) == "BATTLE_COMMAND_STALE"'),
		true,
		"stale durable choices trigger canonical room reconciliation"
	)
	_check_equal(
		battle_source.contains('"Opponent choice phase advanced; waiting for its render batch"'),
		true,
		"a newer phase cannot release the local choice wait before its render batch"
	)
	_check_equal(
		battle_source.contains('"Opponent force-switch phase advanced; waiting for its render batch"'),
		true,
		"a newer phase cannot release forced-switch wait before canonical presentation converges"
	)
	_check_equal(
		battle_source.contains('await _reconcile_pvp_battle_from_room("pvp_phase_release_recovery")'),
		true,
		"missing render batches recover from the canonical room snapshot"
	)
	_check_equal(
		battle_source.contains('if phase == "waiting_for_opponent":') \
			and battle_source.contains("if _pvp_local_request_allows_choice(local_state_player_id):"),
		true,
		"a room-wide waiting phase keeps an unsubmitted local decision actionable"
	)

	_check_equal(
		realtime_source.contains("if not joined:") \
			and realtime_source.contains("if not join_sent:") \
			and realtime_source.contains("_send_join()") \
			and not realtime_source.contains("func _send_join_when_open()"),
		true,
		"an open realtime socket always drives its join state machine without a three-second polling race"
	)
	_check_equal(
		realtime_source.contains("func report_diagnostic(event_type: String, context: Dictionary = {}) -> bool:") \
			and realtime_source.contains('"type": "diagnostic"') \
			and battle_source.contains('"pvp.client_waiting_state"') \
			and battle_source.contains('"pvp.invalid_realtime_response"') \
			and battle_source.contains('"pvp.realtime_response_timeout"') \
			and battle_source.contains('"pvp.event_sequence_gap"') \
			and battle_source.contains('"pvp.resync_required_received"'),
		true,
		"PvP clients report bounded realtime anomalies without changing the battle stream contract"
	)
	_check_equal(
		realtime_source.contains('websocket.send_text(JSON.stringify({"type":"ping"}))') \
			and realtime_source.contains("CONNECTION_PONG_TIMEOUT_MSEC") \
			and realtime_source.contains('if message_type == "pong":') \
			and realtime_source.contains('_restart_stalled_connection("PvP heartbeat timed out.")'),
		true,
		"connection heartbeat requires a pong and restarts half-open sockets"
	)
	_check_equal(
		realtime_source.contains("JOIN_ACK_TIMEOUT_MSEC") \
			and realtime_source.contains("func _handle_join_error(message: Dictionary) -> void:") \
			and realtime_source.contains("elif not joined:") \
			and realtime_source.contains("_handle_join_error(message)"),
		true,
		"uncorrelated join failures cannot leave an open but unjoined socket"
	)
	var restart_start := realtime_source.find("func _restart_stalled_connection(reason: String) -> void:")
	var restart_end := realtime_source.find("\nfunc ", restart_start + 1)
	var restart_source := realtime_source.substr(restart_start, restart_end - restart_start)
	_check_equal(
		restart_source.contains("connection_attempt_generation += 1") \
			and restart_source.contains("websocket = WebSocketPeer.new()"),
		true,
		"a render-barrier resync invalidates the old connection and deterministically reaches the reconnect loop"
	)
	var stalled_socket := service.websocket
	var stalled_generation := service.connection_attempt_generation
	service.should_reconnect = true
	service.active_room_code = "ROOM"
	service.request_resync("test render barrier")
	_check_equal(service.websocket != stalled_socket, true, "resync replaces a stalled WebSocket peer")
	_check_equal(
		service.connection_attempt_generation,
		stalled_generation + 1,
		"resync invalidates an in-flight connection generation"
	)
	_check_equal(
		realtime_source.contains("connection_attempt_generation += 1") \
			and realtime_source.contains("attempt_generation != connection_attempt_generation"),
		true,
		"stale asynchronous connection attempts cannot replace the active socket"
	)
	_check_equal(
		realtime_source.contains("pending_render_ack_payload = payload.duplicate(true)") \
			and realtime_source.contains("_send_pending_render_ack_after_join()") \
			and realtime_source.contains('_retire_pending_render_ack(str(message.get("eventBatchId", "")))'),
		true,
		"a completed render acknowledgement survives a transient socket reconnect until its phase release arrives"
	)
	_check_equal(
		battle_source.contains("func _observe_pvp_gateway_epoch(message: Dictionary) -> void:") \
			and battle_source.contains("pvp_response_order.reset_transport_cursor()") \
			and battle_source.contains("pvp_last_applied_server_seq = 0"),
		true,
		"a new gateway epoch resets transport-only cursors after a gateway restart"
	)
	_check_equal(
		battle_source.contains("pvp_last_connection_server_seq") \
			and battle_source.contains('"connection_event.skip_stale"'),
		true,
		"late disconnect events cannot roll back a newer reconnect state"
	)
	_check_equal(
		battle_source.contains("func _has_pvp_battle_update_event_gap(response: Dictionary) -> bool:") \
			and battle_source.contains('PvpBattleRealtimeService.request_resync("A PvP render event gap was detected.")') \
			and battle_source.contains('"pvp_snapshot_event_catchup"'),
		true,
		"mechanical event gaps fail closed and reconnect snapshots render the missing tail"
	)
	_check_equal(
		realtime_source.contains('if message_type == "pvp.resync_required":') \
			and realtime_source.contains('request_resync(reason: String = "PvP state resynchronization required.")'),
		true,
		"gateway render-boundary failures explicitly restart both clients"
	)
	_check_equal(
		battle_source.contains("func _fetch_pvp_room_serialized(player_id: String) -> Dictionary:") \
			and battle_source.contains("while pvp_room_recovery_request_active:") \
			and battle_source.count("BattleApiClient.get_pvp_room(") == 1,
		true,
		"all canonical HTTP recovery shares one serialized request lane"
	)
	_check_equal(
		not battle_source.contains("Fallback for rare request-id drift") \
			and not battle_source.contains("Match by fallback action+player"),
		true,
		"non-empty action responses require their exact requestId"
	)
	_check_equal(
		realtime_source.contains("websocket.inbound_buffer_size = WEBSOCKET_BUFFER_BYTES"),
		true,
		"realtime sockets increase their receive buffer before connecting"
	)
	_check_equal(
		realtime_source.contains("websocket.max_queued_packets = WEBSOCKET_MAX_QUEUED_PACKETS"),
		true,
		"realtime sockets increase their queued packet capacity before connecting"
	)
	_check_equal(
		realtime_source.contains('"viewerRole": active_viewer_role') \
			and realtime_source.contains('"spectatorCursorValid": spectator_cursor_valid'),
		true,
		"spectator joins carry a separate role and reconnect cursor contract"
	)
	_check_equal(
		realtime_source.contains('if active_viewer_role == "spectator":\n\t\tpush_warning("PvpBattleRealtimeService: spectator action was blocked locally.")') \
			and realtime_source.contains('if active_viewer_role == "spectator":\n\t\treturn false'),
		true,
		"spectator actions and render acknowledgements are blocked locally"
	)
	_check_equal(
		battle_source.contains("func _is_spectator_battle() -> bool:") \
			and battle_source.contains('return "Waiting for both players..."') \
			and battle_source.contains('return "Waiting for players..."') \
			and battle_source.contains("action_buttons.visible = false") \
			and battle_source.contains('action_buttons.set_action_visible("run", false)') \
			and battle_source.contains("spectator_action_panel.visible = true") \
			and battle_source.contains("func _leave_spectator_battle() -> void:") \
			and battle_source.contains('"reason": "spectator_left"') \
			and battle_source.contains('"skipPartyBattleSync": true') \
			and not battle_source.contains('action_buttons.set_action_visible("fight", true)') \
			and not battle_source.contains('action_buttons.set_action_visible("party", true)'),
		true,
		"battle observer mode is read-only and provides a safe leave action"
	)
	_check_equal(
		realtime_source.contains("func seed_spectator_event_cursor(response: Dictionary) -> void:") \
			and battle_source.contains("PvpBattleRealtimeService.seed_spectator_event_cursor(initial_response)"),
		true,
		"spectator websocket joins continue after the HTTP bootstrap history cursor"
	)
	_check_equal(
		battle_source.contains("func _on_spectator_switch_sides_pressed() -> void:") \
			and battle_source.contains('action_flow.set_local_player_id("p2" if spectator_sides_swapped else "p1")') \
			and battle_source.contains("spectator_latest_raw_response") \
			and battle_source.contains('mapped_snapshot["events"] = []') \
			and battle_source.contains("battle_state.reset_side_relative_presentation_memory()") \
			and battle_source.contains("var canonical_response := action_flow.map_response_for_local_player(response)") \
			and battle_source.contains("func _swap_spectator_public_knowledge_sides() -> void:"),
		true,
		"spectator side switching remaps an authoritative snapshot without replaying events"
	)
	_check_equal(
		battle_source.contains("func _run_pvp_spectator_team_preview() -> Dictionary:") \
			and battle_source.contains('current_action_panel.set_message("Waiting for both players...")') \
			and battle_source.contains("_seed_spectator_leads_from_team_preview_events(display_response)") \
			and battle_source.contains("_build_spectator_lead_event_from_public_ident(player_id, public_ident)") \
			and battle_source.contains('for ident_key in ["target", "actor", "pokemon", "sourceTarget", "fromIdent", "toIdent"]') \
			and battle_source.contains("battle_state.build_public_switch_event_for_ident(player_id, public_ident)") \
			and battle_source.contains("_ensure_spectator_active_pokemon_for_event(event_data)") \
			and battle_source.contains("battle_state.get_active_player_pokemon(player_id).is_empty()") \
			and battle_source.contains("_remember_spectator_canonical_response(display_response)") \
			and battle_source.contains('if event_type in ["move", "damage", "heal", "status", "cant", "fail", "miss", "faint"]') \
			and battle_source.contains("if seeded_players.size() >= 2:") \
			and battle_source.contains("if _is_spectator_battle():\n\t\treturn true"),
		true,
		"spectators seed public leads before the intro and continuously drain live battle updates"
	)
	_check_equal(
		battle_source.contains("func _apply_spectator_late_join_snapshot(response: Dictionary) -> bool:") \
			and battle_source.contains('canonical_snapshot["events"] = []') \
			and battle_source.contains('canonical_snapshot["eventBatches"] = []') \
			and battle_source.contains('"spectator_late_join_snapshot"') \
			and battle_source.contains("var response_event_seq := _get_pvp_response_event_seq_end(response)"),
		true,
		"late spectators consume historical cursors and render only the canonical current snapshot"
	)

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
	service._apply_timer_projection_from_battle_response({"response":{"timerState":{"timerContractVersion":1,"authority":"BATTLE_BANK_V1_SHADOW","timerRevision":1,"battleEventSeq":41,"serverNowMs":1,"participants":{}}}})
	_check_equal(service.last_battle_event_seq, 3, "newer timer snapshot cannot skip unapplied durable terminal events")

	var gap_service := PvpBattleRealtimeServiceNode.new()
	gap_service.active_room_code = "ROOM"
	gap_service.should_reconnect = true
	gap_service.joined = true
	gap_service.join_sent = true
	gap_service.awaiting_pong = true
	gap_service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-gap",
		"battleEventLatestSeq": 2,
		"events": [{"battleEventSeq": 2, "type": "battle.turn_resolved"}],
	})
	_check_equal(gap_service.last_battle_event_seq, 0, "durable stream never skips a missing event")
	_check_equal(gap_service.joined, false, "durable event gap restarts the realtime join")
	_check_equal(gap_service.awaiting_pong, false, "durable event gap clears the old heartbeat state")
	gap_service.free()

	var terminal_messages: Array[Dictionary] = []
	service.battle_update_received.connect(func(message: Dictionary) -> void: terminal_messages.append(message))
	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"roomCode": "ROOM",
		"battleId": "battle-1",
		"matchId": "match-1",
		"battleEventLatestSeq": 4,
		"events": [{
			"battleEventSeq": 4,
			"type": "battle.ended",
			"payload": {"category":"INFRASTRUCTURE_NO_CONTEST","terminalResultId":"terminal-1","winner":null,"loser":null,"noContest":true,"noPenalty":true,"endReason":"infrastructure_no_contest"},
		}],
	})
	_check_equal(terminal_messages.size(), 1, "durable no-contest event emits one terminal client outcome")
	_check_equal(terminal_messages[0].get("terminalResultId"), "terminal-1", "terminal client outcome retains canonical result id")
	service._handle_battle_events_message({"type":"pvp.battle_events","battleId":"battle-1","battleEventLatestSeq":4,"events":[{"battleEventSeq":4,"type":"battle.ended","payload":{"category":"INFRASTRUCTURE_NO_CONTEST","terminalResultId":"terminal-1","winner":null,"loser":null,"noContest":true,"noPenalty":true,"endReason":"infrastructure_no_contest"}}]})
	_check_equal(terminal_messages.size(), 1, "duplicate terminal delivery has no repeated client consequence")
	var normal_terminal_service := PvpBattleRealtimeServiceNode.new()
	var normal_terminal_messages: Array[Dictionary] = []
	normal_terminal_service.battle_update_received.connect(func(message: Dictionary) -> void: normal_terminal_messages.append(message))
	normal_terminal_service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"roomCode": "ROOM",
		"battleId": "battle-1",
		"matchId": "match-1",
		"battleEventLatestSeq": 1,
		"events": [{
			"battleEventSeq": 1,
			"type": "battle.ended",
			"payload": {"winnerSide":"p1","loserSide":"p2","endReason":"timeout","source":"AUTO_TIMEOUT"},
		}],
	})
	_check_equal(normal_terminal_messages.size(), 1, "durable normal terminal event emits a client outcome")
	_check_equal(normal_terminal_messages[0].get("type"), "pvp.authoritative_terminal", "normal terminal uses the authoritative terminal path")
	_check_equal(normal_terminal_messages[0].get("winnerSide"), "p1", "normal terminal retains the canonical winner side")
	_check_equal(normal_terminal_messages[0].get("endReason"), "timeout", "normal terminal retains its end reason")
	_check_equal(PvpBattleRealtimeServiceNode.is_infrastructure_no_contest_result({"reason":"infrastructure_no_contest","terminalCategory":"INFRASTRUCTURE_NO_CONTEST","terminalResultId":"terminal-1","noContest":true,"noPenalty":true}), true, "canonical no-contest result is classified for no-persistence finish")
	_check_equal(PvpBattleRealtimeServiceNode.allows_gameplay_persistence_for_terminal({"reason":"infrastructure_no_contest","terminalCategory":"INFRASTRUCTURE_NO_CONTEST","terminalResultId":"terminal-1","noContest":true,"noPenalty":true}), false, "infrastructure no-contest cannot persist healing or invalid battle gameplay")

	var payload := service._build_join_payload()
	_check_equal(payload.get("lastBattleEventSeq"), 4, "join payload includes lastBattleEventSeq")
	_check_equal(payload.get("matchId"), "match-1", "join payload still includes matchId")
	_check_equal(payload.get("timerContractVersions"), [1], "join advertises timer contract v1")
	_check_equal(payload.get("decisionContractVersions"), [1], "join advertises decision contract v1")
	_check_equal(payload.get("battleCommandContractVersions"), [1], "join advertises command contract v1")

	var timer_update_applied := service._apply_timer_projection_from_battle_response({
		"type": "pvp.battle_update",
		"response": {
			"timerState": {
				"timerContractVersion": 1,
				"authority": "BATTLE_BANK_V1_SHADOW",
				"timerRevision": 4,
				"battleEventSeq": 3,
				"serverNowMs": 10_000,
				"participants": {
					"p1": {"playerId": "p1", "status": "IDLE", "mainBankRemainingMs": 75_000, "mainBankMaximumMs": 90_000},
					"p2": {"playerId": "p2", "status": "RUNNING", "decisionId": "d2", "decisionGeneration": 1, "decisionKind": "MOVE_SELECTION", "mainBankRemainingMs": 80_000, "mainBankMaximumMs": 90_000, "maxDecisionMs": 90_000, "actionableAtMs": 10_000, "bankChargeStartsAtMs": 10_000, "decisionCapAtMs": 100_000, "bankExhaustionAtMs": 90_000, "hypotheticalDeadlineAtMs": 90_000},
				},
			},
		},
	})
	_check_equal(timer_update_applied, true, "battle update applies its timer projection")
	_check_equal(service.timer_projection.participant_display("p1", service.timer_projection.monotonic_anchor_ms).get("state"), "WAITING", "accepted local choice stops its displayed clock")
	_check_equal(service.timer_projection.participant_display("p1", service.timer_projection.monotonic_anchor_ms + 5_000).get("bankRemainingMs"), 75_000, "accepted local choice no longer drains")
	_check_equal(service.timer_projection.participant_display("p2", service.timer_projection.monotonic_anchor_ms + 5_000).get("state"), "DECIDING", "opponent clock continues while opponent is choosing")
	_check_equal(service.timer_projection.participant_display("p2", service.timer_projection.monotonic_anchor_ms + 5_000).get("effectiveDecisionRemainingMs"), 75_000, "opponent decision countdown continues independently")
	service.timer_projection.authority = BattleTimerProjection.BATTLE_BANK_V1_AUTHORITY
	service.timer_projection.participants["p2"] = {
		"decisionId": "durable-new-decision",
		"decisionGeneration": 14,
		"decisionKind": "MOVE_SELECTION",
	}
	var resynchronized_decision := service.decision_for_action("p2", {
		"decisionId": "stale-battle-state-decision",
		"decisionGeneration": 13,
		"decisionKind": "MOVE_SELECTION",
	})
	_check_equal(resynchronized_decision.get("decisionId"), "durable-new-decision", "authority action uses a newer durable decision identity")
	_check_equal(resynchronized_decision.get("decisionGeneration"), 14, "authority action advances beyond stale BattleState generation")
	service.timer_projection.pause_for_reconnect(service.timer_projection.monotonic_anchor_ms + 5_000)
	service.timer_projection.resume_after_reconnect(service.timer_projection.monotonic_anchor_ms + 20_000)
	var reconnect_sync_applied := service._apply_timer_contract_message("battle.timer_sync", {
		"payload": {
			"timerContractVersion": 1,
			"authority": "BATTLE_BANK_V1_SHADOW",
			"timerRevision": 5,
			"battleEventSeq": 4,
			"serverNowMs": 30_000,
			"participants": {
				"p1": {"playerId": "p1", "status": "IDLE", "mainBankRemainingMs": 75_000, "mainBankMaximumMs": 90_000},
				"p2": {"playerId": "p2", "status": "RUNNING", "decisionId": "d2", "decisionGeneration": 1, "decisionKind": "MOVE_SELECTION", "mainBankRemainingMs": 75_000, "mainBankMaximumMs": 90_000, "maxDecisionMs": 90_000, "actionableAtMs": 20_000, "bankChargeStartsAtMs": 20_000, "decisionCapAtMs": 110_000, "bankExhaustionAtMs": 105_000, "hypotheticalDeadlineAtMs": 105_000},
			},
		},
	})
	_check_equal(reconnect_sync_applied, true, "reconnect timer sync replaces the stale pre-resume snapshot")
	_check_equal(service.timer_projection.participant_display("p2", service.timer_projection.monotonic_anchor_ms).get("effectiveDecisionRemainingMs"), 75_000, "reconnect resumes from the server-shifted remaining time")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"afterBattleEventSeq": 4,
		"battleEventLatestSeq": 5,
		"events": [],
	})
	_check_equal(service.battle_event_latest_seq, 5, "empty events still update latest seq")
	_check_equal(service.last_battle_event_seq, 4, "remote latest does not skip unapplied pages")
	_check_equal(service.received_battle_event_count, 4, "empty events do not increase received count")

	service._handle_battle_events_message({
		"type": "pvp.battle_events",
		"battleId": "battle-1",
		"battleEventLatestSeq": "7",
		"events": [
			{"battleEventSeq": "6", "type": "battle.choice_submitted"},
			{"battleEventSeq": "5", "type": "battle.turn_resolved"},
			{"battleEventSeq": "5", "type": "duplicate"},
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

	var timeout_end_message := {
		"action": "forfeit",
		"playerId": "p1",
		"response": {
			"pvpMatchEndEvent": "pvp.timeout_forfeit",
			"pvpMatchEnd": {"success": true, "winnerUserId": 2, "loserUserId": 1},
		},
	}
	_check_equal(
		PvpBattleRealtimeServiceNode.should_apply_terminal_action_immediately(timeout_end_message, "p1"),
		true,
		"expired player applies the server-confirmed timeout end"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_apply_terminal_action_immediately(timeout_end_message, "p2"),
		true,
		"winning player applies the server-confirmed timeout end"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_apply_terminal_action_immediately(
			{"action": "forfeit", "playerId": "p1", "response": {"success": true, "state": {"ended": true}}},
			"p1"
		),
		true,
		"local manual forfeit terminal broadcast finishes even if its direct waiter loses the race"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_apply_terminal_action_immediately(
			{"action": "forfeit", "playerId": "p1", "response": {"success": true}},
			"p1"
		),
		false,
		"local manual forfeit requires mechanical terminal proof"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_apply_terminal_action_immediately(
			{"action": "forfeit", "playerId": "p1", "response": {"success": false, "state": {"ended": true}}},
			"p1"
		),
		false,
		"failed local forfeit cannot end the client battle"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(false, false, "", false),
		true,
		"normal authoritative terminal waits for the ended mechanical projection"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(true, true, "batch-final", false),
		true,
		"normal authoritative terminal waits for the active final render batch"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(true, false, "", true),
		true,
		"normal authoritative terminal waits for queued render work"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(true, false, "", false),
		false,
		"normal authoritative terminal can finish after the final projection and queue are complete"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(false, false, "", false, false),
		false,
		"animation-free durable terminal does not wait for a separate ended projection"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(false, true, "batch-final", false, false),
		true,
		"animation-free durable terminal still waits for an active render batch"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.should_defer_authoritative_terminal_until_render(false, false, "", true, false),
		true,
		"animation-free durable terminal still waits for queued work"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_animation_free_authoritative_terminal_reason(" timeout "),
		true,
		"timeout is recognized as animation-free terminal work"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_animation_free_authoritative_terminal_reason("disconnect"),
		true,
		"disconnect is recognized as animation-free terminal work"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_animation_free_authoritative_terminal_reason("forfeit"),
		true,
		"forfeit is recognized as animation-free terminal work"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_animation_free_authoritative_terminal_reason("battle_end"),
		false,
		"normal battle end still waits for its final mechanical projection"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.classify_action_timeout_recovery(
			{"success": false}, "p1", "decision-1", 1
		),
		PvpBattleRealtimeServiceNode.ACTION_TIMEOUT_RECOVERY_UNAVAILABLE,
		"failed canonical lookup cannot claim action recovery"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.classify_action_timeout_recovery(
			{"success": true, "state": {"ended": true}}, "p1", "decision-1", 1
		),
		PvpBattleRealtimeServiceNode.ACTION_TIMEOUT_RECOVERY_TERMINAL,
		"ended canonical state recovers a lost terminal response"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.classify_action_timeout_recovery(
			{"success": true, "requests": {"p2": {"wait": true}}}, "p2", "decision-1", 1
		),
		PvpBattleRealtimeServiceNode.ACTION_TIMEOUT_RECOVERY_ACCEPTED,
		"waiting canonical request proves the submitted choice was accepted"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.classify_action_timeout_recovery(
			{"success": true, "requests": {"p1": {}}, "decisions": {"p1": {"decisionId": "decision-2", "decisionGeneration": 2}}},
			"p1",
			"decision-1",
			1
		),
		PvpBattleRealtimeServiceNode.ACTION_TIMEOUT_RECOVERY_ADVANCED,
		"new canonical decision proves the battle advanced beyond the lost response"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.classify_action_timeout_recovery(
			{"success": true, "phase": "turn_open", "requests": {"p1": {"active": []}}, "decisions": {"p1": {"decisionId": "decision-1", "decisionGeneration": 1}}},
			"p1",
			"decision-1",
			1
		),
		PvpBattleRealtimeServiceNode.ACTION_TIMEOUT_RECOVERY_RETRY,
		"unchanged actionable decision safely asks the player to choose again"
	)
	_check_equal(PvpBattleRealtimeServiceNode.normalize_terminal_winner(null), "", "null terminal winner is treated as absent")
	_check_equal(PvpBattleRealtimeServiceNode.normalize_terminal_winner("None"), "", "Python None terminal winner is treated as absent")
	_check_equal(PvpBattleRealtimeServiceNode.normalize_terminal_winner("Admin"), "Admin", "real terminal winner name is preserved")
	_check_equal(
		PvpBattleRealtimeServiceNode.is_local_terminal_winner("p1", "p1", "Adinho"),
		true,
		"canonical local winner side produces victory"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_local_terminal_winner("p2", "p1", "Adinho"),
		false,
		"canonical opponent winner side produces defeat"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_local_terminal_winner(" AdInHo ", "p1", "Adinho"),
		true,
		"Showdown winner display name produces victory for that local player"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_local_terminal_winner("Adinho", "p1", "Faker"),
		false,
		"the same Showdown winner display name produces defeat for the opponent"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_unrequested_local_team_preview_lead(
			{"action": "choose_lead", "playerId": "p2", "requestId": "human-request", "response": {"success": true}},
			"p2"
		),
		false,
		"human lead response remains available to its realtime action waiter"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_unrequested_local_team_preview_lead(
			{"action": "choose_lead", "playerId": "p2", "requestId": "", "response": {"success": true}},
			"p2"
		),
		true,
		"server-selected timeout lead without request id uses timeout recovery"
	)
	var actionless_team_preview_completion := {
		"type": "pvp.render_batch",
		"playerId": "p2",
		"response": {
			"success": true,
			"visibilityContractVersion": 2,
			"viewer": {"role": "participant", "side": "p1"},
			"phase": "rendering_events",
			"viewerControl": {"phase": "rendering_events"},
			"battleOptions": {"teamPreview": true},
			"requests": {"p1": {"active": []}, "p2": {"wait": true}},
		},
	}
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_completion_update(
			actionless_team_preview_completion,
			"p1"
		),
		true,
		"the first lead chooser accepts the safe actionless final render batch"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_response(
			actionless_team_preview_completion["response"]
		),
		false,
		"authoritative post-preview phase overrides the persistent format option"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_completion_update(
			actionless_team_preview_completion,
			"p2"
		),
		false,
		"a participant projection for the wrong viewer cannot complete Team Preview"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_completion_update(
			{
				"type": "pvp.battle_update",
				"response": {
					"success": true,
					"visibilityContractVersion": 2,
					"viewer": {"role": "participant", "side": "p1"},
					"phase": "team_preview",
					"requests": {"p1": {"teamPreview": true}},
				},
			},
			"p1"
		),
		false,
		"a pending participant response cannot end Team Preview"
	)
	var accepted_first_lead_response := {
		"success": true,
		"visibilityContractVersion": 2,
		"viewer": {"role": "participant", "side": "p1"},
		"phase": "waiting_for_opponent",
		"viewerControl": {"phase": "waiting_for_opponent"},
		"requests": {
			"p1": {"teamPreview": true, "wait": true},
			"p2": {"teamPreview": true},
		},
	}
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_response(accepted_first_lead_response),
		true,
		"waiting_for_opponent remains Team Preview while its requests say teamPreview"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_team_preview_completion_update(
			{"type": "pvp.battle_update", "response": accepted_first_lead_response},
			"p1"
		),
		false,
		"the first accepted lead cannot prematurely complete Team Preview"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_unrequested_local_forced_switch(
			{"action": "choose_switch", "playerId": "p2", "requestId": "", "response": {"success": true}},
			"p2"
		),
		true,
		"server-selected forced switch without request id uses timeout recovery"
	)
	_check_equal(
		PvpBattleRealtimeServiceNode.is_unrequested_local_forced_switch(
			{"action": "choose_switch", "playerId": "p2", "requestId": "human-request", "response": {"success": true}},
			"p2"
		),
		false,
		"human forced switch remains available to its action waiter"
	)

	normal_terminal_service.free()
	service.free()
	print("PASS pvp_battle_realtime_stream_check")
	quit(0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
	quit(1)
