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
	_assert(normalized["results"][0]["move"]["options"] == {"useZ": false, "isCrit": false}, "move modifiers must survive normalization")
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
	var selected_viewer_icon := content.find_child("ViewerTeamIcon2", true, false) as Button
	var selected_opponent_icon := content.find_child("OpponentTeamIcon1", true, false) as Button
	_assert(selected_viewer_icon != null and selected_opponent_icon != null, "both clickable team strips must render")
	var matchup_team_strip := content.find_child("MatchupTeamStrip", true, false)
	var viewer_team_strip := content.find_child("ViewerTeamStrip", true, false)
	var opponent_team_strip := content.find_child("OpponentTeamStrip", true, false)
	_assert(matchup_team_strip != null and viewer_team_strip != null and opponent_team_strip != null, "the compact matchup team header must render")
	if matchup_team_strip != null and viewer_team_strip != null and opponent_team_strip != null:
		_assert(viewer_team_strip.get_parent() == matchup_team_strip and opponent_team_strip.get_parent() == matchup_team_strip, "both teams must share one Showdex-style header row")
	if selected_viewer_icon != null and selected_opponent_icon != null:
		_assert(str(selected_viewer_icon.get_meta("pokemon_ref", "")) == "viewer:public-slot-2", "the selected viewer icon must remain on the left")
		_assert(str(selected_opponent_icon.get_meta("pokemon_ref", "")) == "opponent:public-slot-1", "the selected opponent icon must remain on the right")
	_assert(content.find_child("ViewerPokemonSelector", true, false) == null, "the visible viewer dropdown must be replaced by team icons")
	_assert(content.find_child("OpponentPokemonSelector", true, false) == null, "the visible opponent dropdown must be replaced by team icons")
	var fainted_icon := content.find_child("ViewerTeamIcon3", true, false) as Button
	var unknown_icon := content.find_child("OpponentTeamIcon2", true, false) as Button
	_assert(fainted_icon != null and fainted_icon.disabled and fainted_icon.modulate.a < 0.5, "fainted team icons must be disabled and dimmed")
	_assert(unknown_icon != null and unknown_icon.disabled and _has_label_text(unknown_icon, "?"), "unknown opponent slots must remain privacy-safe question icons")
	_assert(panel._resolve_selected_ref("opponent", "opponent:public-slot-2") == "opponent:public-slot-1", "unknown opponent slots must never become the calculation selection")
	panel._on_team_icon_pressed("opponent", "opponent:public-slot-2")
	_assert(panel.selected_opponent_ref == "opponent:public-slot-1", "direct selection must also reject an unknown opponent slot")
	_assert(_has_line_edit_text(content, "Thunderbolt"), "damage taken must keep the opponent move directly editable")
	_assert(panel.result_summary_panels.size() == 1, "an editable damage-taken move must retain its calculation summary")
	var move_table := content.find_child("MoveResultsTable", true, false)
	var workspace := content.find_child("CalcdexWorkspace", true, false)
	var inspector := content.find_child("CalcdexInspector", true, false)
	_assert(move_table != null and workspace != null and inspector != null, "the overview and contextual inspector must render side by side")
	_assert(content.find_child("MoveInspector", true, false) != null, "the move inspector must be active by default")
	_assert(content.find_child("ZToggle_0", true, false) is Button and content.find_child("CritToggle_0", true, false) is Button, "every calculated move row must expose Z and critical-hit toggles")
	panel._on_move_modifier_toggled(true, 0, "Thunderbolt", "isCrit")
	_assert(panel.get_move_scenarios() == [{"moveIndex": 0, "moveName": "Thunderbolt", "useZ": false, "isCrit": true}], "critical-hit toggles must create one row-scoped scenario")
	_assert(panel.pending_move_index == 0, "only the changed move row must enter recalculating state")
	panel._on_inspector_tab_pressed(panel.INSPECTOR_SET)
	var stat_grid := content.find_child("ShowdexStatGrid", true, false)
	_assert(stat_grid != null, "the set inspector must expose the stat grid")
	_assert(content.find_child("ShowdexEvHp", true, false) is LineEdit, "the stat grid must expose EV editing directly")
	_assert(content.find_child("ShowdexStageAtk", true, false) is OptionButton, "the stat grid must expose stages directly")
	_assert(content.find_child("SampleSetField", true, false) != null, "the sample-set selector must have a compact labeled field")
	panel._on_inspector_tab_pressed(panel.INSPECTOR_FIELD)
	_assert(content.find_child("ShowdexFieldControls", true, false) != null, "the field inspector must expose battle conditions")
	var disclosure_metadata: Dictionary = panel.result_disclosure_buttons.values()[0] if not panel.result_disclosure_buttons.is_empty() else {}
	_assert(bool(disclosure_metadata.get("compact", false)), "damage-taken summaries must use a separate compact disclosure beside the move input")
	panel._on_team_icon_pressed("viewer", "viewer:public-slot-1")
	_assert(panel.selected_viewer_ref == "viewer:public-slot-1", "clicking a team icon must select that public Pokémon directly")
	var viewer_forme_selector := content.find_child("ViewerFormeSelector", true, false) as MenuButton
	var opponent_forme_selector := content.find_child("OpponentFormeSelector", true, false) as MenuButton
	_assert(viewer_forme_selector != null and opponent_forme_selector != null, "both Pokémon names must be clickable forme selectors")
	panel.show_forme_catalog_response("opponent", "Pikachu", {
		"success": true,
		"forms": [{"id": "pikachu", "name": "Pikachu"}, {"id": "pikachurockstar", "name": "Pikachu-Rock-Star"}],
	})
	panel._on_forme_menu_item_pressed(1, "opponent")
	_assert(panel.get_species_scenario() == {"opponent": "Pikachu-Rock-Star"}, "a clicked forme must remain an explicit opponent calculation scenario")
	_assert(str(panel.species_scenarios.get("opponent:public-slot-1", "")) == "Pikachu-Rock-Star", "a forme scenario must be scoped to the selected public slot")
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
		"routeRevision": "calc4.0-2026-08-10",
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
			"options": {"useZ": false, "isCrit": false},
			"resultState": "supported",
			"damageDistribution": {"kind": "exact_rolls", "rolls": [42, 43]},
			"minDamage": 42,
			"maxDamage": 43,
			"averageDamage": 42.5,
			"minPercent": 30.0,
			"maxPercent": 31.0,
			"description": "safe",
			"koProjection": {"state": "available", "chance": 1.0, "hits": 2, "text": "guaranteed 2HKO", "basedOn": "exact_current_hp", "effects": []},
			"warningCodes": [],
		}],
		"warningCodes": ["CALC_SCENARIO_NATURE"],
	}


func _selection_snapshot() -> Dictionary:
	return {
		"viewerPokemon": [
			{"pokemonRef": "viewer:public-slot-1", "active": false, "fainted": false, "identity": {"state": "known", "value": "Bulbasaur"}, "hp": {"display": {"current": 100, "maximum": 100, "scale": "exact"}}},
			{"pokemonRef": "viewer:public-slot-2", "active": true, "fainted": false, "identity": {"state": "known", "value": "Mew"}, "hp": {"display": {"current": 73, "maximum": 100, "scale": "exact"}}},
			{"pokemonRef": "viewer:public-slot-3", "active": false, "fainted": true, "identity": {"state": "known", "value": "Charizard"}, "hp": {"display": {"current": 0, "maximum": 100, "scale": "exact"}}},
		],
		"opponentPokemon": [
			{"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Pikachu"}, "hp": {"display": {"current": 88, "maximum": 100, "scale": "public_percent_100"}}},
			{"pokemonRef": "opponent:public-slot-2", "active": false, "fainted": false, "identity": {"state": "unknown"}},
		],
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _has_line_edit_text(node: Node, expected: String) -> bool:
	if node is LineEdit and (node as LineEdit).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_line_edit_text(child, expected):
			return true
	return false


func _has_label_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_label_text(child, expected):
			return true
	return false
