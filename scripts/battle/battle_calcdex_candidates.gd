extends RefCounted

class_name BattleCalcdexCandidates

const SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const MATCHUP := preload("res://scripts/battle/battle_calcdex_matchup.gd")
const SCHEMA_VERSION := 1
const ROUTE_REVISION := "calc4.7-2026-08-09"


static func normalize_response(response: Dictionary, expected_revision: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response.duplicate(true)
	response = SNAPSHOT.canonicalize_success_response(response)
	expected_revision = SNAPSHOT.canonicalize_success_response(expected_revision)
	var top_fields: Array[String] = ["success", "schemaVersion", "routeRevision", "safeInputFingerprint", "projectionRevision", "mechanicsManifest", "presetRevision", "presetFingerprint", "direction", "rangeMode", "attacker", "defender", "candidates", "ranges", "candidateCoverage", "cacheStatus", "warningCodes"]
	if not _has_exact_fields(response, top_fields):
		return _malformed("Unexpected smart-matchup fields.")
	if int(response.get("schemaVersion", 0)) != SCHEMA_VERSION or str(response.get("routeRevision", "")) != ROUTE_REVISION:
		return _malformed("Unsupported smart-matchup revision.")
	if not (response.get("projectionRevision") is Dictionary) or response.get("projectionRevision") != expected_revision:
		return _malformed("Stale smart-matchup response.")
	if not SNAPSHOT.is_valid_mechanics_manifest(response.get("mechanicsManifest")):
		return _malformed("Invalid smart-matchup mechanics manifest.")
	for key: String in ["safeInputFingerprint", "presetFingerprint"]:
		var digest := str(response.get(key, ""))
		if digest.length() != 64 or not digest.is_valid_hex_number(false):
			return _malformed("Invalid smart-matchup fingerprint.")
	if str(response.get("direction", "")) not in MATCHUP.DIRECTIONS or str(response.get("rangeMode", "")) not in ["likely", "full"]:
		return _malformed("Invalid smart-matchup mode.")
	var attacker := MATCHUP._normalize_pokemon(response.get("attacker"), "attacker")
	var defender := MATCHUP._normalize_pokemon(response.get("defender"), "defender")
	if attacker.is_empty() or defender.is_empty():
		return _malformed("Invalid smart-matchup selection.")
	var candidates := _normalize_candidates(response.get("candidates"))
	if candidates.is_empty():
		return _malformed("Smart matchup requires candidates.")
	var ranges: Variant = _normalize_ranges(response.get("ranges"))
	if ranges == null:
		return _malformed("Invalid smart-matchup ranges.")
	var results: Array[Dictionary] = []
	for range_row: Dictionary in ranges:
		var minimum: Variant = range_row.get("displayedMinPercent")
		var maximum: Variant = range_row.get("displayedMaxPercent")
		results.append({
			"move": {"name": range_row["moveName"], "source": range_row["moveSource"]},
			"resultState": "supported" if minimum != null and maximum != null else "error",
			"minPercent": minimum,
			"maxPercent": maximum,
			"shortLabel": "%.1f-%.1f%%" % [float(minimum), float(maximum)] if minimum != null and maximum != null else "--",
			"damageDistribution": {"kind": "unavailable", "rolls": []},
			"koProjection": {
				"state": "unavailable", "chance": null, "hits": null, "text": "",
				"basedOn": "full_hp", "effects": [], "reasonCode": "CALC_KO_CANDIDATE_ENVELOPE",
			},
			"warnings": [],
			"candidateRange": range_row,
		})
	return {
		"success": true,
		"schemaVersion": SCHEMA_VERSION,
		"routeRevision": ROUTE_REVISION,
		"projectionRevision": expected_revision.duplicate(true),
		"mechanicsManifest": (response.get("mechanicsManifest") as Dictionary).duplicate(true),
		"presetRevision": str(response.get("presetRevision")),
		"presetFingerprint": str(response.get("presetFingerprint")),
		"direction": str(response.get("direction")),
		"rangeMode": str(response.get("rangeMode")),
		"attacker": attacker,
		"defender": defender,
		"candidates": candidates,
		"candidateCoverage": float(response.get("candidateCoverage", 0.0)),
		"cacheStatus": str(response.get("cacheStatus")),
		"results": results,
		"warnings": MATCHUP._reason_codes(response.get("warningCodes", [])),
	}


static func _normalize_candidates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array) or not 1 <= (value as Array).size() or (value as Array).size() > 12:
		return result
	var seen: Dictionary = {}
	for candidate_value: Variant in value:
		if not (candidate_value is Dictionary):
			return []
		var candidate: Dictionary = candidate_value as Dictionary
		if not _has_exact_fields(candidate, ["candidateId", "labelKey", "source", "weight", "coverage", "pinned", "effectiveInput", "explanationKeys", "results"]):
			return []
		var candidate_id := str(candidate.get("candidateId", ""))
		var source := str(candidate.get("source", ""))
		if candidate_id == "" or candidate_id.length() > 128 or seen.has(candidate_id) or source not in ["curated_prior", "public_usage_prior"]:
			return []
		var effective: Dictionary = candidate.get("effectiveInput", {}) if candidate.get("effectiveInput") is Dictionary else {}
		for key: Variant in effective.keys():
			if str(key) not in ["nature", "item", "ability", "status", "evs", "ivs", "boosts", "assumedMoves", "replaceMoves", "exactStats"]:
				return []
		if effective.has("status") and str(effective.get("status", "")) not in ["brn", "par", "psn", "tox", "slp", "frz"]:
			return []
		if effective.has("boosts") and not _is_valid_boost_table(effective.get("boosts")):
			return []
		if effective.has("exactStats") and typeof(effective.get("exactStats")) != TYPE_BOOL:
			return []
		if effective.has("replaceMoves") and typeof(effective.get("replaceMoves")) != TYPE_BOOL:
			return []
		var normalized_rows: Array[Dictionary] = []
		if not (candidate.get("results") is Array) or (candidate.get("results") as Array).size() > 4:
			return []
		for row_value: Variant in candidate.get("results", []):
			var row := MATCHUP._normalize_row(row_value, false)
			if row.is_empty():
				return []
			normalized_rows.append(row)
		seen[candidate_id] = true
		result.append({
			"candidateId": candidate_id,
			"labelKey": str(candidate.get("labelKey", "")),
			"source": source,
			"weight": float(candidate.get("weight", 0.0)),
			"coverage": float(candidate.get("coverage", 0.0)),
			"pinned": bool(candidate.get("pinned", false)),
			"effectiveInput": effective.duplicate(true),
			"explanationKeys": (candidate.get("explanationKeys") as Array).duplicate(true) if candidate.get("explanationKeys") is Array else [],
			"results": normalized_rows,
		})
	return result


static func _is_valid_boost_table(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for key: Variant in (value as Dictionary).keys():
		if str(key) not in ["atk", "def", "spa", "spd", "spe"]:
			return false
		var stage: Variant = (value as Dictionary).get(key)
		if typeof(stage) != TYPE_INT or int(stage) < -6 or int(stage) > 6:
			return false
	return true


static func _normalize_ranges(value: Variant) -> Variant:
	var result: Array[Dictionary] = []
	if not (value is Array) or (value as Array).size() > 4:
		return null
	for range_value: Variant in value:
		if not (range_value is Dictionary):
			return null
		var row: Dictionary = range_value as Dictionary
		var required: Array[String] = ["moveName", "moveSource", "likelyCandidateCount", "fullCandidateCount", "extremaCandidateIds"]
		var allowed: Array[String] = ["moveName", "moveSource", "likelyCandidateCount", "fullCandidateCount", "extremaCandidateIds", "likelyMinPercent", "likelyMaxPercent", "fullMinPercent", "fullMaxPercent", "displayedMinPercent", "displayedMaxPercent"]
		if not _has_required_allowed_fields(row, required, allowed) or str(row.get("moveName", "")) == "" or str(row.get("moveSource", "")) not in MATCHUP.MOVE_SOURCES:
			return null
		for key: String in ["likelyMinPercent", "likelyMaxPercent", "fullMinPercent", "fullMaxPercent", "displayedMinPercent", "displayedMaxPercent"]:
			if row.has(key) and (not typeof(row.get(key)) in [TYPE_INT, TYPE_FLOAT] or float(row.get(key)) < 0.0 or not is_finite(float(row.get(key)))):
				return null
		result.append(row.duplicate(true))
	return result


static func _has_exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	return _has_required_allowed_fields(value, fields, fields)


static func _has_required_allowed_fields(value: Dictionary, required: Array[String], allowed: Array[String]) -> bool:
	for key: String in required:
		if not value.has(key):
			return false
	for key: Variant in value.keys():
		if str(key) not in allowed:
			return false
	return true


static func _malformed(message: String) -> Dictionary:
	return {"success": false, "code": "malformed_calcdex_candidates", "error": message}
