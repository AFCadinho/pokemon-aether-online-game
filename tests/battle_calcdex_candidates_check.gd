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
		"status": "brn",
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
	if normalized_usage["candidates"][0]["effectiveInput"].get("status") != "brn":
		_fail("A supported manual status must survive smart-candidate normalization")
		return
	var invalid_status := usage_response.duplicate(true)
	invalid_status["candidates"][0]["effectiveInput"]["status"] = "burned"
	if bool(Candidates.normalize_response(invalid_status, revision).get("success", false)):
		_fail("Unknown status identifiers must fail closed")
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
	panel.show_response(response)
	await process_frame
	var condition_snapshot := _selection_snapshot()
	condition_snapshot["field"]["effects"] = [
		{"effectId": "Rain Dance", "scope": "field"},
		{"effectId": "Light Screen", "scope": "side", "side": "p1"},
	]
	panel.set_knowledge_snapshot(condition_snapshot)
	panel.advanced_scenario_expanded = true
	panel._render_current_state()
	await process_frame
	for condition_label: String in [
		panel._t("battle.calc.conditions_global").to_upper(),
		panel._t("battle.calc.conditions_your_side").to_upper(),
		panel._t("battle.calc.conditions_opponent_side").to_upper(),
		panel._t("battle.calc.condition.weather").to_upper(),
		panel._t("battle.calc.condition.terrain").to_upper(),
		panel._t("battle.calc.condition.status").to_upper(),
	]:
		if not _has_label_text(panel, condition_label):
			_fail("Battle-condition editor is missing the clearly labeled section %s" % condition_label)
			return
	if panel._get_field_scenario_option_label("weather", "") != panel._t("battle.calc.condition_current", {"value": panel._t("battle.calc.condition.weather.rain")}):
		_fail("Battle-condition selectors must identify the confirmed current weather")
		return
	var confirmed_light_screen := _find_button_text(panel, panel._t("battle.calc.condition.light_screen"))
	if confirmed_light_screen == null or not confirmed_light_screen.button_pressed or not confirmed_light_screen.disabled:
		_fail("Confirmed public side conditions must be visible, active, and protected from manual removal")
		return
	panel._on_field_side_condition_toggled(true, "opponentReflect")
	if panel.get_field_scenario().get("defenderReflect") != true:
		_fail("Opponent-side conditions must map to the defender while viewing damage dealt")
		return
	panel.active_subtab = panel.SUBTAB_THEIR_DAMAGE
	if panel.get_field_scenario().get("attackerReflect") != true or panel.get_field_scenario().has("defenderReflect"):
		_fail("Opponent-side conditions must stay with the opponent while viewing damage taken")
		return
	panel.active_subtab = panel.SUBTAB_YOUR_DAMAGE
	panel._on_field_side_condition_toggled(false, "opponentReflect")
	var status_selector := panel._make_pokemon_status_selector("opponent")
	var burn_index := -1
	for index in range(status_selector.item_count):
		if str(status_selector.get_item_metadata(index)) == "brn":
			burn_index = index
			break
	if burn_index < 0:
		_fail("Opponent status selector must expose burn as an explicit scenario")
		return
	panel._on_pokemon_status_selected(burn_index, status_selector)
	if panel.defender_assumptions.get("status") != "brn" or not bool(panel.edited_assumption_fields.get("status", false)):
		_fail("A hypothetical opponent burn must become an explicit calculator input")
		return
	var burned_snapshot := _selection_snapshot()
	burned_snapshot["opponentPokemon"][0]["status"] = {"state": "known", "value": "brn"}
	panel.set_knowledge_snapshot(burned_snapshot)
	if panel._get_effective_pokemon_status("opponent") != "brn" or panel.defender_assumptions.has("status"):
		_fail("Confirmed public burn must take priority and remove a stale hypothetical status")
		return
	var confirmed_status_selector := panel._make_pokemon_status_selector("opponent")
	if not confirmed_status_selector.disabled:
		_fail("Confirmed public status must be visible but not manually erasable")
		return
	panel.set_knowledge_snapshot(_selection_snapshot())
	panel.advanced_scenario_expanded = false
	if panel.item_assumption_input == null or panel.ability_assumption_input == null or panel.nature_assumption_input == null:
		_fail("Item, ability, and nature must be directly editable in their setup cards")
		return
	panel._on_catalog_assumption_focus_entered("item")
	if _count_nodes_of_type(panel.catalog_suggestions_box, "LineEdit") != 0:
		_fail("Inline setup autocomplete must not create a duplicate input below the setup cards")
		return
	panel.show_assumption_catalog_response("item", {
		"success": true,
		"items": [{"name": "Leftovers", "calcName": "Leftovers"}],
	})
	if not _has_label_text(panel.catalog_suggestions_box, panel._t("battle.calc.suggestions_for", {"field": panel._t("battle.calc.item")}).to_upper()):
		_fail("Inline setup autocomplete must clearly identify its suggestion field")
		return
	if not _has_label_text(panel.catalog_suggestions_box, "Leftovers") or not _has_label_text(panel.catalog_suggestions_box, panel._t("battle.calc.use_default_value")):
		_fail("Inline setup autocomplete must separate suggestions from its explicit default action")
		return
	panel._on_inline_assumption_text_submitted("left", "item")
	panel._on_inline_assumption_text_submitted("Pressure", "ability")
	panel._on_inline_assumption_text_submitted("Modest", "nature")
	if panel.defender_assumptions.get("item") != "Leftovers" or panel.defender_assumptions.get("ability") != "Pressure" or panel.defender_assumptions.get("nature") != "Modest":
		_fail("Submitting an inline setup field must apply the custom scenario directly")
		return
	for field_name: String in ["item", "ability", "nature"]:
		if not bool(panel.edited_assumption_fields.get(field_name, false)):
			_fail("Inline %s edits must retain user-scenario provenance" % field_name)
			return
	panel._reset_to_current()
	panel._on_assumption_summary_pressed("evs")
	await process_frame
	if panel.live_ev_inputs.size() != 6 or panel.live_ev_bars.size() != 6 or panel.live_ev_total_bar == null:
		_fail("EV editor must render six clearly tracked stat rows and a total allocation bar")
		return
	for stat_label: String in ["HP", "Defense", "Sp. Defense", "Attack", "Sp. Attack", "Speed"]:
		if not _has_label_text(panel.catalog_suggestions_box, stat_label):
			_fail("EV editor is missing the full stat label %s" % stat_label)
			return
	var min_button := _find_button_text(panel.catalog_suggestions_box, panel._t("battle.calc.ev_min_short"))
	var max_button := _find_button_text(panel.catalog_suggestions_box, panel._t("battle.calc.ev_max_short"))
	if min_button == null or max_button == null:
		_fail("EV quick actions must use explicit MIN and MAX labels instead of ambiguous numeric buttons")
		return
	if min_button.get_theme_color("font_color").is_equal_approx(max_button.get_theme_color("font_color")):
		_fail("EV MIN and MAX actions must have distinct semantic colors")
		return
	panel._on_live_ev_quick_value_pressed("hp", 252)
	panel._on_live_ev_quick_value_pressed("def", 252)
	panel._apply_live_ev_value("spd", 4, true)
	if panel.live_ev_total_bar.value != 508.0 or not panel.live_ev_total_label.get_theme_color("font_color").is_equal_approx(panel.STAGE_POSITIVE):
		_fail("A complete 508 EV spread must have a clear completed allocation state")
		return
	panel._reset_to_current()
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
	if not _has_line_edit_text(panel, "U-turn") or _count_line_edit_placeholder(panel, panel._t("battle.calc.add_move")) != 4:
		_fail("Damage taken must render four directly editable opponent move slots")
		return
	if panel.inline_move_result_panels.size() != 4:
		_fail("Every editable opponent move slot must own a styled autocomplete panel")
		return
	for panel_value: Variant in panel.inline_move_result_panels.values():
		var suggestions_panel := panel_value as PanelContainer
		if suggestions_panel == null or not suggestions_panel.has_theme_stylebox_override("panel"):
			_fail("Opponent move autocomplete must use the shared Calcdex suggestion styling")
			return
	panel.active_selector = "move"
	panel.active_move_slot = 1
	panel.selector_results = [{"name": "Bug Buzz", "calcName": "Bug Buzz", "type": "bug", "category": "special"}]
	panel._on_inline_move_text_submitted("bug buz", 1)
	if panel.defender_assumptions.get("assumedMoves") != ["U-turn", "Bug Buzz"]:
		_fail("Enter must accept the first visible move suggestion instead of committing partial text")
		return
	panel.selector_results = [{"name": "Hidden Power Ice", "calcName": "Hidden Power Ice", "type": "ice", "category": "special"}]
	panel._on_inline_move_text_submitted("hidden power i", 1)
	if panel.defender_assumptions.get("assumedMoves") != ["U-turn", "Hidden Power Ice"]:
		_fail("Hidden Power selections must preserve their explicit type in the calculator scenario")
		return
	panel._on_inline_move_text_submitted("Aura Sphere", 1)
	if panel.defender_assumptions.get("assumedMoves") != ["U-turn", "Aura Sphere"]:
		_fail("pressing Enter in an opponent result row must commit that move in place")
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
		"success": true, "schemaVersion": 1, "routeRevision": "calc4.5-2026-08-09",
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
		"viewerSide": "p1",
		"field": {"effects": []},
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Pikachu"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Mew"}}],
	}


func _has_line_edit_text(node: Node, text: String) -> bool:
	if node is LineEdit and (node as LineEdit).text == text:
		return true
	for child: Node in node.get_children():
		if _has_line_edit_text(child, text):
			return true
	return false


func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _has_label_text(child, text):
			return true
	return false


func _find_button_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var result := _find_button_text(child, text)
		if result != null:
			return result
	return null


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	if node == null:
		return 0
	var count := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _count_line_edit_placeholder(node: Node, text: String) -> int:
	var count := 1 if node is LineEdit and (node as LineEdit).placeholder_text == text else 0
	for child: Node in node.get_children():
		count += _count_line_edit_placeholder(child, text)
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
