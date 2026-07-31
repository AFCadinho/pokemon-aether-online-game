extends SceneTree

const RealtimeService = preload("res://scripts/services/pvp_battle_realtime_service.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var first_lead_response := {
		"success": true,
		"visibilityContractVersion": 2,
		"viewer": {"role": "participant", "side": "p1"},
		"phase": "waiting_for_opponent",
		"viewerControl": {"phase": "waiting_for_opponent"},
		"battleOptions": {"teamPreview": true},
		"requests": {
			"p1": {"teamPreview": true, "wait": true},
			"p2": {"teamPreview": true},
		},
	}
	_check(
		RealtimeService.is_team_preview_response(first_lead_response),
		"the first accepted lead remains in Team Preview"
	)
	_check(
		not RealtimeService.is_team_preview_completion_update(
			{"type": "pvp.battle_update", "response": first_lead_response},
			"p1"
		),
		"a pending response cannot complete Team Preview"
	)

	var completed_response := {
		"success": true,
		"visibilityContractVersion": 2,
		"viewer": {"role": "participant", "side": "p1"},
		"phase": "rendering_events",
		"viewerControl": {"phase": "rendering_events"},
		# This format capability intentionally remains true after preview.
		"battleOptions": {"teamPreview": true},
		"requests": {
			"p1": {"active": [{"moves": []}]},
			"p2": {"wait": true},
		},
	}
	var actionless_final_batch := {
		"type": "pvp.render_batch",
		"playerId": "p2",
		"eventBatchId": "team-preview-final-1",
		"eventSeqEnd": 10,
		"serverSeq": 20,
		"response": completed_response,
	}
	_check(
		not RealtimeService.is_team_preview_response(completed_response),
		"post-preview phase overrides the persistent format capability"
	)
	_check(
		RealtimeService.is_team_preview_completion_update(actionless_final_batch, "p1"),
		"the first chooser accepts an actionless privacy-v2 final render batch"
	)
	_check(
		not RealtimeService.is_team_preview_completion_update(actionless_final_batch, "p2"),
		"a projection for the other viewer cannot complete Team Preview"
	)
	_check(
		not RealtimeService.is_team_preview_completion_update(
			{"type": "pvp.choice_confirmed", "confirmed": true, "response": first_lead_response},
			"p1"
		),
		"the public Waiting confirmation alone cannot complete Team Preview"
	)
	_check_picker_open_completion_capture(
		actionless_final_batch,
		first_lead_response
	)

	if failures > 0:
		quit(1)
		return
	print("PASS pvp_team_preview_privacy_completion_check")
	quit(0)


func _check_picker_open_completion_capture(
	actionless_final_batch: Dictionary,
	first_lead_response: Dictionary
) -> void:
	# Exercise the actual battle-controller capture boundary without entering the
	# full battle scene. These are the only collaborators used by this method.
	var battle_controller_script: Script = load("res://scripts/battle/battle.gd")
	var party_grid_script: Script = load("res://scripts/battle/battle_ui/party_grid.gd")
	_check(battle_controller_script != null, "the battle controller loads for picker behavior testing")
	_check(party_grid_script != null, "the party grid loads for picker behavior testing")
	if battle_controller_script == null or party_grid_script == null:
		return
	var controller: Variant = battle_controller_script.new()
	var party_grid: Variant = party_grid_script.new()
	controller.player_party_grid = party_grid
	controller.action_flow.set_local_player_id("p1")
	controller.team_preview_lead_selection_active = true
	controller.current_action_view = 2 # ActionView.PARTY
	var wake_slots: Array[int] = []
	party_grid.party_selected.connect(func(slot: int) -> void: wake_slots.append(slot))

	controller.team_preview_lead_selection_active = false
	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(actionless_final_batch),
		"a completion cannot wake an inactive Team Preview"
	)
	controller.team_preview_lead_selection_active = true
	controller.current_action_view = 0 # ActionView.NONE
	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(actionless_final_batch),
		"a completion cannot wake a picker that is no longer open"
	)
	controller.current_action_view = 2 # ActionView.PARTY

	var correlated_batch := actionless_final_batch.duplicate(true)
	correlated_batch["requestId"] = "local-action-request"
	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(correlated_batch),
		"a correlated local action response remains owned by its action waiter"
	)
	_check(
		controller.pvp_pending_team_preview_completion.is_empty() and wake_slots.is_empty(),
		"a correlated response cannot mutate or wake the picker recovery state"
	)

	var wrong_viewer_batch := actionless_final_batch.duplicate(true)
	wrong_viewer_batch["response"]["viewer"]["side"] = "p2"
	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(wrong_viewer_batch),
		"a projection for another viewer cannot wake the local picker"
	)

	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open({
			"type": "pvp.battle_update",
			"response": first_lead_response,
		}),
		"a still-pending Team Preview response cannot wake the picker"
	)
	_check(
		controller._capture_pvp_team_preview_completion_while_picker_open(actionless_final_batch),
		"an actionless authoritative completion wakes the open picker"
	)
	_check(
		wake_slots == [0]
			and controller.pvp_realtime_activity_seq == 1
			and str(controller.pvp_pending_team_preview_completion.get("phase", "")) == "rendering_events",
		"picker wake stores one completion and emits exactly one synthetic selection"
	)

	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(actionless_final_batch),
		"an identical retransmit remains queueable for normal dedupe and ACK handling"
	)
	_check(
		wake_slots == [0]
			and controller.pvp_realtime_activity_seq == 1
			and int(controller.pvp_pending_team_preview_completion.get("pvpServerSeq", 0)) == 20,
		"an identical retransmit cannot emit, advance, or replace the first picker completion"
	)

	var newer_completion := actionless_final_batch.duplicate(true)
	newer_completion["eventBatchId"] = "team-preview-final-2"
	newer_completion["eventSeqEnd"] = 11
	newer_completion["serverSeq"] = 21
	newer_completion["response"]["eventSeq"] = 11
	newer_completion["response"]["batchSeq"] = 2
	_check(
		not controller._capture_pvp_team_preview_completion_while_picker_open(newer_completion),
		"a distinct newer completion remains queueable for rendering and ACK"
	)
	_check(
		wake_slots == [0]
			and controller.pvp_realtime_activity_seq == 1
			and int(controller.pvp_pending_team_preview_completion.get("pvpServerSeq", 0)) == 20,
		"a newer completion cannot overwrite pending state or wake the picker twice"
	)

	party_grid.free()
	controller.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
