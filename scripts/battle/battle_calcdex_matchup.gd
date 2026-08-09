extends RefCounted

class_name BattleCalcdexMatchup

const SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const SCHEMA_VERSION := 1
const ROUTE_REVISION := "calc3.4-2026-08-09"
const DIRECTIONS := ["own-to-opponent", "opponent-to-own"]
const RESULT_STATES := ["supported", "unsupported", "error"]
const MOVE_SOURCES := ["owned_exact", "public_reveal", "user_scenario", "public_usage_prior", "curated_prior"]


static func normalize_response(response: Dictionary, expected_revision: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response.duplicate(true)
	response = SNAPSHOT.canonicalize_success_response(response)
	expected_revision = SNAPSHOT.canonicalize_success_response(expected_revision)
	if not _has_exact_fields(response, ["success", "schemaVersion", "routeRevision", "safeInputFingerprint", "projectionRevision", "mechanicsManifest", "direction", "attacker", "defender", "results", "warningCodes"]):
		return _malformed("Unexpected Calcdex matchup fields.")
	if int(response.get("schemaVersion", 0)) != SCHEMA_VERSION or str(response.get("routeRevision", "")) != ROUTE_REVISION:
		return _malformed("Unsupported Calcdex matchup contract.")
	if not (response.get("projectionRevision") is Dictionary) or not SNAPSHOT.is_valid_projection_revision(response.get("projectionRevision", {})):
		return _malformed("Invalid Calcdex matchup revision.")
	if response.get("projectionRevision") != expected_revision:
		return _malformed("Stale Calcdex matchup revision.")
	if not SNAPSHOT.is_valid_mechanics_manifest(response.get("mechanicsManifest")):
		return _malformed("Invalid Calcdex mechanics manifest.")
	var fingerprint := str(response.get("safeInputFingerprint", ""))
	if fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(false):
		return _malformed("Invalid Calcdex safe-input fingerprint.")
	var direction := str(response.get("direction", ""))
	if direction not in DIRECTIONS:
		return _malformed("Invalid Calcdex matchup direction.")
	var attacker := _normalize_pokemon(response.get("attacker"), "attacker")
	var defender := _normalize_pokemon(response.get("defender"), "defender")
	if attacker.is_empty() or defender.is_empty():
		return _malformed("Invalid Calcdex matchup selection.")
	if not (response.get("results") is Array) or (response.get("results") as Array).size() > 4:
		return _malformed("Invalid Calcdex matchup result count.")
	var rows: Array[Dictionary] = []
	for row_value: Variant in response.get("results", []):
		var row := _normalize_row(row_value)
		if row.is_empty():
			return _malformed("Invalid Calcdex matchup result row.")
		rows.append(row)
	return {
		"success": true,
		"schemaVersion": SCHEMA_VERSION,
		"routeRevision": ROUTE_REVISION,
		"safeInputFingerprint": fingerprint,
		"projectionRevision": expected_revision.duplicate(true),
		"mechanicsManifest": (response.get("mechanicsManifest") as Dictionary).duplicate(true),
		"direction": direction,
		"attacker": attacker,
		"defender": defender,
		"results": rows,
		"warnings": _reason_codes(response.get("warningCodes", [])),
	}


static func _normalize_pokemon(value: Variant, _role: String) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value as Dictionary
	if not _has_exact_fields(source, ["pokemonRef", "relation", "species", "level", "active", "source"]):
		return {}
	var pokemon_ref := str(source.get("pokemonRef", ""))
	var relation := str(source.get("relation", ""))
	var species := str(source.get("species", "")).strip_edges()
	var level: Variant = source.get("level")
	if relation not in ["viewer", "opponent"] or not pokemon_ref.begins_with("%s:public-slot-" % relation):
		return {}
	if species == "" or typeof(level) != TYPE_INT or int(level) < 1 or int(level) > 100:
		return {}
	if str(source.get("source", "")) not in ["owned_exact", "public_reveal", "user_scenario"]:
		return {}
	return {
		"pokemonRef": pokemon_ref,
		"relation": relation,
		"species": species,
		"level": int(level),
		"active": bool(source.get("active", false)),
		"source": str(source.get("source")),
	}


static func _normalize_row(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value as Dictionary
	if not _has_required_allowed_fields(
		source,
		["moveName", "moveSource", "resultState", "damageDistribution", "endOfTurn", "warningCodes"],
		["moveName", "moveSource", "resultState", "reasonCode", "damageDistribution", "minDamage", "maxDamage", "averageDamage", "minPercent", "maxPercent", "description", "endOfTurn", "warningCodes"]
	):
		return {}
	var move_name := str(source.get("moveName", "")).strip_edges()
	var move_source := str(source.get("moveSource", ""))
	var state := str(source.get("resultState", ""))
	if move_name == "" or move_name.length() > 100 or move_source not in MOVE_SOURCES or state not in RESULT_STATES:
		return {}
	var distribution: Dictionary = source.get("damageDistribution", {}) if source.get("damageDistribution") is Dictionary else {}
	var rolls: Array = distribution.get("rolls", []) if distribution.get("rolls") is Array else []
	if str(distribution.get("kind", "")) not in ["exact_rolls", "unavailable"] or rolls.size() > 256:
		return {}
	for roll: Variant in rolls:
		if not (typeof(roll) in [TYPE_INT, TYPE_FLOAT]) or float(roll) < 0.0 or not is_finite(float(roll)):
			return {}
	var end_of_turn: Dictionary = source.get("endOfTurn", {}) if source.get("endOfTurn") is Dictionary else {}
	if end_of_turn != {"state": "not_included", "reasonCode": "CALC_END_OF_TURN_NOT_INCLUDED"}:
		return {}
	var result := {
		"move": {"name": move_name, "source": move_source},
		"resultState": state,
		"damageDistribution": {"kind": str(distribution.get("kind")), "rolls": rolls.duplicate(true)},
		"damage": rolls.duplicate(true),
		"endOfTurn": end_of_turn.duplicate(true),
		"warnings": _reason_codes(source.get("warningCodes", [])),
	}
	for key: String in ["minDamage", "maxDamage", "averageDamage", "minPercent", "maxPercent"]:
		if source.has(key):
			var number: Variant = source.get(key)
			if not (typeof(number) in [TYPE_INT, TYPE_FLOAT]) or float(number) < 0.0 or not is_finite(float(number)):
				return {}
			result[key] = number
	if source.has("description"):
		result["description"] = str(source.get("description", ""))
	if source.has("reasonCode"):
		result["reasonCode"] = str(source.get("reasonCode", ""))
	return result


static func _reason_codes(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array) or (value as Array).size() > 32:
		return result
	for code_value: Variant in value:
		var code := str(code_value)
		if code.length() > 0 and code.length() <= 96:
			result.append(code)
	return result


static func _malformed(message: String) -> Dictionary:
	return {"success": false, "code": "malformed_calcdex_matchup", "error": message}


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
