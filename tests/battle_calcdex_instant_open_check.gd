extends SceneTree

const CalcdexOpen := preload("res://scripts/battle/battle_calcdex_open.gd")
const CalcdexSnapshot := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var revision := {
		"visibilityContractVersion": 3,
		"snapshotFingerprint": "a".repeat(64),
		"eventSeq": 1,
		"batchSeq": 1,
		"mechanicalRevision": 1,
		"aggregateRevision": 1,
		"battleEventSeq": 1,
	}
	var wire_revision := revision.duplicate(true)
	for field_name: String in [
		"visibilityContractVersion", "eventSeq", "batchSeq", "mechanicalRevision",
		"aggregateRevision", "battleEventSeq",
	]:
		wire_revision[field_name] = float(wire_revision[field_name])
	wire_revision["status"] = 200
	_check(
		CalcdexSnapshot.is_valid_projection_revision(
			CalcdexSnapshot.projection_revision_from_response(wire_revision)
		),
		"Team Preview accepts integer-valued revision numbers parsed from JSON as floats"
	)
	_check(
		not bool(CalcdexOpen.normalize_response({
			"success": true,
			"schemaVersion": 1,
			"routeRevision": CalcdexOpen.ROUTE_REVISION,
			"snapshot": {},
			"matchup": {},
		}, revision).get("success", false)),
		"the combined response fails closed when either nested contract is invalid"
	)

	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	var refresh_start := battle_source.find("func _refresh_damage_calc_results")
	var refresh_end := battle_source.find("\nfunc ", refresh_start + 5)
	var refresh_source := battle_source.substr(refresh_start, refresh_end - refresh_start)
	var closed_guard_end := refresh_source.find("\treturn")
	var closed_guard_source := refresh_source.substr(0, closed_guard_end)
	_check(
		closed_guard_source.find("_schedule_damage_calc_prefetch()") >= 0,
		"closed Calcdex keeps a public snapshot history for later damage inference"
	)
	_check(refresh_source.find("open_calcdex") >= 0, "cold open uses the combined endpoint")
	_check(refresh_source.find("get_calcdex_snapshot") >= 0, "Team Preview loads a selectable roster snapshot without inventing active Pokémon")
	_check(refresh_source.find("get_npc_battle_state") >= 0, "trainer Team Preview recovers a missing projection fence from participant-safe state")
	_check(refresh_source.find("_damage_calc_projection_revision_from_response") >= 0, "Team Preview reuses the validated snapshot revision for later selections")
	_check(refresh_source.find("_damage_calc_snapshot_matches_revision") >= 0, "an exact cached revision skips the cold-open endpoint")
	_check(refresh_source.find("damage_calc_prefetch_finished") >= 0, "opening waits for an already-running battle-start prefetch")
	_check(refresh_source.find("set_knowledge_snapshot(damage_calc_knowledge_snapshot, false)") >= 0, "snapshot defaults do not cancel the first calculation")
	_check(refresh_source.find("set_manual_matchup_selection_required") >= 0, "Team Preview requires an explicit matchup selection")

	var api_source := FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd")
	_check(api_source.find("/calcdex/v1/open") >= 0, "the client targets the versioned combined route")
	_check(battle_source.find("_schedule_damage_calc_prefetch()") >= 0, "battle setup prefetches the initial calculator result")
	var panel_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
	_check(panel_source.find("notify_assumption_changes: bool = true") >= 0, "the panel can initialize defaults without emitting a redundant refresh")

	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	panel.set_manual_matchup_selection_required(true)
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [
			{"pokemonRef": "viewer:public-slot-1", "active": false, "identity": {"state": "known", "value": "Garchomp"}},
			{"pokemonRef": "viewer:public-slot-2", "active": false, "identity": {"state": "known", "value": "Zapdos"}},
		],
		"opponentPokemon": [
			{"pokemonRef": "opponent:public-slot-1", "active": false, "identity": {"state": "known", "value": "Corviknight"}},
			{"pokemonRef": "opponent:public-slot-2", "active": false, "identity": {"state": "known", "value": "Iron Treads"}},
		],
	}, false)
	var preview_selection := panel.get_matchup_selection()
	_check(preview_selection.attackerRef == "" and preview_selection.defenderRef == "", "Team Preview does not present either roster member as already selected")
	var viewer_icon := content.find_child("ViewerTeamIcon2", true, false) as Button
	var opponent_icon := content.find_child("OpponentTeamIcon1", true, false) as Button
	_check(viewer_icon != null and opponent_icon != null and not viewer_icon.disabled and not opponent_icon.disabled, "both Team Preview rosters remain selectable in Calcdex")
	panel._on_team_icon_pressed("viewer", "viewer:public-slot-2")
	panel._on_team_icon_pressed("opponent", "opponent:public-slot-1")
	preview_selection = panel.get_matchup_selection()
	_check(preview_selection.attackerRef == "viewer:public-slot-2" and preview_selection.defenderRef == "opponent:public-slot-1", "an explicit pair becomes the preview calculation matchup")
	panel.set_manual_matchup_selection_required(false)
	var changes: Array[Dictionary] = []
	panel.defender_assumptions_changed.connect(func(assumptions: Dictionary, edited: Dictionary) -> void:
		changes.append({"assumptions": assumptions, "edited": edited})
	)
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true, "identity": {"state": "known", "value": "Garchomp"}}],
		"opponentPokemon": [{
			"pokemonRef": "opponent:public-slot-1", "active": true,
			"identity": {"state": "known", "value": "Corviknight"},
			"item": {"state": "unknown"}, "ability": {"state": "known", "value": "Pressure"},
			"status": {"state": "known", "value": ""},
		}],
	}, false)
	var assumption_state := panel.get_defender_assumption_state()
	_check(changes.is_empty(), "snapshot initialization does not enqueue a second calculation")
	_check(str(assumption_state.get("assumptions", {}).get("nature", "")) == "Hardy", "silent initialization still applies the visible default nature")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS battle_calcdex_instant_open_check")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
