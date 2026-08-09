extends SceneTree

const Candidates := preload("res://scripts/battle/battle_calcdex_candidates.gd")
const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var revision := _revision()
	var response := _response(revision)
	var normalized := Candidates.normalize_response(response, revision)
	if not bool(normalized.get("success", false)):
		_fail("valid smart candidate response must normalize")
		return
	if normalized["results"][0]["shortLabel"] != "20.0-40.0%":
		_fail("displayed candidate envelope must drive the visible result")
		return
	var wire_response: Dictionary = JSON.parse_string(JSON.stringify(response))
	wire_response["status"] = 200.0
	if not bool(Candidates.normalize_response(wire_response, JSON.parse_string(JSON.stringify(revision))).get("success", false)):
		_fail("smart candidates must accept integral JSON numbers and known HTTP transport metadata")
		return
	var usage_response := response.duplicate(true)
	usage_response["candidates"][0]["candidateId"] = "usage:mew-1630-01"
	usage_response["candidates"][0]["source"] = "public_usage_prior"
	usage_response["candidates"][0]["labelKey"] = "calcdex.preset.public_usage"
	usage_response["candidates"][0]["effectiveInput"] = {
		"nature": "Timid", "item": "Heavy-Duty Boots", "ability": "Flame Body",
		"evs": {"spa": 252, "spd": 4, "spe": 252},
		"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"assumedMoves": ["Quiver Dance", "Bug Buzz", "Flamethrower", "Fiery Dance"],
	}
	usage_response["candidates"][0]["results"][0]["moveSource"] = "public_usage_prior"
	var second_usage_candidate: Dictionary = usage_response["candidates"][0].duplicate(true)
	second_usage_candidate["candidateId"] = "usage:mew-1630-02"
	second_usage_candidate["weight"] = 0.25
	second_usage_candidate["effectiveInput"]["nature"] = "Modest"
	second_usage_candidate["effectiveInput"]["item"] = "Leftovers"
	usage_response["candidates"].append(second_usage_candidate)
	usage_response["ranges"][0]["moveSource"] = "public_usage_prior"
	usage_response["ranges"][0]["extremaCandidateIds"] = ["usage:mew-1630-01"]
	var normalized_usage := Candidates.normalize_response(usage_response, revision)
	if not bool(normalized_usage.get("success", false)) or normalized_usage["candidates"][0]["source"] != "public_usage_prior" or normalized_usage["results"][0]["move"]["source"] != "public_usage_prior":
		_fail("public aggregate usage candidates must normalize without becoming confirmed facts")
		return
	var leaked := response.duplicate(true)
	leaked["candidates"][0]["effectiveInput"]["privateSetId"] = "secret"
	if bool(Candidates.normalize_response(leaked, revision).get("success", false)):
		_fail("unknown effective-input fields must fail closed")
		return
	var invalid_boost := response.duplicate(true)
	invalid_boost["candidates"][0]["effectiveInput"]["boosts"] = {"spa": 7}
	if bool(Candidates.normalize_response(invalid_boost, revision).get("success", false)):
		_fail("manual stat stages outside -6 through +6 must fail closed")
		return

	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot(_selection_snapshot())
	panel.show_default_ability_response("Mew", {
		"success": true,
		"filteredBySpecies": true,
		"abilities": [{"name": "Synchronize", "calcName": "Synchronize"}],
	})
	panel.show_sample_set_catalog_response("Mew", {
		"schemaVersion": 1,
		"libraryRevision": "test-v1",
		"manifestFingerprint": "c".repeat(64),
		"speciesFingerprint": "d".repeat(64),
		"formatId": "gen9nationaldex",
		"source": "pokeaether_curated",
		"species": "Mew",
		"sets": [{
			"id": "defensive-pivot",
			"name": "Defensive Pivot",
			"item": "Heavy-Duty Boots",
			"ability": "Synchronize",
			"nature": "Bold",
			"evs": {"hp": 252, "def": 252, "spd": 4},
			"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 0},
			"teraType": "Ghost",
			"moves": ["Psychic", "U-turn", "Will-O-Wisp", "Roost"],
			"provenance": {"kind": "pokeaether_curated"},
		}],
	})
	await process_frame
	if panel.sample_set_options.size() != 1:
		_fail("the curated sample-set catalog must be available as scenarios")
		return
	panel._apply_sample_set(panel.sample_set_options[0])
	if panel.selected_sample_set_id != "defensive-pivot":
		_fail("selecting a sample set must retain its explicit scenario identity")
		return
	if panel.defender_assumptions.get("item") != "Heavy-Duty Boots" or panel.defender_assumptions.get("ability") != "Synchronize" or panel.defender_assumptions.get("nature") != "Bold":
		_fail("selecting a sample set must fill item, ability, and nature")
		return
	if panel.defender_assumptions.get("evs") != {"hp": 252, "def": 252, "spd": 4} or (panel.defender_assumptions.get("assumedMoves", []) as Array).size() != 4:
		_fail("selecting a sample set must fill EVs and assumed moves")
		return
	if not bool(panel.defender_assumptions.get("replaceMoves", false)):
		_fail("a selected sample set must own its four editable move slots")
		return
	if panel.defender_assumptions.get("ivs") != {"spe": 0}:
		_fail("only non-default IVs should become explicit assumptions")
		return
	if not bool(panel.defender_assumptions.get("exactStats", false)):
		_fail("a selected sample set must be calculated as an exact user scenario")
		return
	panel._on_nature_option_pressed("Modest")
	if panel.selected_sample_set_id != "":
		_fail("editing a selected sample set must turn it into a custom scenario")
		return
	panel._reset_to_current()
	if panel.defender_assumptions.get("nature") != "Hardy" or panel.defender_assumptions.get("evs") != {}:
		_fail("Current must restore a neutral nature and empty EV spread")
		return
	if panel.defender_assumptions.has("replaceMoves") or panel.defender_assumptions.has("assumedMoves"):
		_fail("Current must return move slots to confirmed battle information")
		return
	if panel.defender_assumptions.get("ability") != "Synchronize" or not panel.edited_assumption_fields.is_empty():
		_fail("Current must use the first public species ability without marking it as a manual edit")
		return
	panel.active_selector = "move"
	panel.active_move_slot = 0
	panel._on_selector_result_pressed({"name": "Psychic", "calcName": "Psychic", "type": "psychic", "category": "special"})
	if panel.defender_assumptions.get("assumedMoves") != ["Psychic"] or panel.selected_sample_set_id != "":
		_fail("choosing an opponent move must add it to the current custom scenario")
		return
	if not bool(panel.defender_assumptions.get("replaceMoves", false)):
		_fail("editing an opponent move slot must create an explicit move loadout")
		return
	panel.active_selector = "move"
	panel.active_move_slot = 1
	panel._on_selector_result_pressed({"name": "U-turn", "calcName": "U-turn", "type": "bug", "category": "physical"})
	if panel.defender_assumptions.get("assumedMoves") != ["Psychic", "U-turn"]:
		_fail("opponent move slots must preserve their visible order")
		return
	panel.active_selector = "move"
	panel.active_move_slot = 0
	panel._on_selector_result_pressed({"name": "Aura Sphere", "calcName": "Aura Sphere", "type": "fighting", "category": "special"})
	if panel.defender_assumptions.get("assumedMoves") != ["Aura Sphere", "U-turn"]:
		_fail("choosing a move in a filled slot must replace it")
		return
	panel.active_selector = "move"
	panel.active_move_slot = 0
	panel._on_catalog_assumption_clear_pressed("move")
	if panel.defender_assumptions.get("assumedMoves") != ["U-turn"]:
		_fail("clearing an opponent move slot must remove only that move")
		return
	var known_snapshot := _selection_snapshot()
	known_snapshot["opponentPokemon"][0]["item"] = {"state": "known", "value": "Leftovers"}
	known_snapshot["opponentPokemon"][0]["ability"] = {"state": "known", "value": "Pressure"}
	known_snapshot["opponentPokemon"][0]["boosts"] = {
		"state": "known",
		"value": {"spa": 1, "spe": 1},
		"provenance": {"source": "public_derived", "reasonCode": "TEST_KNOWN"},
	}
	panel.set_knowledge_snapshot(known_snapshot)
	if panel.defender_assumptions.get("item") != "Leftovers" or panel.defender_assumptions.get("ability") != "Pressure":
		_fail("Current must automatically prefer confirmed item and ability values")
		return
	if panel._get_effective_opponent_boosts().get("spa") != 1 or panel._get_effective_opponent_boosts().get("spe") != 1:
		_fail("confirmed opponent stat stages must automatically fill the selectors")
		return
	panel._set_opponent_boost_stage("spa", 2)
	var selected_boosts: Dictionary = panel.defender_assumptions.get("boosts", {})
	if selected_boosts.get("spa") != 2 or selected_boosts.get("spe") != 1 or selected_boosts.size() != 5:
		_fail("editing one stat stage must create a complete explicit opponent boost scenario")
		return
	var reverse_response := response.duplicate(true)
	reverse_response["direction"] = "opponent-to-own"
	panel.active_subtab = "their"
	panel.show_response(reverse_response)
	await process_frame
	if not _has_button_text(panel, "U-turn") or _count_button_text(panel, panel._t("battle.calc.add_move")) != 3:
		_fail("Damage taken must render four directly editable opponent move slots")
		return
	print("PASS battle_calcdex_candidates_check")
	quit(0)


func _revision() -> Dictionary:
	return {"visibilityContractVersion": 3, "snapshotFingerprint": "a".repeat(64), "eventSeq": 4, "batchSeq": 2, "mechanicalRevision": 3, "aggregateRevision": 1, "battleEventSeq": 7}


func _response(revision: Dictionary) -> Dictionary:
	var row := {
		"moveName": "Thunderbolt", "moveSource": "owned_exact", "resultState": "supported",
		"damageDistribution": {"kind": "exact_rolls", "rolls": [20, 40]},
		"minDamage": 20, "maxDamage": 40, "averageDamage": 30.0,
		"minPercent": 20.0, "maxPercent": 40.0, "description": "safe",
		"endOfTurn": {"state": "not_included", "reasonCode": "CALC_END_OF_TURN_NOT_INCLUDED"},
		"warningCodes": [],
	}
	return {
		"success": true, "schemaVersion": 1, "routeRevision": "calc4.4-2026-08-09",
		"safeInputFingerprint": "b".repeat(64), "projectionRevision": revision.duplicate(true),
		"mechanicsManifest": {"contractRevision": "calc0-2026-08-08", "damageCalcVersion": "0.10.0", "showdownVersion": "0.11.10", "formatDataFingerprint": "fd94c49ab26ddf8daff2259dfc2b3857f957e37b166557412c4fe303c87e54b0"},
		"presetRevision": "test-v1", "presetFingerprint": "c".repeat(64),
		"direction": "own-to-opponent", "rangeMode": "likely",
		"attacker": {"pokemonRef": "viewer:public-slot-1", "relation": "viewer", "species": "Pikachu", "level": 50, "active": true, "source": "owned_exact"},
		"defender": {"pokemonRef": "opponent:public-slot-1", "relation": "opponent", "species": "Mew", "level": 50, "active": true, "source": "public_reveal"},
		"candidates": [{
			"candidateId": "curated:fast-special", "labelKey": "calcdex.preset.fast_special",
			"source": "curated_prior", "weight": 0.6, "coverage": 0.6, "pinned": false,
			"effectiveInput": {"nature": "Timid", "evs": {"spa": 252, "spe": 252}, "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}, "assumedMoves": []},
			"explanationKeys": ["calcdex.explain.curated_preset"], "results": [row],
		}],
		"ranges": [{"moveName": "Thunderbolt", "moveSource": "owned_exact", "likelyMinPercent": 20.0, "likelyMaxPercent": 40.0, "fullMinPercent": 10.0, "fullMaxPercent": 50.0, "displayedMinPercent": 20.0, "displayedMaxPercent": 40.0, "likelyCandidateCount": 1, "fullCandidateCount": 1, "extremaCandidateIds": ["curated:fast-special"]}],
		"candidateCoverage": 0.6, "cacheStatus": "miss", "warningCodes": [],
	}


func _selection_snapshot() -> Dictionary:
	return {
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Pikachu"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Mew"}}],
	}


func _has_button_text(node: Node, text: String) -> bool:
	return _count_button_text(node, text) > 0


func _count_button_text(node: Node, text: String) -> int:
	var count := 1 if node is Button and (node as Button).text == text else 0
	for child: Node in node.get_children():
		count += _count_button_text(child, text)
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
