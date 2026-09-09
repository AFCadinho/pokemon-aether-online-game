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
	panel.show_set_suggestions(ref, revision, response)
	_check(panel.get_defender_assumption_state() == before, "Receiving suggestions never edits Custom")
	panel.set_suggestions_expanded = true
	var host := VBoxContainer.new()
	content.add_child(host)
	panel._add_set_suggestions(host)
	_check(host.find_child("ApplySetSuggestion", true, false) != null, "Expanded suggestions have an explicit apply button")
	panel._apply_set_suggestion(build)
	_check(panel.defender_assumptions["assumedMoves"][0] == "Fire Blast", "Revealed Fire Blast survives reference Toxic")
	_check(panel.defender_assumptions["assumedMoves"].size() == 4, "Never adds a fifth move")
	_check(panel.defender_assumptions["item"] == "Leftovers", "Newest revealed item takes precedence")
	_check(panel.selected_sample_set_id == "" and not panel.edited_assumption_fields.is_empty(), "Applied suggestion becomes Custom")
	panel._undo_set_suggestion()
	_check(panel.defender_assumptions["nature"] == "Timid" and panel.defender_assumptions["evs"] == {"spe": 252}, "Undo restores prior manual stats")
	_check(panel.set_suggestion_undo.is_empty(), "Undo is consumed once")
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
