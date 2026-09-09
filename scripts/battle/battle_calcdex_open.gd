extends RefCounted

class_name BattleCalcdexOpen

const SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const MATCHUP := preload("res://scripts/battle/battle_calcdex_matchup.gd")
const SCHEMA_VERSION := 1
const ROUTE_REVISION := "calc-open1.0-2026-09-09"


static func normalize_response(response: Dictionary, expected_revision: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response.duplicate(true)
	response = SNAPSHOT.canonicalize_success_response(response)
	if not _has_exact_fields(response, ["success", "schemaVersion", "routeRevision", "snapshot", "matchup"]):
		return _malformed("Unexpected Calcdex open fields.")
	if int(response.get("schemaVersion", 0)) != SCHEMA_VERSION or str(response.get("routeRevision", "")) != ROUTE_REVISION:
		return _malformed("Unsupported Calcdex open contract.")
	var snapshot_response := SNAPSHOT.normalize_response({
		"success": true,
		"schemaVersion": SNAPSHOT.SCHEMA_VERSION,
		"routeRevision": SNAPSHOT.ROUTE_REVISION,
		"snapshot": response.get("snapshot"),
	}, expected_revision)
	if not bool(snapshot_response.get("success", false)):
		return snapshot_response
	var matchup_value: Variant = response.get("matchup")
	if not (matchup_value is Dictionary):
		return _malformed("Calcdex open matchup is missing.")
	var matchup := MATCHUP.normalize_response(matchup_value as Dictionary, expected_revision)
	if not bool(matchup.get("success", false)):
		return matchup
	var snapshot: Dictionary = snapshot_response.get("snapshot", {}) as Dictionary
	if str(snapshot.get("safeInputFingerprint", "")) != str(matchup.get("safeInputFingerprint", "")):
		return _malformed("Calcdex open snapshot and matchup do not match.")
	return {
		"success": true,
		"schemaVersion": SCHEMA_VERSION,
		"routeRevision": ROUTE_REVISION,
		"snapshot": snapshot.duplicate(true),
		"matchup": matchup.duplicate(true),
	}


static func _has_exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key: Variant in value.keys():
		actual.append(str(key))
	actual.sort()
	var wanted := expected.duplicate()
	wanted.sort()
	return actual == wanted


static func _malformed(message: String) -> Dictionary:
	return {"success": false, "code": "CALC_INVALID_RESPONSE", "error": message}
