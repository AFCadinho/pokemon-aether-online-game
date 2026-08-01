extends SceneTree

const RealtimeService = preload("res://scripts/services/pvp_battle_realtime_service.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const REALTIME_SERVICE_SCRIPT_PATH := "res://scripts/services/pvp_battle_realtime_service.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_check_actionless_participant_render_contract()
	_check_presentation_fence_contract()
	_check_rendering_phase_action_guard()
	_check_duplicate_phase_release_clears_reintroduced_fence()
	_check_stale_transport_exact_release_clears_current_fence()
	_check_gateway_epoch_change_drops_process_local_fence()
	_check_authoritative_unfenced_snapshot_evicts_current_fence()
	_check_render_ack_retry_generation_ownership()
	_check_waiters_consume_actionless_render_batches()
	_check_accepted_local_choice_arms_idle_drain()
	_check_render_completion_rearms_idle_drain()
	_check_realtime_render_batch_installs_presentation_fence()
	_check_stale_and_unrendered_apply_outcomes()
	_check_stale_snapshot_still_observes_transport_fence()
	_check_prejoin_battle_event_paging()
	_check_private_action_resync_resolves_only_the_correlated_waiter()
	_check_idle_wait_watchdog_recovers_canonical_snapshot()

	if failures > 0:
		quit(1)
		return
	print("PASS pvp_privacy_render_resolution_check")
	quit(0)


func _check_actionless_participant_render_contract() -> void:
	# p1 chose first, so p2's resolving action is private and p1 receives an
	# actionless participant projection.
	var p1_first_move := _make_actionless_render_batch("p1", "p2", "move-batch", 8, 42)
	_check(
		RealtimeService.is_actionless_participant_render_candidate(
			p1_first_move,
			"p1",
			"battle-1"
		),
		"the Gateway-shaped actionless participant batch is recognized before strict validation"
	)
	_check(
		RealtimeService.is_actionless_opponent_render_batch(p1_first_move, "p1", "battle-1"),
		"p1-first accepts p2's actionless resolved move batch"
	)

	# Mirror the exact delivery for p2-first. Neither actor ordering may depend on
	# the hidden choice category or request correlation.
	var p2_first_move := _make_actionless_render_batch("p2", "p1", "move-batch", 8, 42)
	_check(
		RealtimeService.is_actionless_opponent_render_batch(p2_first_move, "p2", "battle-1"),
		"p2-first accepts p1's actionless resolved move batch"
	)

	var forced_switch_timeout := _make_actionless_render_batch(
		"p1",
		"p2",
		"forced-switch-timeout-batch",
		9,
		43,
		"turn_open",
		[{"type": "switch", "actor": "p2a: Alomomola"}]
	)
	_check(
		RealtimeService.is_actionless_opponent_render_batch(
			forced_switch_timeout,
			"p1",
			"battle-1"
		),
		"an opponent timeout forced-switch resolves through the same public batch contract"
	)

	for mutation in [
		{"requestId": "private-request"},
		{"action": "choose_move"},
		{"playerId": "p1"},
		{"battleId": "other-battle"},
		{"batchSeq": 99},
		{"eventBatchId": "mismatched-envelope-batch"},
	]:
		var invalid := p1_first_move.duplicate(true)
		for key: Variant in mutation:
			invalid[key] = mutation[key]
		_check(
			not RealtimeService.is_actionless_opponent_render_batch(invalid, "p1", "battle-1"),
			"private/cross-boundary render envelope is rejected: %s" % JSON.stringify(mutation)
		)

	var wrong_viewer := p1_first_move.duplicate(true)
	wrong_viewer["response"]["viewer"]["side"] = "p2"
	_check(
		not RealtimeService.is_actionless_opponent_render_batch(wrong_viewer, "p1", "battle-1"),
		"a response projected for another participant is rejected"
	)
	var mismatched_response_batch := p1_first_move.duplicate(true)
	mismatched_response_batch["response"]["eventBatches"][0]["eventSeqEnd"] = 41
	_check(
		RealtimeService.is_actionless_participant_render_candidate(
			mismatched_response_batch,
			"p1",
			"battle-1"
		),
		"a same-battle malformed actionless batch remains a fail-closed recovery candidate"
	)
	_check(
		not RealtimeService.is_actionless_opponent_render_batch(
			mismatched_response_batch,
			"p1",
			"battle-1"
		),
		"an envelope whose latest response batch has another event boundary is rejected"
	)
	var mismatched_response_cursor := p1_first_move.duplicate(true)
	mismatched_response_cursor["response"]["eventSeq"] = 43
	_check(
		not RealtimeService.is_actionless_opponent_render_batch(
			mismatched_response_cursor,
			"p1",
			"battle-1"
		),
		"an envelope whose response cursor does not match its render boundary is rejected"
	)


func _check_presentation_fence_contract() -> void:
	var snapshot := _make_fenced_snapshot("p1", "fenced-batch", 8, 42)
	var fence := RealtimeService.presentation_fence_from_snapshot(snapshot, "p1", "battle-1")
	_check(
		fence == {
			"releasePending": true,
			"eventBatchId": "fenced-batch",
			"batchSeq": 8,
			"eventSeqEnd": 42,
			"turn": 2,
		},
		"a valid reconnect snapshot exposes its unresolved presentation fence"
	)
	_check(
		not RealtimeService.has_malformed_present_presentation_fence(
			snapshot,
			"p1",
			"battle-1"
		),
		"a valid presentation fence is never rejected by the malformed-fence guard"
	)

	var cursor_behind := snapshot.duplicate(true)
	cursor_behind["response"]["eventSeq"] = 41
	cursor_behind["response"]["eventBatches"][0]["eventSeqEnd"] = 41
	_check(
		RealtimeService.presentation_fence_from_snapshot(cursor_behind, "p1", "battle-1").is_empty(),
		"a fence ahead of the authoritative response cursor is rejected"
	)

	var exact_release := {
		"type": "pvp.phase_update",
		"battleId": "battle-1",
		"eventBatchId": "fenced-batch",
		"batchSeq": 8,
		"lastRenderedSeq": 42,
		"phase": "turn_open",
	}
	_check(
		RealtimeService.phase_update_releases_presentation_fence(exact_release, fence, "battle-1"),
		"the exact fenced batch releases presentation"
	)

	var equal_but_unmatched := exact_release.duplicate(true)
	equal_but_unmatched["eventBatchId"] = "unrelated-batch"
	_check(
		not RealtimeService.phase_update_releases_presentation_fence(equal_but_unmatched, fence, "battle-1"),
		"an unmatched equal cursor cannot release the fence"
	)

	var newer_batch_release := equal_but_unmatched.duplicate(true)
	newer_batch_release["batchSeq"] = 9
	_check(
		RealtimeService.phase_update_releases_presentation_fence(newer_batch_release, fence, "battle-1"),
		"an unmatched strictly newer batch with a cumulative render cursor releases the fence"
	)

	var newer_render_release := equal_but_unmatched.duplicate(true)
	newer_render_release["lastRenderedSeq"] = 43
	_check(
		RealtimeService.phase_update_releases_presentation_fence(newer_render_release, fence, "battle-1"),
		"an unmatched strictly newer cumulative render cursor releases the fence"
	)

	var wrong_battle_release := exact_release.duplicate(true)
	wrong_battle_release["battleId"] = "other-battle"
	_check(
		not RealtimeService.phase_update_releases_presentation_fence(wrong_battle_release, fence, "battle-1"),
		"a cross-battle phase update cannot release the fence"
	)
	var non_release_phase := exact_release.duplicate(true)
	non_release_phase["phase"] = "rendering_events"
	_check(
		not RealtimeService.phase_update_releases_presentation_fence(non_release_phase, fence, "battle-1"),
		"a rendering phase update cannot release its own fence"
	)

	var unfenced_snapshot := snapshot.duplicate(true)
	unfenced_snapshot.erase("presentationFence")
	_check(
		RealtimeService.is_valid_unfenced_participant_snapshot(
			unfenced_snapshot,
			"p1",
			"battle-1"
		),
		"a valid participant snapshot with an absent fence key is an authoritative eviction signal"
	)
	var malformed_present_fence := snapshot.duplicate(true)
	malformed_present_fence["presentationFence"] = {}
	_check(
		not RealtimeService.is_valid_unfenced_participant_snapshot(
			malformed_present_fence,
			"p1",
			"battle-1"
		),
		"a present-but-malformed fence remains fail-closed instead of impersonating absence"
	)
	_check(
		RealtimeService.has_malformed_present_presentation_fence(
			malformed_present_fence,
			"p1",
			"battle-1"
		),
		"an applicable snapshot classifies a present-but-malformed fence as an integrity failure"
	)
	_check(
		not RealtimeService.has_malformed_present_presentation_fence(
			unfenced_snapshot,
			"p1",
			"battle-1"
		),
		"an absent presentation fence remains a valid explicit rebase instead of a malformed fence"
	)
	var foreign_malformed_fence := malformed_present_fence.duplicate(true)
	foreign_malformed_fence["battleId"] = "other-battle"
	foreign_malformed_fence["response"]["battleId"] = "other-battle"
	_check(
		not RealtimeService.has_malformed_present_presentation_fence(
			foreign_malformed_fence,
			"p1",
			"battle-1"
		),
		"a foreign snapshot is not misclassified as a local malformed-fence recovery request"
	)


func _check_rendering_phase_action_guard() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for phase-guard behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({
		"battleId": "battle-1",
		"requests": {
			"p1": {"active": [{"moves": [{"move": "Stealth Rock"}]}]},
			"p2": {"wait": true},
		},
		"decisions": {
			"p1": {"status": "ACTIVE", "decisionId": "turn-2", "decisionGeneration": 2},
		},
	}, false)

	controller.pvp_last_phase = "rendering_events"
	_check(
		not controller._pvp_local_request_allows_action_recovery("p1"),
		"a turn-2 request remains non-actionable while rendering_events is fenced"
	)
	controller.pvp_last_phase = "turn_open"
	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "fenced-batch",
		"batchSeq": 8,
		"eventSeqEnd": 42,
		"turn": 2,
	}
	_check(
		not controller._pvp_local_request_allows_action_recovery("p1"),
		"a snapshot cannot open turn-2 input while its presentation fence remains pending"
	)
	var equal_cursor_other_batch: Dictionary = controller.pvp_pending_presentation_fence.duplicate(true)
	equal_cursor_other_batch["eventBatchId"] = "unrelated-batch"
	_check(
		not controller._should_replace_pvp_presentation_fence(equal_cursor_other_batch),
		"an unrelated equal-cursor snapshot cannot replace the active fence"
	)
	var newer_cursor_other_batch: Dictionary = equal_cursor_other_batch.duplicate(true)
	newer_cursor_other_batch["batchSeq"] = 9
	_check(
		controller._should_replace_pvp_presentation_fence(newer_cursor_other_batch),
		"a different snapshot fence is accepted only when a cursor is strictly newer"
	)
	controller._update_pvp_phase_contract_from_response({
		"phase": "turn_open",
		"nextPhase": "turn_open",
		"eventSeq": 42,
		"batchSeq": 8,
	}, "pvp_snapshot_reconciliation")
	_check(
		controller.pvp_last_phase == "rendering_events"
			and controller.pvp_last_next_phase == "turn_open"
			and not controller.pvp_pending_presentation_fence.is_empty(),
		"snapshot phase reconciliation cannot overwrite or clear a pending presentation fence"
	)
	controller.pvp_pending_presentation_fence.clear()
	controller.pvp_last_phase = "turn_open"
	_check(
		controller._pvp_local_request_allows_action_recovery("p1"),
		"the same ACTIVE request becomes actionable after the turn_open release"
	)
	controller.free()


func _check_duplicate_phase_release_clears_reintroduced_fence() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for duplicate release behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({"battleId": "battle-1"}, false)
	controller.pvp_last_phase = "turn_open"
	controller.pvp_last_applied_server_seq = 77
	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "fenced-batch",
		"batchSeq": 8,
		"eventSeqEnd": 42,
		"turn": 2,
	}
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "fenced-batch",
		"success": true,
	}
	controller._apply_pvp_phase_update({
		"type": "pvp.phase_update",
		"battleId": "battle-1",
		"serverSeq": 77,
		"eventBatchId": "fenced-batch",
		"batchSeq": 8,
		"lastRenderedSeq": 42,
		"phase": "turn_open",
	})
	_check(
		controller.pvp_pending_presentation_fence.is_empty()
			and controller.pvp_pending_render_ack_completion.is_empty()
			and controller.pvp_last_phase == "turn_open",
		"a matching duplicate release idempotently clears reintroduced fence and ACK state"
	)
	controller.free()


func _check_stale_transport_exact_release_clears_current_fence() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for stale-sequence exact release behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({"battleId": "battle-1"}, false)
	controller.battle_finished = true # Avoid UI mutation; only the release contract is under test.
	controller.pvp_last_phase = "rendering_events"
	controller.pvp_last_applied_server_seq = 100
	controller.pvp_last_phase_update_server_seq = 100
	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "missed-release-batch",
		"batchSeq": 8,
		"eventSeqEnd": 42,
		"turn": 2,
	}
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "missed-release-batch",
		"success": true,
	}
	controller._apply_pvp_phase_update({
		"type": "pvp.phase_update",
		"battleId": "battle-1",
		"serverSeq": 90,
		"eventBatchId": "missed-release-batch",
		"batchSeq": 8,
		"lastRenderedSeq": 42,
		"phase": "turn_open",
	})
	_check(
		controller.pvp_pending_presentation_fence.is_empty()
			and controller.pvp_pending_render_ack_completion.is_empty()
			and controller.pvp_last_phase == "turn_open"
			and controller.pvp_last_applied_server_seq == 100
			and controller.pvp_last_phase_update_server_seq == 100,
		"an exact missed release clears the current fence despite an older transport sequence without regressing cursors"
	)
	controller.free()


func _check_gateway_epoch_change_drops_process_local_fence() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for gateway-epoch behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({"battleId": "battle-1"}, false)
	controller.pvp_gateway_epoch = "epoch-a"
	controller.pvp_last_phase = "rendering_events"
	controller.pvp_last_applied_server_seq = 77
	controller.pvp_last_applied_snapshot_server_seq = 76
	controller.pvp_last_phase_update_server_seq = 75
	controller.pvp_last_connection_server_seq = 74
	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "old-process-batch",
		"batchSeq": 8,
		"eventSeqEnd": 42,
		"turn": 2,
	}
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "old-process-batch",
		"success": true,
	}
	controller.pvp_render_ack_retry_active = true

	var replacement_snapshot := _make_fenced_snapshot("p1", "snapshot-batch", 9, 43)
	replacement_snapshot["gatewayEpoch"] = "epoch-b"
	replacement_snapshot.erase("presentationFence")
	replacement_snapshot["response"]["phase"] = "turn_open"
	replacement_snapshot["response"]["nextPhase"] = "turn_open"
	controller._observe_pvp_gateway_epoch(replacement_snapshot)
	controller._observe_pvp_presentation_fence(replacement_snapshot)
	controller._update_pvp_phase_contract_from_response(
		replacement_snapshot["response"],
		"pvp_snapshot_reconciliation"
	)
	_check(
		controller.pvp_gateway_epoch == "epoch-b"
			and controller.pvp_pending_presentation_fence.is_empty()
			and controller.pvp_pending_render_ack_completion.is_empty()
			and not controller.pvp_render_ack_retry_active
			and controller.pvp_last_applied_server_seq == 0
			and controller.pvp_last_applied_snapshot_server_seq == 0
			and controller.pvp_last_phase_update_server_seq == 0
			and controller.pvp_last_connection_server_seq == 0
			and controller.pvp_last_phase == "turn_open",
		"gateway epoch A-to-B drops the old process fence/ACK and trusts an unfenced replacement snapshot"
	)
	controller.free()


func _check_authoritative_unfenced_snapshot_evicts_current_fence() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for unfenced snapshot eviction behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({"battleId": "battle-1"}, false)
	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "evicted-batch",
		"batchSeq": 8,
		"eventSeqEnd": 42,
		"turn": 2,
	}
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "evicted-batch",
		"success": true,
	}
	controller.pvp_render_ack_retry_active = true
	var unfenced_snapshot := _make_fenced_snapshot("p1", "snapshot-batch", 9, 43)
	unfenced_snapshot.erase("presentationFence")
	controller._clear_pvp_presentation_fence_from_unfenced_snapshot(unfenced_snapshot)
	_check(
		controller.pvp_pending_presentation_fence.is_empty()
			and controller.pvp_pending_render_ack_completion.is_empty()
			and not controller.pvp_render_ack_retry_active,
		"a validated unfenced participant snapshot evicts process-local fence and ACK recovery state"
	)

	controller.pvp_pending_presentation_fence = {
		"releasePending": true,
		"eventBatchId": "still-guarded-batch",
		"batchSeq": 10,
		"eventSeqEnd": 44,
		"turn": 2,
	}
	var malformed_present_fence := unfenced_snapshot.duplicate(true)
	malformed_present_fence["presentationFence"] = {}
	controller._clear_pvp_presentation_fence_from_unfenced_snapshot(malformed_present_fence)
	_check(
		str(controller.pvp_pending_presentation_fence.get("eventBatchId", ""))
			== "still-guarded-batch",
		"a malformed present fence cannot fail open by clearing the current boundary"
	)
	controller.free()


func _check_render_ack_retry_generation_ownership() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for render-ACK retry ownership")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "batch-a",
		"success": true,
	}
	controller._start_pvp_render_ack_retry()
	var batch_a_generation: int = controller.pvp_render_ack_retry_generation
	controller.pvp_pending_render_ack_completion = {
		"event_batch_id": "batch-b",
		"success": true,
	}
	controller._start_pvp_render_ack_retry()
	var batch_b_generation: int = controller.pvp_render_ack_retry_generation
	controller._finish_pvp_render_ack_retry_generation(batch_a_generation)
	_check(
		batch_b_generation > batch_a_generation
			and controller.pvp_render_ack_retry_active
			and str(controller.pvp_pending_render_ack_completion.get("event_batch_id", ""))
				== "batch-b",
		"batch B owns a new retry generation and batch A cannot clear its active state"
	)
	controller._finish_pvp_render_ack_retry_generation(batch_b_generation)
	_check(
		not controller.pvp_render_ack_retry_active,
		"only the current batch B generation may finish the retry lifecycle"
	)
	controller.free()


func _check_waiters_consume_actionless_render_batches() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var move_wait := _function_source(battle_source, "_wait_for_pvp_opponent_choice_and_render")
	var force_wait := _function_source(battle_source, "_wait_for_pvp_opponent_force_switch_and_render")
	var realtime_handler := _function_source(battle_source, "_on_pvp_realtime_battle_update")
	var private_action_filters := [
		move_wait.find('if not (message_action in ["choose_move", "choose_switch"]):'),
		force_wait.find('if message_action != "choose_switch" and message_action != "choose_move":'),
	]
	for waiter_index: int in range(2):
		var waiter: String = [move_wait, force_wait][waiter_index]
		var actionless_index := waiter.find("is_actionless_opponent_render_batch")
		_check(
			actionless_index >= 0
				and waiter.contains('"pvp_privacy_projected_render"')
				and private_action_filters[waiter_index] >= 0
				and actionless_index < private_action_filters[waiter_index],
			"the active waiter consumes the actionless batch before private-action filtering"
		)
	_check(
		battle_source.contains('if pvp_last_phase == "rendering_events" or not pvp_pending_presentation_fence.is_empty():'),
		"request recovery cannot bypass the shared rendering phase"
	)
	_check(
		realtime_handler.contains("is_actionless_participant_render_candidate")
			and realtime_handler.contains("_reject_invalid_actionless_pvp_render_batch"),
		"a malformed same-battle actionless render fails into resync before it can be silently queued or discarded"
	)
	_check(
		move_wait.contains('"pvp_opponent_render_watchdog"')
			and battle_source.contains("require_unrendered_events := false"),
		"the first-chooser waiter has a render-cursor watchdog independent of phase release"
	)


func _check_accepted_local_choice_arms_idle_drain() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var submit_choice := _function_source(battle_source, "_submit_pvp_realtime_choice")
	var recovery_helper := _function_source(battle_source, "_arm_pvp_local_choice_wait_recovery")
	var arm_index := submit_choice.find("_arm_pvp_local_choice_wait_recovery()")
	var enqueue_index := submit_choice.find("_enqueue_pvp_battle_response")
	_check(
		arm_index >= 0 and enqueue_index >= 0 and arm_index < enqueue_index,
		"an accepted local choice arms recovery before a stale/no-op response can finish queueing"
	)
	_check(
		recovery_helper.contains("pvp_idle_wait_recovery_active = true")
			and recovery_helper.contains("_drain_idle_pvp_realtime_updates.call_deferred()"),
		"accepted local choices independently drain actionless realtime batches"
	)


func _check_render_completion_rearms_idle_drain() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var drain := _function_source(battle_source, "_drain_pvp_event_queue")
	var release_index := drain.find("pvp_event_queue.is_rendering = false")
	var idle_drain_index := drain.find("_drain_idle_pvp_realtime_updates.call_deferred()")
	_check(
		release_index >= 0 and idle_drain_index > release_index,
		"render completion re-arms idle delivery after a pivot batch raced the active queue"
	)


func _check_realtime_render_batch_installs_presentation_fence() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var render_batch := _function_source(battle_source, "_render_pvp_event_batch")
	var fence_helper := _function_source(battle_source, "_observe_pvp_realtime_render_batch_fence")
	var begin_index := render_batch.find("pvp_event_queue.begin_render_batch")
	var fence_index := render_batch.find("_observe_pvp_realtime_render_batch_fence")
	var render_index := render_batch.find("await _render_battle_events", fence_index)
	_check(
		begin_index >= 0 and fence_index > begin_index and render_index > fence_index,
		"a realtime render batch installs its local fence before presentation starts"
	)
	_check(
		fence_helper.contains('\"releasePending\": true')
			and fence_helper.contains('pvp_last_phase = \"rendering_events\"')
			and fence_helper.contains("pvp_idle_wait_recovery_active = true")
			and fence_helper.contains("_set_battle_input_locked(true)"),
		"the realtime fence holds controls and recovery until the matching phase release"
	)


func _check_idle_wait_watchdog_recovers_canonical_snapshot() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var observer := _function_source(battle_source, "_report_stalled_pvp_waiting_if_needed")
	var recovery := _function_source(battle_source, "_recover_stalled_pvp_idle_wait")
	_check(
		observer.contains("PVP_IDLE_WAIT_RECONCILE_MSEC")
			and observer.contains("_recover_stalled_pvp_idle_wait.call_deferred()"),
		"a stranded waiting UI actively starts canonical recovery"
	)
	_check(
		recovery.contains('"pvp_idle_wait_watchdog"')
			and recovery.contains("_recover_pvp_idle_wait_ui_after_update"),
		"idle recovery applies the canonical snapshot and reopens only authoritative controls"
	)


func _check_stale_and_unrendered_apply_outcomes() -> void:
	var battle_script: Script = load(BATTLE_SCRIPT_PATH)
	_check(battle_script != null, "battle controller loads for response-apply outcome behavior")
	if battle_script == null:
		return
	var controller: Variant = battle_script.new()
	controller.pvp_room_code = "ROOM"
	controller.action_flow.set_local_player_id("p1")
	controller.battle_state.load_from_api_response({
		"success": true,
		"battleId": "battle-1",
		"turn": 6,
		"eventSeq": 38,
		"batchSeq": 5,
	}, false)
	controller.pvp_event_queue.last_rendered_seq = 38
	controller.pvp_response_order.remember({
		"success": true,
		"battleId": "battle-1",
		"turn": 6,
		"eventSeq": 48,
		"batchSeq": 7,
	})

	var stale_outcome: Dictionary = {}
	var stale_success: bool = controller._apply_api_response({
		"success": true,
		"battleId": "battle-1",
		"turn": 5,
		"eventSeq": 38,
		"batchSeq": 5,
	}, true, "test_stale_local_response", stale_outcome)
	_check(
		stale_success and str(stale_outcome.get("status", "")) == "stale_noop",
		"a stale local response is successful but explicitly reports that no state was applied"
	)

	var render_outcome: Dictionary = {}
	var render_success: bool = controller._apply_api_response({
		"success": true,
		"battleId": "battle-1",
		"phase": "rendering_events",
		"nextPhase": "awaiting_force_switch",
		"turn": 6,
		"eventSeq": 43,
		"batchSeq": 6,
		"pvpRealtimeMessageType": "pvp.render_batch",
		"events": [{"type": "move", "actor": "p1a: Charizard", "move": "Solar Beam"}],
		"eventBatches": [{
			"eventBatchId": "battle-1:6",
			"batchSeq": 6,
			"eventSeqStart": 39,
			"eventSeqEnd": 43,
		}],
	}, true, "test_unrendered_authoritative_batch", render_outcome)
	_check(
		render_success
			and str(render_outcome.get("status", "")) == "applied"
			and bool(render_outcome.get("required_render_batch", false)),
		"an unrendered authoritative batch survives a newer canonical projection and remains renderable"
	)
	controller.free()


func _check_stale_snapshot_still_observes_transport_fence() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var update_handler := _function_source(battle_source, "_on_pvp_realtime_battle_update")
	var snapshot_branch := update_handler.find('if is_snapshot_message:')
	var malformed_fence_guard := update_handler.find(
		"has_malformed_present_presentation_fence",
		snapshot_branch
	)
	var fence_observer := update_handler.find("_observe_pvp_presentation_fence(message)", snapshot_branch)
	var stale_filter := update_handler.find("_is_stale_pvp_snapshot_response(message, mapped_snapshot)", snapshot_branch)
	var unfenced_eviction := update_handler.find(
		"_clear_pvp_presentation_fence_from_unfenced_snapshot(message)",
		snapshot_branch
	)
	_check(
		snapshot_branch >= 0
			and malformed_fence_guard >= 0
			and fence_observer >= 0
			and stale_filter >= 0
			and unfenced_eviction >= 0
			and malformed_fence_guard < fence_observer
			and fence_observer < stale_filter
			and stale_filter < unfenced_eviction,
		"malformed fences fail closed, new fences are observed before stale filtering, and absence evicts only after acceptance"
	)


func _check_prejoin_battle_event_paging() -> void:
	var service := RealtimeService.new()
	service.last_battle_event_seq = 6
	service.joined = false
	var initial_generation: int = service.connection_attempt_generation
	var initial_socket: WebSocketPeer = service.websocket
	service._handle_battle_events_message({
		"battleEventLatestSeq": 34,
		"events": _battle_events(7, 31),
	})
	_check(
		service.last_battle_event_seq == 31
			and service.connection_attempt_generation == initial_generation
			and service.websocket == initial_socket,
		"the first contiguous pre-join catch-up page does not restart the socket"
	)
	service._handle_battle_events_message({
		"battleEventLatestSeq": 34,
		"events": _battle_events(32, 34),
	})
	var joined_after_complete_catchup := service._handle_joined_message({
		"roomCode": "ROOM",
		"playerId": "p1",
		"battleId": "battle-1",
	})
	_check(
		service.last_battle_event_seq == 34
			and joined_after_complete_catchup
			and service.joined
			and service.connection_attempt_generation == initial_generation,
		"the final pre-join catch-up page reaches the durable head and permits the join commit"
	)

	var incomplete_service := RealtimeService.new()
	incomplete_service.last_battle_event_seq = 6
	incomplete_service.joined = false
	initial_generation = incomplete_service.connection_attempt_generation
	initial_socket = incomplete_service.websocket
	incomplete_service._handle_battle_events_message({
		"battleEventLatestSeq": 9,
		"events": _battle_events(7, 7),
	})
	var joined_with_known_gap := incomplete_service._handle_joined_message({
		"roomCode": "ROOM",
		"playerId": "p1",
		"battleId": "battle-1",
	})
	_check(
		not joined_with_known_gap
			and not incomplete_service.joined
			and incomplete_service.last_battle_event_seq == 7
			and incomplete_service.battle_event_latest_seq == 9
			and incomplete_service.connection_attempt_generation == initial_generation + 1
			and incomplete_service.websocket != initial_socket,
		"a join commit with a known pre-join durable gap restarts fail-closed"
	)
	incomplete_service.free()

	service.joined = true
	service.last_battle_event_seq = 6
	initial_generation = service.connection_attempt_generation
	initial_socket = service.websocket
	service._handle_battle_events_message({
		"battleEventLatestSeq": 9,
		"events": _battle_events(7, 7),
	})
	_check(
		service.last_battle_event_seq == 7
			and service.connection_attempt_generation == initial_generation + 1
			and service.websocket != initial_socket,
		"a genuine joined live-stream gap still restarts for fail-closed recovery"
	)
	service.free()


func _check_private_action_resync_resolves_only_the_correlated_waiter() -> void:
	var service_source := FileAccess.get_file_as_string(REALTIME_SERVICE_SCRIPT_PATH)
	var poll_source := _function_source(service_source, "_process_packets")
	var resync_branch := poll_source.find('if message_type == "pvp.resync_required":')
	var battle_update_emit := poll_source.find(
		"battle_update_received.emit(message)",
		resync_branch
	)
	var private_request_guard := poll_source.find(
		'if request_id != "" and response_value is Dictionary:',
		resync_branch
	)
	var action_response_emit := poll_source.find(
		"action_response_received.emit(request_id, message)",
		resync_branch
	)
	_check(
		resync_branch >= 0
			and battle_update_emit > resync_branch
			and private_request_guard > battle_update_emit
			and action_response_emit > private_request_guard,
		"a shared resync resolves an action waiter only when its private projection carries correlation"
	)


func _make_actionless_render_batch(
	viewer_side: String,
	actor_side: String,
	batch_id: String,
	batch_seq: int,
	event_seq_end: int,
	next_phase := "turn_open",
	events: Array = [{"type": "move", "actor": "p2a: Alomomola", "move": "Flip Turn"}]
) -> Dictionary:
	return {
		"type": "pvp.render_batch",
		"roomCode": "ROOM",
		"battleId": "battle-1",
		"playerId": actor_side,
		"serverSeq": 17,
		"phase": "rendering_events",
		"nextPhase": next_phase,
		"turn": 2,
		"eventBatchId": batch_id,
		"batchSeq": batch_seq,
		"eventSeqEnd": event_seq_end,
		"response": {
			"success": true,
			"visibilityContractVersion": 2,
			"viewer": {"role": "participant", "side": viewer_side},
			"battleId": "battle-1",
			"phase": "rendering_events",
			"nextPhase": next_phase,
			"turn": 2,
			"eventSeq": event_seq_end,
			"batchSeq": batch_seq,
			"events": events,
			"eventBatches": [{
				"eventBatchId": batch_id,
				"batchSeq": batch_seq,
				"eventSeqEnd": event_seq_end,
			}],
		},
	}


func _make_fenced_snapshot(
	viewer_side: String,
	batch_id: String,
	batch_seq: int,
	event_seq_end: int
) -> Dictionary:
	var render_batch := _make_actionless_render_batch(
		viewer_side,
		"p2" if viewer_side == "p1" else "p1",
		batch_id,
		batch_seq,
		event_seq_end
	)
	return {
		"type": "pvp.snapshot",
		"battleId": "battle-1",
		"presentationFence": {
			"releasePending": true,
			"eventBatchId": batch_id,
			"batchSeq": batch_seq,
			"eventSeqEnd": event_seq_end,
			"turn": 2,
		},
		"response": render_batch["response"],
	}


func _battle_events(first_seq: int, last_seq: int) -> Array:
	var events: Array = []
	for event_seq in range(first_seq, last_seq + 1):
		events.append({
			"battleEventSeq": event_seq,
			"type": "battle.event_redacted",
			"redacted": true,
		})
	return events


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
