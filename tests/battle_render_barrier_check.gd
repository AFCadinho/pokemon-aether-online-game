extends SceneTree

const ACTION_FLOW_PATH := "res://scripts/battle/battle_action_flow.gd"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BattleEventQueueScript := preload("res://scripts/battle/battle_event_queue.gd")

var failed := false


func _init() -> void:
	var action_flow_source := FileAccess.get_file_as_string(ACTION_FLOW_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := action_flow_source.find("func apply_response(")
	var apply_next_index := action_flow_source.find("\nfunc ", apply_index + 1)
	var apply_source := action_flow_source.substr(apply_index, apply_next_index - apply_index)

	_check(apply_source.contains("load_battle_state: bool = true"), "action flow exposes an explicit canonical-state render barrier")
	_check(apply_source.contains("if load_battle_state:\n\t\tbattle_state.load_from_api_response"), "deferred responses do not mutate visible BattleState")
	_check(apply_source.find("ability_response_handler.call(display_response)") < apply_source.find("if load_battle_state:"), "public response metadata remains available while state is deferred")
	_check(battle_source.contains("_should_defer_pvp_canonical_state_until_render(display_response)"), "PvP responses activate the canonical-state render barrier")
	_check(battle_source.contains("response[\"requests\"] = battle_state.requests.duplicate(true)"), "terminal restore retains the event-applied winner presentation")
	_check(
		battle_source.contains("_acknowledge_already_rendered_pvp_batch(queue_response, source)"),
		"an already rendered duplicate retries its idempotent render acknowledgement"
	)
	var duplicate_ack_index := battle_source.find(
		"_acknowledge_already_rendered_pvp_batch(queue_response, source)"
	)
	var duplicate_process_index := battle_source.find(
		"_process_pvp_choice_queue_entry(queue_response, source"
	)
	_check(
		duplicate_ack_index >= 0 and duplicate_ack_index < duplicate_process_index,
		"duplicate ACK is sent before any force-switch phase-release wait"
	)
	var release_index := battle_source.find("func _release_pvp_presentation_hold_from_ack_barrier(")
	var release_next_index := battle_source.find("\nfunc ", release_index + 1)
	var release_source := battle_source.substr(release_index, release_next_index - release_index)
	_check(
		release_source.contains("if not pvp_presentation_acknowledgements_authoritative:"),
		"legacy presentation schedules retain their deterministic fallback hold"
	)
	_check(
		release_source.contains('if not bool(message.get("presentationReleased", false)):'),
		"a phase update cannot release input unless the server timer release succeeded"
	)
	_check(
		battle_source.contains("if releases_presentation_fence:")
		and battle_source.contains("_release_pvp_presentation_hold_from_ack_barrier(message)"),
		"the shared render barrier releases the local presentation hold"
	)
	_check(
		battle_source.contains("_try_open_pvp_local_prechoice_window.call_deferred(completion.duplicate(true))"),
		"local controls may pre-open only after the completed render batch leaves the queue"
	)
	_check(
		battle_source.contains("pvp_prechoice_buffer.open_window(")
		and battle_source.contains("pvp_pending_presentation_fence,"),
		"prechoice remains correlated to the private decision and pending render fence"
	)
	_check(
		battle_source.contains("_submit_pvp_buffered_prechoice.call_deferred(buffered_choice, phase)"),
		"a buffered choice is submitted only by the authoritative phase release"
	)
	_check(
		battle_source.contains("pvp_prechoice_buffer.reset()\n\t\tpvp_idle_wait_recovery_active = true"),
		"resynchronization discards an unsubmitted local prechoice"
	)
	_check_duplicate_batch_retries_until_render_cursor_advances()
	quit(1 if failed else 0)

func _check_duplicate_batch_retries_until_render_cursor_advances() -> void:
	var queue = BattleEventQueueScript.new()
	var response := {
		"eventSeq": 161,
		"batchSeq": 30,
		"eventBatchId": "volt-switch-ko:30",
		"phase": "rendering_events",
		"nextPhase": "awaiting_force_switch",
		"state": {"turn": 20},
		"events": [{"type": "switch", "to": "Kingambit"}],
	}

	var first: Dictionary = queue.enqueue_response(response, "first")
	var duplicate: Dictionary = queue.enqueue_response(response, "duplicate")
	_check(not bool(first.get("skip_render", false)), "first batch delivery remains renderable")
	_check(bool(duplicate.get("skip_render", false)), "duplicate delivery starts as a skip candidate")
	_check(
		not queue.should_skip_duplicate_render(response, true),
		"duplicate is promoted to a render retry while its cursor is still unrendered"
	)

	var context: Dictionary = queue.begin_render_batch(response, "first")
	queue.complete_render_batch(context, true)
	_check_equal(queue.last_rendered_seq, 161, "successful first render advances the batch cursor")
	_check(
		queue.should_skip_duplicate_render(response, true),
		"duplicate can be skipped only after its render cursor is complete"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
