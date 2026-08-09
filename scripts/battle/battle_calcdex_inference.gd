extends RefCounted

class_name BattleCalcdexInference

const CANDIDATES := preload("res://scripts/battle/battle_calcdex_candidates.gd")
const ROUTE_REVISION := "calc5.1-2026-08-09"


static func normalize_response(response: Dictionary, expected_revision: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response.duplicate(true)
	response = CANDIDATES.SNAPSHOT.canonicalize_success_response(response)
	expected_revision = CANDIDATES.SNAPSHOT.canonicalize_success_response(expected_revision)
	var extras := ["inferenceRevision", "inferenceMode", "consideredEvidenceCount", "appliedEvidence", "inferenceExplanationKeys"]
	var calc4 := response.duplicate(true)
	for key: String in extras:
		if not calc4.has(key):
			return _malformed("Missing inference response field.")
		calc4.erase(key)
	if str(calc4.get("routeRevision", "")) != ROUTE_REVISION:
		return _malformed("Unsupported inference route revision.")
	calc4["routeRevision"] = CANDIDATES.ROUTE_REVISION
	var normalized: Dictionary = CANDIDATES.normalize_response(calc4, expected_revision)
	if not bool(normalized.get("success", false)):
		return normalized
	if str(response.get("inferenceRevision", "")) != "public-observations-v1" or str(response.get("inferenceMode", "")) != "public_observations":
		return _malformed("Unsupported inference model.")
	var count_value: Variant = response.get("consideredEvidenceCount")
	if typeof(count_value) != TYPE_INT or int(count_value) < 0 or int(count_value) > 64:
		return _malformed("Invalid inference evidence count.")
	var applied: Variant = _normalize_applied(response.get("appliedEvidence"))
	if applied == null:
		return _malformed("Invalid inference evidence explanation.")
	var explanations: Variant = response.get("inferenceExplanationKeys")
	if not (explanations is Array) or (explanations as Array).size() > 32:
		return _malformed("Invalid inference explanation keys.")
	for value: Variant in explanations:
		if typeof(value) != TYPE_STRING or str(value).strip_edges() == "" or str(value).length() > 128:
			return _malformed("Invalid inference explanation key.")
	normalized["routeRevision"] = ROUTE_REVISION
	normalized["inferenceRevision"] = "public-observations-v1"
	normalized["inferenceMode"] = "public_observations"
	normalized["consideredEvidenceCount"] = int(count_value)
	normalized["appliedEvidence"] = applied
	normalized["inferenceExplanationKeys"] = (explanations as Array).duplicate(true)
	return normalized


static func _normalize_applied(value: Variant) -> Variant:
	if not (value is Array) or (value as Array).size() > 16:
		return null
	var result: Array[Dictionary] = []
	for row_value: Variant in value:
		if not (row_value is Dictionary):
			return null
		var row: Dictionary = row_value as Dictionary
		if not CANDIDATES._has_exact_fields(row, ["evidenceType", "opponentRef", "turn", "explanationKey", "excludedCandidateIds"]):
			return null
		if str(row.get("evidenceType", "")) not in ["damage_interval", "speed_order"] or not str(row.get("opponentRef", "")).begins_with("opponent:public-slot-"):
			return null
		if typeof(row.get("turn")) != TYPE_INT or int(row.get("turn")) < 0 or not (row.get("excludedCandidateIds") is Array) or (row.get("excludedCandidateIds") as Array).size() > 12:
			return null
		result.append(row.duplicate(true))
	return result


static func _malformed(message: String) -> Dictionary:
	return {"success": false, "code": "malformed_calcdex_inference", "error": message}
