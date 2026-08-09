extends SceneTree

const Inference := preload("res://scripts/battle/battle_calcdex_inference.gd")
const CalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")

var failed := false


func _init() -> void:
	var revision := _revision()
	var response := _response(revision)
	var normalized := Inference.normalize_response(response, revision)
	_check(bool(normalized.get("success", false)), "valid public inference response normalizes")
	_check(normalized.get("inferenceExplanationKeys", []).size() == 1, "inference explanation remains visible")
	var wire_response: Dictionary = JSON.parse_string(JSON.stringify(response))
	wire_response["status"] = 200.0
	_check(
		bool(Inference.normalize_response(wire_response, JSON.parse_string(JSON.stringify(revision))).get("success", false)),
		"inference accepts integral JSON numbers and known HTTP transport metadata"
	)
	var leaked := response.duplicate(true)
	leaked["appliedEvidence"][0]["privateDamage"] = 999
	_check(not bool(Inference.normalize_response(leaked, revision).get("success", false)), "unexpected inference fields fail closed")
	var panel := CalcPanel.new()
	_check(not bool(panel.get_smart_options().get("useObservationInference", true)), "inference is opt-in")
	panel._on_inference_toggle_pressed()
	_check(bool(panel.get_smart_options().get("useObservationInference", false)), "inference can be enabled and reversed")
	panel._on_inference_toggle_pressed()
	_check(not bool(panel.get_smart_options().get("useObservationInference", true)), "ignore restores Calc-4 request mode")
	panel.free()
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	var refresh_start := battle_source.find("func _refresh_damage_calc_results")
	var refresh_end := battle_source.find("\nfunc ", refresh_start + 5)
	var refresh_source := battle_source.substr(refresh_start, refresh_end - refresh_start)
	var inferred_index := refresh_source.find("calculate_calcdex_inferred_matchup")
	var smart_index := refresh_source.find("calculate_calcdex_smart_matchup", inferred_index)
	var base_index := refresh_source.find("calculate_calcdex_matchup", smart_index)
	_check(inferred_index >= 0 and smart_index > inferred_index and base_index > smart_index, "downgrade order is inferred to smart to base")
	if not failed:
		print("PASS battle_calcdex_inference_check")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _revision() -> Dictionary:
	return {
		"visibilityContractVersion": 3, "snapshotFingerprint": "a".repeat(64),
		"eventSeq": 1, "batchSeq": 1, "mechanicalRevision": 1,
		"aggregateRevision": 1, "battleEventSeq": 1,
	}


func _response(revision: Dictionary) -> Dictionary:
	var pokemon := {"pokemonRef": "viewer:public-slot-1", "relation": "viewer", "species": "Starmie", "level": 50, "active": true, "source": "owned_exact"}
	var opponent := {"pokemonRef": "opponent:public-slot-1", "relation": "opponent", "species": "Pikachu", "level": 50, "active": true, "source": "public_reveal"}
	var result := {
		"moveName": "Surf", "moveSource": "owned_exact", "resultState": "supported",
		"damageDistribution": {"kind": "exact_rolls", "rolls": [20]}, "minDamage": 20,
		"maxDamage": 20, "averageDamage": 20.0, "minPercent": 20.0, "maxPercent": 20.0,
		"description": "safe", "endOfTurn": {"state": "not_included", "reasonCode": "CALC_END_OF_TURN_NOT_INCLUDED"}, "warningCodes": [],
	}
	return {
		"success": true, "schemaVersion": 1, "routeRevision": "calc5.1-2026-08-09",
		"safeInputFingerprint": "b".repeat(64), "projectionRevision": revision,
		"mechanicsManifest": {"contractRevision": "calc0-2026-08-08", "damageCalcVersion": "0.10.0", "showdownVersion": "0.11.10", "formatDataFingerprint": "fd94c49ab26ddf8daff2259dfc2b3857f957e37b166557412c4fe303c87e54b0"},
		"presetRevision": "test-v1", "presetFingerprint": "d".repeat(64),
		"direction": "own-to-opponent", "rangeMode": "likely", "attacker": pokemon, "defender": opponent,
		"candidates": [{"candidateId": "curated:bulky", "labelKey": "calcdex.preset.bulky", "source": "curated_prior", "weight": 1.0, "coverage": 1.0, "pinned": false, "effectiveInput": {"nature": "Bold", "evs": {"hp": 252}, "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}, "assumedMoves": []}, "explanationKeys": ["calcdex.explain.curated_preset"], "results": [result]}],
		"ranges": [{"moveName": "Surf", "moveSource": "owned_exact", "likelyMinPercent": 20.0, "likelyMaxPercent": 20.0, "fullMinPercent": 20.0, "fullMaxPercent": 20.0, "displayedMinPercent": 20.0, "displayedMaxPercent": 20.0, "likelyCandidateCount": 1, "fullCandidateCount": 1, "extremaCandidateIds": ["curated:bulky"]}],
		"candidateCoverage": 1.0, "cacheStatus": "miss", "warningCodes": [],
		"inferenceRevision": "public-observations-v1", "inferenceMode": "public_observations", "consideredEvidenceCount": 1,
		"appliedEvidence": [{"evidenceType": "damage_interval", "opponentRef": "opponent:public-slot-1", "turn": 7, "explanationKey": "calcdex.inference.damage_interval", "excludedCandidateIds": ["curated:fast"]}],
		"inferenceExplanationKeys": ["calcdex.inference.public_only_applied"],
	}
