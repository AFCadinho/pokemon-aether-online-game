extends Node

const HttpFlow := preload("res://scripts/battle/battle_http_flow.gd")
const State := preload("res://scripts/battle/battle_state.gd")
const ActionFlow := preload("res://scripts/battle/battle_action_flow.gd")
const BattleScript := preload("res://scripts/battle/battle.gd")

var failed := false

class FakeActionFlow extends ActionFlow:
	var next_response: Dictionary = {}
	var recovery_response: Dictionary = {}
	var recovery_count := 0
	var submitted_count := 0
	var npc_responses: Array[Dictionary] = []
	var npc_submitted_count := 0

	func send_player_choice_and_resolve(_type: String, _slot: int, _mega := false, _since := -1, _z := false) -> Dictionary:
		submitted_count += 1
		return next_response.duplicate(true)

	func recover_http_response(since_event_seq: int) -> Dictionary:
		recovery_count += 1
		return await accept_http_response(recovery_response, since_event_seq, false)

	func send_npc_choice(_player_id: String = "p2", _since := -1) -> Dictionary:
		npc_submitted_count += 1
		if npc_responses.is_empty():
			return {"success": false}
		return npc_responses.pop_front()


class FakeNpcBattle extends BattleScript:
	var rendered_sequences: Array[int] = []
	var recovery_prompts := 0
	var moves_shown := false

	func _wait_non_pvp_recovery_retry(_attempt: int) -> void:
		pass

	func _set_battle_input_locked(locked: bool) -> void:
		battle_input_locked = locked

	func _show_non_pvp_opponent_force_switch_wait() -> void:
		recovery_prompts += 1

	func _show_moves() -> void:
		moves_shown = true

	func _show_force_switch_if_needed() -> bool:
		return _local_player_needs_force_switch_ui()

	func _capture_ordered_response_display_species() -> void:
		pass

	func _clear_ordered_response_display_species() -> void:
		pass

	func _hold_opponent_response_message() -> void:
		pass

	func _render_opponent_response(response: Dictionary, _keys: Dictionary = {}, _pending: Array = [], _suppress := false, _suppress_win := false) -> void:
		var events: Array = _filter_incremental_non_pvp_response_events(response)
		battle_state.apply_event_conditions(events)
		last_rendered_event_seq = int(response.get("eventSeq", last_rendered_event_seq))
		action_flow.restore_http_response(response, last_rendered_event_seq)
		rendered_sequences.append(last_rendered_event_seq)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_public_force_switch_contract()
	await _check_damage_heal_and_delayed_response()
	await _check_missing_events_are_recovered_without_resubmitting()
	_check_full_heal_snapshot_overrides_presentation_memory()
	_check_mixed_projection_order()
	_check_battle_uses_public_control()
	await _check_hazard_chain_and_pivot_wait()
	await _check_recovery_budget_and_half_resolved_turn()
	if not failed:
		print("PASS: HTTP battle ordering, HP, forced-switch chains and bounded recovery")
	get_tree().quit(1 if failed else 0)


func _check_public_force_switch_contract() -> void:
	var response := _snapshot(5, 0)
	response["requests"]["p2"]["wait"] = true
	response["viewerControl"] = {
		"ownActionRequired": false, "ownForceSwitchRequired": false,
		"opponentActionRequired": true, "opponentForceSwitchRequired": true,
	}
	_check(HttpFlow.public_force_switch(response["viewerControl"], false), "masked request still requires NPC replacement")
	_check(HttpFlow.needs_resolution(response), "player cannot choose while NPC replacement is pending")
	response["viewerControl"]["ownActionRequired"] = true
	response["viewerControl"]["ownForceSwitchRequired"] = true
	response["viewerControl"]["opponentActionRequired"] = false
	_check(not HttpFlow.needs_resolution(response), "ordered pivot returns control to the human first")
	_check(not HttpFlow.public_force_switch(response["viewerControl"], false), "a delayed opponent switch is not actionable")
	response["state"]["ended"] = true
	_check(not HttpFlow.needs_resolution(response), "final hazard KO requires no NPC continuation")


func _check_damage_heal_and_delayed_response() -> void:
	var state := State.new()
	state.load_from_api_response(_snapshot(1, 100))
	var flow := FakeActionFlow.new()
	flow.setup(state, null)
	var damage := _hp_event("damage", 100, 30)
	var heal := _hp_event("heal", 30, 50)
	flow.next_response = _snapshot(3, 50, [damage, heal])
	var response: Dictionary = await flow.submit_player_choice_and_resolve("move", 1, false, 1)
	_check(state.get_active_pokemon_current_hp("p2") == 100, "HP stays at the pre-animation value")
	state.apply_event_conditions([damage])
	_check(state.get_active_pokemon_current_hp("p2") == 30, "damage is visible before healing")
	state.apply_event_conditions([heal])
	flow.restore_http_response(response, 3)
	_check(state.get_active_pokemon_current_hp("p2") == 50, "post-render HP equals the server snapshot")
	flow.next_response = _snapshot(2, 30, [damage])
	response = await flow.submit_player_choice_and_resolve("move", 1, false, 3)
	_check(response.get("events", []).is_empty(), "late response does not replay old damage")
	_check(state.get_active_pokemon_current_hp("p2") == 50, "late response cannot rewind HP")
	flow.next_response = _snapshot(3, 50, [damage, heal])
	response = await flow.submit_player_choice_and_resolve("move", 1, false, 3)
	_check(state.get_active_pokemon_current_hp("p2") == 50, "duplicate full history cannot rewind HP")


func _check_missing_events_are_recovered_without_resubmitting() -> void:
	var state := State.new()
	state.load_from_api_response(_snapshot(1, 100))
	var flow := FakeActionFlow.new()
	flow.setup(state, null)
	flow.next_response = _snapshot(3, 30, [_hp_event("damage", 60, 30)])
	flow.recovery_response = _snapshot(3, 30, [_hp_event("damage", 100, 60), _hp_event("damage", 60, 30)])
	var response: Dictionary = await flow.submit_player_choice_and_resolve("move", 1, false, 1)
	_check(flow.submitted_count == 1 and flow.recovery_count == 1, "gap recovery reads state without replaying the human action")
	_check(response["events"].size() == 2, "recovery returns both missing damage events")
	flow.recovery_response = flow.next_response
	response = await flow.accept_http_response(flow.next_response, 1)
	_check(not bool(response.get("success", false)), "unrecoverable gap refuses to advance the cursor")
	_check(flow.http_recovery_required, "unrecoverable gap offers further recovery")


func _check_full_heal_snapshot_overrides_presentation_memory() -> void:
	var state := State.new()
	state.load_from_api_response(_snapshot(1, 20))
	state.load_from_api_response(_snapshot(2, 100), false, 2, true)
	_check(state.get_active_pokemon_current_hp("p2") == 100, "canonical full healing is not overwritten by old damage memory")


func _check_mixed_projection_order() -> void:
	var flow := HttpFlow.new()
	var legacy := _snapshot(5, 40)
	legacy["mechanicalRevision"] = 8
	legacy["snapshotFingerprint"] = "legacy"
	legacy["decisions"]["p2"] = {"decisionGeneration": 9}
	flow.remember(legacy)
	var participant := _snapshot(5, 40)
	participant["mechanicalRevision"] = 8
	participant["snapshotFingerprint"] = "participant"
	_check(not flow.is_stale(participant), "privacy masking is not mistaken for older mechanical state")
	participant["mechanicalRevision"] = 7
	_check(flow.is_stale(participant), "older same-event mechanical revision is still rejected")


func _check_battle_uses_public_control() -> void:
	var script: Script = load("res://scripts/battle/battle.gd")
	_check(script != null and script.can_instantiate(), "battle scene script compiles")
	if script == null or not script.can_instantiate():
		return
	var battle = script.new()
	battle.battle_state.viewer_control = {
		"ownActionRequired": false, "ownForceSwitchRequired": false,
		"opponentActionRequired": true, "opponentForceSwitchRequired": true,
	}
	battle.battle_state.requests = {"p2": {"wait": true}}
	_check(battle._opponent_player_needs_force_switch_ui(), "actual non-PvP UI honors the masked forced-switch contract")
	var catchup_events := [
		{"type": "move", "actor": "p1a: Charizard", "move": "Protect"},
		{"type": "turn", "turn": 3},
		{"type": "mega", "target": "p1a: Charizard"},
		{"type": "move", "actor": "p1a: Charizard", "move": "Flamethrower"},
	]
	_check(battle._order_form_change_events_before_moves(catchup_events) == catchup_events, "catch-up does not pull next-turn Mega Evolution ahead of the previous move")
	battle.free()


func _check_hazard_chain_and_pivot_wait() -> void:
	var battle := FakeNpcBattle.new()
	var flow := FakeActionFlow.new()
	battle.action_flow = flow
	battle.battle_state.load_from_api_response(_snapshot(1, 0))
	battle.last_rendered_event_seq = 1
	flow.setup(battle.battle_state, null)
	var hazard := _snapshot(2, 0, [_hp_event("damage", 20, 0)])
	hazard["viewerControl"] = {"ownActionRequired": false, "opponentActionRequired": true, "opponentForceSwitchRequired": true}
	var terminal := _snapshot(3, 0, [_hp_event("damage", 20, 0)])
	terminal["state"]["ended"] = true
	flow.npc_responses = [hazard, terminal]
	_check(await battle._submit_npc_choice_and_render(), "hazard chain reaches terminal response")
	_check(flow.npc_submitted_count == 2, "last hazard KO does not request a nonexistent replacement")
	_check(battle.rendered_sequences == [2, 3], "replacement responses render in sequence")
	battle.free()

	battle = FakeNpcBattle.new()
	flow = FakeActionFlow.new()
	battle.action_flow = flow
	battle.battle_state.load_from_api_response(_snapshot(1, 0))
	battle.last_rendered_event_seq = 1
	flow.setup(battle.battle_state, null)
	var pivot := _snapshot(1, 0)
	pivot["viewerControl"] = {"ownActionRequired": true, "ownForceSwitchRequired": true, "opponentActionRequired": false, "opponentForceSwitchRequired": true}
	pivot["npcChoiceSkipped"] = true
	flow.npc_responses = [pivot]
	_check(await battle._submit_npc_choice_and_render(), "ordered pivot skip returns to player control")
	_check(flow.npc_submitted_count == 1, "NPC skip does not consume the hazard-chain retry budget")
	_check(battle._local_player_needs_force_switch_ui(), "player replacement stays selectable after NPC no-op")
	battle.free()


func _check_recovery_budget_and_half_resolved_turn() -> void:
	var battle := FakeNpcBattle.new()
	var flow := FakeActionFlow.new()
	battle.action_flow = flow
	battle.battle_state.load_from_api_response(_snapshot(1, 100))
	battle.last_rendered_event_seq = 1
	flow.setup(battle.battle_state, null)
	flow.recovery_response = {"success": false}
	await battle._resolve_non_pvp_opponent_force_switch_wait()
	_check(flow.recovery_count == 3, "recovery stops after three attempts")
	_check(battle.non_pvp_recovery_failed and battle.recovery_prompts == 1, "failed recovery offers a manual retry")
	_check(flow.submitted_count == 0, "failed recovery never repeats the human choice")
	battle.free()

	battle = FakeNpcBattle.new()
	flow = FakeActionFlow.new()
	battle.action_flow = flow
	battle.battle_state.load_from_api_response(_snapshot(1, 100))
	battle.last_rendered_event_seq = 1
	flow.setup(battle.battle_state, null)
	var pending := _snapshot(1, 100)
	pending["viewerControl"] = {"ownActionRequired": false, "opponentActionRequired": true}
	flow.recovery_response = pending
	flow.npc_responses = [_snapshot(2, 40, [_hp_event("damage", 100, 40)])]
	await battle._resolve_non_pvp_opponent_force_switch_wait()
	_check(flow.npc_submitted_count == 1 and flow.submitted_count == 0, "half-resolved turn resumes only the NPC decision")
	_check(battle.moves_shown and not battle.battle_input_locked, "successful recovery reopens the next player decision")
	battle.free()


func _snapshot(seq: int, hp: int, events: Array = []) -> Dictionary:
	return {
		"success": true, "battleId": "http-flow-test", "eventSeq": seq,
		"state": {"turn": 2, "ended": false}, "events": events,
		"decisions": {"p1": {"status": "ACTIVE", "decisionGeneration": 1}},
		"requests": {"p2": {"side": {"pokemon": [{
			"ident": "p2: Pikachu", "species": "Pikachu", "active": true,
			"condition": "%d/100" % hp, "hp": hp, "maxHp": 100,
			"metadataSlot": 1, "pokemonKey": "p2:slot:1",
		}]}}},
	}


func _hp_event(type: String, before: int, after: int) -> Dictionary:
	return {
		"type": type, "target": "p2a: Pikachu", "pokemonKey": "p2:slot:1",
		"previousHp": before, "hp": after, "maxHp": 100,
		"previousCondition": "%d/100" % before, "condition": "%d/100" % after,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
