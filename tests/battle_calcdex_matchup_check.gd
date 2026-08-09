extends SceneTree

const Matchup := preload("res://scripts/battle/battle_calcdex_matchup.gd")
const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var revision := _revision()
	var response := _response(revision)
	var normalized := Matchup.normalize_response(response, revision)
	_assert(bool(normalized.get("success", false)), "valid matchup must normalize")
	_assert(str(normalized["results"][0]["move"]["source"]) == "public_reveal", "move provenance must survive")
	var wire_response: Dictionary = JSON.parse_string(JSON.stringify(response))
	wire_response["status"] = 200.0
	_assert(
		bool(Matchup.normalize_response(wire_response, JSON.parse_string(JSON.stringify(revision))).get("success", false)),
		"matchup accepts integral JSON numbers and known HTTP transport metadata"
	)

	var leaked := response.duplicate(true)
	leaked["privateTeam"] = {"moves": ["Secret Move"]}
	_assert(not bool(Matchup.normalize_response(leaked, revision).get("success", false)), "unknown top-level fields must fail closed")
	var stale := revision.duplicate(true)
	stale["eventSeq"] += 1
	_assert(not bool(Matchup.normalize_response(response, stale).get("success", false)), "stale result must fail closed")

	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot(_selection_snapshot())
	var selection := panel.get_matchup_selection()
	_assert(selection == {
		"direction": "own-to-opponent",
		"attackerRef": "viewer:public-slot-2",
		"defenderRef": "opponent:public-slot-1",
	}, "active public references must be selected by default")
	panel._on_their_damage_tab_pressed()
	selection = panel.get_matchup_selection()
	_assert(selection["direction"] == "opponent-to-own", "reverse direction must be available")
	_assert(selection["attackerRef"] == "opponent:public-slot-1", "reverse attacker must stay public opponent")
	_assert(selection["defenderRef"] == "viewer:public-slot-2", "reverse defender must stay owned")
	var wrong_direction := response.duplicate(true)
	wrong_direction["direction"] = "own-to-opponent"
	panel.show_response(wrong_direction)
	_assert(panel.last_response.is_empty(), "reverse tab must reject a stale own-damage response")
	_assert(panel.last_error != "", "direction mismatch must render an explicit safe error")
	panel.show_response(response)
	_assert(not panel.last_response.is_empty(), "reverse tab must accept a matching damage-taken response")
	await process_frame
	var selectors := _collect_option_buttons(content)
	_assert(selectors.size() >= 2, "the matchup profile selectors must render")
	if selectors.size() >= 2:
		_assert(
			str(selectors[0].get_item_metadata(selectors[0].selected)).begins_with("viewer:"),
			"the viewer must remain on the left in damage taken",
		)
		_assert(
			str(selectors[1].get_item_metadata(selectors[1].selected)).begins_with("opponent:"),
			"the opponent must remain on the right in damage taken",
		)
	_assert(_has_line_edit_text(content, "Thunderbolt"), "damage taken must keep the opponent move directly editable")
	_assert(panel.result_summary_panels.size() == 1, "an editable damage-taken move must retain its calculation summary")
	var disclosure_metadata: Dictionary = panel.result_disclosure_buttons.values()[0] if not panel.result_disclosure_buttons.is_empty() else {}
	_assert(bool(disclosure_metadata.get("compact", false)), "damage-taken summaries must use a separate compact disclosure beside the move input")
	print("PASS battle_calcdex_matchup_check")
	quit(0)


func _revision() -> Dictionary:
	return {
		"visibilityContractVersion": 3,
		"snapshotFingerprint": "a".repeat(64),
		"eventSeq": 4,
		"batchSeq": 2,
		"mechanicalRevision": 3,
		"aggregateRevision": 1,
		"battleEventSeq": 7,
	}


func _response(revision: Dictionary) -> Dictionary:
	return {
		"success": true,
		"schemaVersion": 1,
		"routeRevision": "calc3.5-2026-08-09",
		"safeInputFingerprint": "b".repeat(64),
		"projectionRevision": revision.duplicate(true),
		"mechanicsManifest": {
			"contractRevision": "calc0-2026-08-08",
			"damageCalcVersion": "0.10.0",
			"showdownVersion": "0.11.10",
			"formatDataFingerprint": "fd94c49ab26ddf8daff2259dfc2b3857f957e37b166557412c4fe303c87e54b0",
		},
		"direction": "opponent-to-own",
		"attacker": {"pokemonRef": "opponent:public-slot-1", "relation": "opponent", "species": "Pikachu", "level": 50, "active": true, "source": "public_reveal"},
		"defender": {"pokemonRef": "viewer:public-slot-2", "relation": "viewer", "species": "Mew", "level": 50, "active": true, "source": "owned_exact"},
		"results": [{
			"moveName": "Thunderbolt",
			"moveSource": "public_reveal",
			"resultState": "supported",
			"damageDistribution": {"kind": "exact_rolls", "rolls": [42, 43]},
			"minDamage": 42,
			"maxDamage": 43,
			"averageDamage": 42.5,
			"minPercent": 30.0,
			"maxPercent": 31.0,
			"description": "safe",
			"endOfTurn": {"state": "not_included", "reasonCode": "CALC_END_OF_TURN_NOT_INCLUDED"},
			"warningCodes": [],
		}],
		"warningCodes": ["CALC_SCENARIO_NATURE"],
	}


func _selection_snapshot() -> Dictionary:
	return {
		"viewerPokemon": [
			{"pokemonRef": "viewer:public-slot-1", "active": false, "fainted": false, "identity": {"state": "known", "value": "Bulbasaur"}},
			{"pokemonRef": "viewer:public-slot-2", "active": true, "fainted": false, "identity": {"state": "known", "value": "Mew"}},
		],
		"opponentPokemon": [
			{"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Pikachu"}},
		],
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _collect_option_buttons(node: Node) -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	if node is OptionButton:
		result.append(node as OptionButton)
	for child: Node in node.get_children():
		result.append_array(_collect_option_buttons(child))
	return result


func _has_line_edit_text(node: Node, expected: String) -> bool:
	if node is LineEdit and (node as LineEdit).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_line_edit_text(child, expected):
			return true
	return false
