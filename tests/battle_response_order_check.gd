extends SceneTree

const BattleResponseOrderScript := preload("res://scripts/battle/battle_response_order.gd")
const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_same_turn_flip_turn_projection_cannot_replace_faint()
	_check_canonical_restore_does_not_replay_full_switch_history()
	_check_deferred_rewind_does_not_mutate_canonical_response()
	_check_newer_same_event_request_revision_is_retained()
	_check_battle_controller_uses_order_guard()
	quit(1 if failed else 0)


func _check_same_turn_flip_turn_projection_cannot_replace_faint() -> void:
	var order = BattleResponseOrderScript.new()
	var flip_turn_response := _response(
		12,
		4,
		2,
		99,
		"Alomomola",
		false,
		true,
		[{"type": "switch", "to": "Cinderace"}]
	)
	var cinderace_faint_response := _response(
		18,
		6,
		2,
		37,
		"Cinderace",
		true,
		true,
		[
			{"type": "move", "move": "Earthquake", "target": "p2a: Cinderace"},
			{"type": "faint", "target": "p2a: Cinderace"},
		]
	)

	_check(order.remember(flip_turn_response), "initial Flip Turn projection is remembered")
	_check(order.remember(cinderace_faint_response), "newer faint projection is remembered")
	_check(order.is_stale(flip_turn_response), "older mechanical projection stays stale despite a higher transport sequence")

	var rendered := order.merge_latest_projection_with_events(flip_turn_response)
	var active := _active_pokemon(rendered)
	_check_equal(str(active.get("species", "")), "Cinderace", "old batch renders on latest active identity")
	_check_equal(bool(active.get("fainted", false)), true, "latest faint remains canonical during old batch render")
	_check_equal(str(rendered.get("phase", "")), "awaiting_force_switch", "newest control phase remains canonical")
	_check_equal(
		str(((rendered.get("events", []) as Array)[0] as Dictionary).get("to", "")),
		"Cinderace",
		"old batch event payload remains renderable"
	)
	var render_batch := order.render_batch_projection_for(rendered)
	_check_equal(str(render_batch.get("phase", "")), "rendering_events", "render ACK keeps the event batch phase")
	_check_equal(str(render_batch.get("nextPhase", "")), "turn_open", "render ACK keeps the event batch next phase")

	var restored := order.latest_projection_for(flip_turn_response)
	active = _active_pokemon(restored)
	_check_equal(str(active.get("species", "")), "Cinderace", "restore selects newest canonical response")
	_check_equal(bool(active.get("fainted", false)), true, "restore cannot revive Alomomola")


func _check_canonical_restore_does_not_replay_full_switch_history() -> void:
	var order = BattleResponseOrderScript.new()
	var response := _response(
		18,
		6,
		2,
		42,
		"Cinderace",
		true,
		true,
		[
			{
				"type": "switch", "pokemon": "p2a: Alomomola", "condition": "100/100",
				"pokemonKey": "p2:slot:1", "metadataSlot": 1,
			},
			{
				"type": "switch", "pokemon": "p2a: Cinderace", "condition": "100/100",
				"pokemonKey": "p2:slot:2", "metadataSlot": 2,
			},
			{
				"type": "faint", "target": "p2a: Cinderace", "condition": "0 fnt",
				"pokemonKey": "p2:slot:2", "metadataSlot": 2,
			},
		]
	)
	var team: Array = (((response["requests"] as Dictionary)["p2"] as Dictionary)["side"] as Dictionary)["pokemon"]
	(team[0] as Dictionary)["pokemonKey"] = "p2:slot:2"
	(team[0] as Dictionary)["metadataSlot"] = 2
	(team[1] as Dictionary)["pokemonKey"] = "p2:slot:1"
	(team[1] as Dictionary)["metadataSlot"] = 1

	_check(order.remember(response), "full-history canonical projection is remembered")
	var snapshot: Dictionary = order.latest_canonical_snapshot_for(response)
	_check_equal((snapshot.get("events", []) as Array).size(), 0, "canonical restore strips historical events")
	_check_equal((snapshot.get("eventBatches", []) as Array).size(), 0, "canonical restore strips historical batches")

	var state = BattleStateScript.new()
	state.load_from_api_response(snapshot, false)
	var restored_active := state.get_active_player_pokemon("p2")
	_check_equal(str(restored_active.get("species", "")), "Cinderace", "canonical fainted active remains Cinderace")
	_check_equal(bool(restored_active.get("fainted", false)), true, "canonical Cinderace remains fainted")
	_check_equal(bool((state.get_player_team("p2")[1] as Dictionary).get("active", true)), false, "old Alomomola switch is not replayed")


func _check_deferred_rewind_does_not_mutate_canonical_response() -> void:
	var response := _response(
		24,
		8,
		6,
		51,
		"Cinderace",
		true,
		true,
		[
			{
				"type": "damage", "target": "p2a: Cinderace",
				"previousCondition": "100/100", "condition": "0 fnt",
				"previousHp": 100, "hp": 0, "maxHp": 100,
				"pokemonKey": "p2:slot:1", "metadataSlot": 1,
				"targetRef": {"pokemonKey": "p2:slot:1", "metadataSlot": 1},
			},
			{
				"type": "faint", "target": "p2a: Cinderace", "condition": "0 fnt",
				"pokemonKey": "p2:slot:1", "metadataSlot": 1,
				"targetRef": {"pokemonKey": "p2:slot:1", "metadataSlot": 1},
			},
		]
	)
	var team: Array = (((response["requests"] as Dictionary)["p2"] as Dictionary)["side"] as Dictionary)["pokemon"]
	(team[0] as Dictionary)["pokemonKey"] = "p2:slot:1"
	(team[0] as Dictionary)["metadataSlot"] = 1
	(team[1] as Dictionary)["pokemonKey"] = "p2:slot:2"
	(team[1] as Dictionary)["metadataSlot"] = 2

	var presentation_state = BattleStateScript.new()
	presentation_state.load_from_api_response(response, false)
	var rewound_active := presentation_state.get_active_player_pokemon("p2")
	_check_equal(str(rewound_active.get("condition", "")), "100/100", "presentation state rewinds the deferred faint before animation")

	var canonical_active := _active_pokemon(response)
	_check_equal(str(canonical_active.get("condition", "")), "0 fnt", "deferred rewind cannot mutate the response condition")
	_check_equal(bool(canonical_active.get("fainted", false)), true, "deferred rewind cannot revive the canonical response")

	var order = BattleResponseOrderScript.new()
	_check(order.remember(response), "unmodified canonical response is remembered after presentation rewind")
	var restored_state = BattleStateScript.new()
	restored_state.load_from_api_response(order.latest_canonical_snapshot_for(response), false)
	_check_equal(bool(restored_state.get_active_player_pokemon("p2").get("fainted", false)), true, "post-animation restore keeps the canonical faint")


func _check_newer_same_event_request_revision_is_retained() -> void:
	var order = BattleResponseOrderScript.new()
	var scheduled := _response(18, 6, 2, 40, "Cinderace", true, true, [])
	var actionable := _response(18, 6, 2, 41, "Cinderace", true, true, [])
	(scheduled["timerState"] as Dictionary)["timerRevision"] = 8
	(actionable["timerState"] as Dictionary)["timerRevision"] = 9
	_check(order.remember(scheduled), "scheduled forced switch projection is remembered")
	_check(order.remember(actionable), "newer timer revision advances same-event projection")
	_check(order.is_stale(scheduled), "older same-event request revision is stale")


func _check_battle_controller_uses_order_guard() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_start := source.find("func _apply_api_response(")
	var apply_end := source.find("\nfunc ", apply_start + 1)
	var apply_source := source.substr(apply_start, apply_end - apply_start)
	_check(
		apply_source.find("pvp_response_order.is_stale(display_response)")
			< apply_source.find("action_flow.apply_response(response, apply_event_conditions)"),
		"stale canonical projection is rejected before mutating BattleState"
	)
	_check(
		source.contains("pvp_response_order.merge_latest_projection_with_events(display_response)"),
		"queued event payloads are combined with the newest canonical projection"
	)
	_check(
		source.contains("pvp_response_order.latest_canonical_snapshot_for(response)"),
		"post-animation restore selects a newest event-free canonical snapshot"
	)
	_check(
		source.contains("pvp_response_order.render_batch_projection_for(response)"),
		"render acknowledgements retain their event-batch phase metadata"
	)


func _response(
	event_seq: int,
	batch_seq: int,
	turn: int,
	server_seq: int,
	active_species: String,
	active_fainted: bool,
	force_switch: bool,
	events: Array
) -> Dictionary:
	var bench_species := "Cinderace" if active_species == "Alomomola" else "Alomomola"
	return {
		"success": true,
		"battleId": "flip-turn-force-switch",
		"eventSeq": event_seq,
		"batchSeq": batch_seq,
		"serverSeq": server_seq,
		"phase": "awaiting_force_switch",
		"nextPhase": "awaiting_force_switch",
		"state": {"turn": turn, "ended": false},
		"timerState": {"timerRevision": 1},
		"requests": {
			"p2": {
				"forceSwitch": [force_switch],
				"side": {
					"pokemon": [
						{
							"ident": "p2: %s" % active_species,
							"species": active_species,
							"active": true,
							"fainted": active_fainted,
							"condition": "0 fnt" if active_fainted else "100/100",
						},
						{
							"ident": "p2: %s" % bench_species,
							"species": bench_species,
							"active": false,
							"fainted": false,
							"condition": "100/100",
						},
					],
				},
			},
		},
		"events": events,
		"eventBatches": [{
			"eventBatchId": "batch:%d" % batch_seq,
			"batchSeq": batch_seq,
			"eventSeqEnd": event_seq,
			"turn": turn,
			"phase": "rendering_events",
			"nextPhase": "turn_open",
		}],
	}


func _active_pokemon(response: Dictionary) -> Dictionary:
	var team: Array = (((response.get("requests", {}) as Dictionary).get("p2", {}) as Dictionary).get("side", {}) as Dictionary).get("pokemon", [])
	for pokemon_value: Variant in team:
		if pokemon_value is Dictionary and bool((pokemon_value as Dictionary).get("active", false)):
			return pokemon_value as Dictionary
	return {}


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
