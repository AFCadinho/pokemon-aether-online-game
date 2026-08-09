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
	var usage_response := response.duplicate(true)
	usage_response["candidates"][0]["candidateId"] = "usage:mew-1630-01"
	usage_response["candidates"][0]["source"] = "public_usage_prior"
	usage_response["candidates"][0]["labelKey"] = "calcdex.preset.public_usage"
	usage_response["ranges"][0]["extremaCandidateIds"] = ["usage:mew-1630-01"]
	var normalized_usage := Candidates.normalize_response(usage_response, revision)
	if not bool(normalized_usage.get("success", false)) or normalized_usage["candidates"][0]["source"] != "public_usage_prior":
		_fail("public aggregate usage candidates must normalize without becoming confirmed facts")
		return
	var leaked := response.duplicate(true)
	leaked["candidates"][0]["effectiveInput"]["privateSetId"] = "secret"
	if bool(Candidates.normalize_response(leaked, revision).get("success", false)):
		_fail("unknown effective-input fields must fail closed")
		return

	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot(_selection_snapshot())
	panel.show_response(normalized)
	await process_frame
	if panel._get_nature_chip_label({}, "aggregate_prior").contains("Hardy"):
		_fail("a public candidate range must not be presented as an assumed Hardy nature")
		return
	if panel.get_smart_options()["rangeMode"] != "likely":
		_fail("likely range must be the safe default")
		return
	panel._on_smart_range_pressed("full")
	if panel.get_smart_options()["rangeMode"] != "full":
		_fail("full envelope switch must be reversible")
		return
	panel._on_candidate_pin_pressed("curated:fast-special")
	if panel.get_smart_options()["pinnedCandidateId"] != "curated:fast-special":
		_fail("candidate pin must be explicit")
		return
	panel._on_candidate_pin_pressed("curated:fast-special")
	if panel.get_smart_options()["pinnedCandidateId"] != "":
		_fail("candidate pin must reset")
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
		"success": true, "schemaVersion": 1, "routeRevision": "calc4.1-2026-08-09",
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
		"ranges": [{"moveName": "Thunderbolt", "likelyMinPercent": 20.0, "likelyMaxPercent": 40.0, "fullMinPercent": 10.0, "fullMaxPercent": 50.0, "displayedMinPercent": 20.0, "displayedMaxPercent": 40.0, "likelyCandidateCount": 1, "fullCandidateCount": 1, "extremaCandidateIds": ["curated:fast-special"]}],
		"candidateCoverage": 0.6, "cacheStatus": "miss", "warningCodes": [],
	}


func _selection_snapshot() -> Dictionary:
	return {
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Pikachu"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false, "identity": {"state": "known", "value": "Mew"}}],
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
