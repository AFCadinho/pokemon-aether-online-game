extends SceneTree

const CalcdexOpen := preload("res://scripts/battle/battle_calcdex_open.gd")
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
	_check(refresh_source.find("open_calcdex") >= 0, "cold open uses the combined endpoint")
	_check(refresh_source.find("get_calcdex_snapshot") < 0, "cold open no longer performs a separate snapshot request")
	_check(refresh_source.find("_damage_calc_snapshot_matches_revision") >= 0, "an exact cached revision skips the cold-open endpoint")
	_check(refresh_source.find("damage_calc_prefetch_finished") >= 0, "opening waits for an already-running battle-start prefetch")
	_check(refresh_source.find("set_knowledge_snapshot(damage_calc_knowledge_snapshot, false)") >= 0, "snapshot defaults do not cancel the first calculation")

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
