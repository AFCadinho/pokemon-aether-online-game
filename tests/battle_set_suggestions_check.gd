extends SceneTree

const Suggestions := preload("res://scripts/battle/battle_set_suggestions.gd")
const CalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(load("res://scripts/battle/battle.gd") != null, "Battle integration compiles with project autoloads")
	var revision := {"visibilityContractVersion": 3, "snapshotFingerprint": "a".repeat(64), "eventSeq": 1,
		"batchSeq": 1, "mechanicalRevision": 1, "aggregateRevision": 1, "battleEventSeq": 1}
	var ref := "opponent:public-slot-1"
	var build := {"nature": "Impish", "item": "Rocky Helmet", "ability": "Rough Skin",
		"evs": {"hp": 252, "def": 164, "spe": 92}, "ivs": {},
		"moves": ["Earthquake", "Stealth Rock", "Toxic", "Dragon Tail"]}
	var row := {"groupId": "tank", "variantId": "tank-1", "name": "TankChomp", "formatName": "National Dex",
		"confidence": "strong", "build": build, "referenceBuild": build, "matchingVariantCount": 2, "alternativeBuilds": [],
		"evidence": [{"kind": "damage", "state": "match", "turn": 1, "value": "observed_range"}]}
	var response := {"success": true, "schemaVersion": 1, "routeRevision": "set-inference-1", "projectionRevision": revision,
		"opponentRef": ref, "species": "Garchomp", "catalogRevision": "fixture", "suggestions": [row],
		"variantCount": 2, "observationCount": 2, "complete": true, "state": "matches"}
	_check(bool(Suggestions.normalize_response(JSON.parse_string(JSON.stringify(response)), revision, ref).get("success")), "Wire numbers normalize")
	var stale := revision.duplicate(true)
	stale["eventSeq"] = 2
	_check(not bool(Suggestions.normalize_response(response, stale, ref).get("success")), "Stale responses are rejected")
	var leaked := response.duplicate(true)
	leaked["privateTeam"] = []
	_check(not bool(Suggestions.normalize_response(leaked, revision, ref).get("success")), "Private fields are rejected")
	var invalid := build.duplicate(true)
	invalid["evs"] = {"hp": 252, "def": 252, "spe": 252}
	_check(not Suggestions.valid_build(invalid), "Illegal EV totals are rejected")
	var changed_turn := response.duplicate(true)
	changed_turn["suggestions"][0]["evidence"][0]["turn"] = 2
	_check(Suggestions.signature(response) == Suggestions.signature(changed_turn), "Repeated equivalent evidence does not reannounce an ignored suggestion")
	var panel := CalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot({"battleId": "fixture", "projectionRevision": revision,
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true, "identity": {"state": "known", "value": "Starmie"}}],
		"opponentPokemon": [{"pokemonRef": ref, "active": true, "identity": {"state": "known", "value": "Garchomp"},
			"item": {"state": "known", "value": "Leftovers"}, "moves": [{"name": "Fire Blast"}, {"name": "Earthquake"}]}],
	})
	panel.defender_assumptions = {"nature": "Timid", "evs": {"spe": 252}}
	panel.edited_assumption_fields = {"nature": true, "evs": true}
	var before := panel.get_defender_assumption_state()
	var popup_response := response.duplicate(true)
	popup_response["suggestions"][0]["evidence"] = [
		{"kind": "damage", "state": "match", "turn": 1, "value": "observed_range"},
		{"kind": "move", "state": "variant", "turn": 1, "value": "Fire Blast"},
		{"kind": "speed", "state": "unknown", "turn": 1, "value": "ambiguous"},
		{"kind": "item", "state": "conflict", "turn": 1, "value": "Leftovers"},
	]
	for index in range(2):
		var extra_row := row.duplicate(true)
		extra_row["groupId"] = "tank-%s" % index
		extra_row["variantId"] = "tank-extra-%s" % index
		extra_row["name"] = "TankChomp Alternative %s" % (index + 1)
		popup_response["suggestions"].append(extra_row)
	panel.show_set_suggestions(ref, revision, popup_response)
	_check(panel.get_defender_assumption_state() == before, "Receiving suggestions never edits Custom")
	var host := VBoxContainer.new()
	content.add_child(host)
	panel._add_set_suggestions(host)
	var evidence_backed_toggle := host.find_child("SetSuggestionsToggle", true, false) as Button
	_check(evidence_backed_toggle != null, "Inspector keeps the compact suggestion opener")
	_check(evidence_backed_toggle.text == "Possible opponent sets (3)" and evidence_backed_toggle.get_theme_color("font_color") == Color("#8ccbe8"), "Evidence-backed suggestions announce their available match count")
	_check(evidence_backed_toggle.has_meta("set_suggestion_attention_pulse") and (evidence_backed_toggle.get_theme_stylebox("normal") as StyleBoxFlat).shadow_size == 4, "Evidence-backed suggestions receive a soft repeating attention glow")
	_check(host.find_child("ApplySetSuggestion", true, false) == null, "Suggestion cards do not expand the inspector layout")
	var catalog_only_response := popup_response.duplicate(true)
	catalog_only_response["observationCount"] = 0
	for suggestion: Dictionary in catalog_only_response["suggestions"]:
		suggestion["confidence"] = "weak"
	panel.show_set_suggestions(ref, revision, catalog_only_response)
	var catalog_only_host := VBoxContainer.new()
	content.add_child(catalog_only_host)
	panel._add_set_suggestions(catalog_only_host)
	var catalog_only_toggle := catalog_only_host.find_child("SetSuggestionsToggle", true, false) as Button
	_check(catalog_only_toggle.text == "Possible opponent sets" and catalog_only_toggle.get_theme_color("font_color") == Color("#f2f0ea"), "Catalog-only possibilities remain available without a misleading new-match badge")
	_check(not catalog_only_toggle.has_meta("set_suggestion_attention_pulse"), "Catalog-only possibilities do not pulse for attention")
	panel.show_set_suggestions(ref, revision, popup_response)
	panel._open_set_suggestions_popup()
	await process_frame
	_check(is_instance_valid(panel.set_suggestions_popup), "Suggestion opener creates its own popup layer")
	_check(panel.set_suggestions_popup.exclusive, "Suggestion popup blocks input behind its modal layer")
	_check(panel.set_suggestions_popup.find_child("SetSuggestionDetailsScroll", true, false) != null, "Suggestion details scroll independently from the fixed set list")
	_check(panel.set_suggestions_popup.find_child("ApplySetSuggestion", true, false) != null, "Suggestion popup has an explicit apply button")
	var suggestion_list := panel.set_suggestions_popup.find_child("SetSuggestionsList", true, false) as VBoxContainer
	var suggestion_workspace := panel.set_suggestions_popup.find_child("SetSuggestionsWorkspace", true, false) as HBoxContainer
	var suggestion_choices := panel.set_suggestions_popup.find_child("SetSuggestionChoices", true, false) as VBoxContainer
	_check(suggestion_choices != null and suggestion_choices.get_child_count() == 4 and suggestion_choices.get_child(0).name == "SetSuggestionChooseLabel", "All three suggestions remain visible beneath a clear choice heading")
	_check(suggestion_workspace != null, "Wide suggestion popup places its choice list beside the detail pane")
	_check(suggestion_list != null and suggestion_list.get_child_count() <= 5, "Suggestion popup keeps a compact master-detail structure")
	_check(panel.set_suggestions_popup.size.x <= 760 and panel.set_suggestions_popup.size.y <= 520, "Suggestion popup uses the available matchup workspace (%s)" % panel.set_suggestions_popup.size)
	_check(panel.set_suggestions_popup.find_child("SetSuggestionsIntro", true, false) != null, "Suggestion popup briefly explains what the player should do")
	_check(panel.set_suggestions_popup.find_child("SetSuggestionSelectedLabel", true, false) != null, "Suggestion details identify the selected set")
	var apply_button := panel.set_suggestions_popup.find_child("ApplySetSuggestion", true, false) as Button
	_check(apply_button != null and apply_button.text == "Calculate with this set" and panel.set_suggestions_popup.find_child("ApplySetSuggestionHint", true, false) != null, "The primary action explains its calculator effect")
	var suggestion_name := panel.set_suggestions_popup.find_child("SetSuggestionName", true, false) as Label
	var suggestion_build := panel.set_suggestions_popup.find_child("SetSuggestionBuild", true, false) as Label
	_check(suggestion_name != null and suggestion_name.text == "TankChomp" and suggestion_name.custom_minimum_size.y > 0, "Suggested set name remains visibly allocated")
	_check(suggestion_build != null and suggestion_build.text.contains("Rocky Helmet") and suggestion_build.text.contains("Earthquake") and suggestion_build.custom_minimum_size.y > 0, "Suggested build details remain visibly allocated")
	var evidence_summary := panel.set_suggestions_popup.find_child("SetSuggestionEvidenceSummary", true, false) as HFlowContainer
	_check(evidence_summary != null and evidence_summary.get_child_count() == 4, "Evidence summary shows every relevant non-zero category")
	var evidence_labels: Array[String] = []
	if evidence_summary != null:
		for child: Node in evidence_summary.get_children():
			evidence_labels.append(str(child.text))
			_check((child as Label).custom_minimum_size.x > 50.0, "Evidence label reserves enough width to render its text")
	_check(evidence_labels.has("✓ Clues matched: 1") and evidence_labels.has("~ Differences: 1"), "Evidence counters explain their meaning without a legend")
	var evidence_summaries := panel.set_suggestions_popup.find_children("SetSuggestionEvidenceSummary", "HFlowContainer", true, false)
	_check(evidence_summaries.size() == 3 and (evidence_summaries[1] as HFlowContainer).get_child_count() == 1, "Evidence summaries hide empty counters")
	_check(panel.set_suggestions_popup.find_child("SetSuggestionEvidenceDetail", true, false) != null, "The selected suggestion shows evidence without expanding its list row")
	var cards: Array[Node] = []
	for index in range(1, suggestion_choices.get_child_count()):
		cards.append(suggestion_choices.get_child(index))
	var whole_card_interactive := cards.size() == 3 and (cards[1] as PanelContainer).mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and not (cards[1] as PanelContainer).gui_input.get_connections().is_empty()
	if cards.size() > 1:
		var card_click := InputEventMouseButton.new()
		card_click.button_index = MOUSE_BUTTON_LEFT
		card_click.pressed = true
		(cards[1] as PanelContainer).gui_input.emit(card_click)
	_check(whole_card_interactive, "Every suggestion card advertises and handles its full clickable surface")
	_check(panel.selected_set_suggestion_key == "tank-0:tank-extra-0", "Clicking anywhere on a compact card changes the detail target")
	await process_frame
	var selected_name := panel.set_suggestions_popup.find_child("SetSuggestionName", true, false) as Label
	_check(selected_name != null and selected_name.text == "TankChomp Alternative 1", "The stable detail pane follows the selected suggestion")
	panel._apply_set_suggestion(build)
	_check(not is_instance_valid(panel.set_suggestions_popup), "Applying a suggestion closes the popup")
	_check(panel.defender_assumptions["assumedMoves"][0] == "Fire Blast", "Revealed Fire Blast survives reference Toxic")
	_check(panel.defender_assumptions["assumedMoves"].size() == 4, "Never adds a fifth move")
	_check(panel.defender_assumptions["item"] == "Leftovers", "Newest revealed item takes precedence")
	_check(panel.selected_sample_set_id == "" and not panel.edited_assumption_fields.is_empty(), "Applied suggestion becomes Custom")
	panel._undo_set_suggestion()
	_check(panel.defender_assumptions["nature"] == "Timid" and panel.defender_assumptions["evs"] == {"spe": 252}, "Undo restores prior manual stats")
	_check(panel.set_suggestion_undo.is_empty(), "Undo is consumed once")
	panel.knowledge_snapshot["opponentPokemon"][0]["item"] = {"state": "known", "value": null}
	panel._apply_set_suggestion(build)
	_check(not panel.defender_assumptions.has("item"), "Applying a suggestion keeps a knocked-off or consumed item slot empty")
	panel._undo_set_suggestion()
	panel.show_set_suggestions("opponent:public-slot-2", revision, {"success": false})
	_check(panel.set_suggestions.get("success") == true, "Wrong-opponent replies cannot erase current suggestions")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: set suggestion contract, preview, revealed moves, Custom and undo")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
