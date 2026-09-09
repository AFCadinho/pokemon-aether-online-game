extends RefCounted

const SNAPSHOT := preload("res://scripts/battle/battle_calcdex_snapshot.gd")


static func normalize_response(response: Dictionary, revision: Dictionary, opponent_ref: String) -> Dictionary:
	if not bool(response.get("success", false)):
		return {"success": false}
	response = SNAPSHOT.canonicalize_success_response(response)
	var fields := ["success", "schemaVersion", "routeRevision", "projectionRevision", "opponentRef", "species", "catalogRevision", "suggestions", "variantCount", "observationCount", "complete", "state"]
	if response.size() != fields.size():
		return {"success": false}
	for key: String in fields:
		if not response.has(key):
			return {"success": false}
	if response.get("routeRevision") != "set-inference-1" or response.get("schemaVersion") != 1 or response.get("projectionRevision") != revision or response.get("opponentRef") != opponent_ref:
		return {"success": false}
	if not response.get("suggestions") is Array or response["suggestions"].size() > 3:
		return {"success": false}
	for row: Variant in response["suggestions"]:
		if not row is Dictionary or row.get("confidence") not in ["weak", "possible", "strong"]:
			return {"success": false}
		var row_fields := ["groupId", "variantId", "name", "formatName", "build", "referenceBuild", "confidence", "evidence", "matchingVariantCount", "alternativeBuilds"]
		if row.size() != row_fields.size():
			return {"success": false}
		for key: String in row_fields:
			if not row.has(key):
				return {"success": false}
		for key: String in ["groupId", "variantId", "name", "formatName"]:
			if not row[key] is String or row[key].length() > 256:
				return {"success": false}
		if not row["alternativeBuilds"] is Array or row["alternativeBuilds"].size() > 3:
			return {"success": false}
		for alternative: Variant in row["alternativeBuilds"]:
			if not valid_build(alternative):
				return {"success": false}
		if not valid_build(row.get("build")) or not valid_build(row.get("referenceBuild")):
			return {"success": false}
		if not row.get("evidence") is Array or row["evidence"].size() > 22:
			return {"success": false}
		for evidence: Variant in row["evidence"]:
			if not evidence is Dictionary or evidence.get("kind") not in ["item", "ability", "move", "damage", "speed"] or evidence.get("state") not in ["match", "variant", "unknown", "conflict"]:
				return {"success": false}
			for key: Variant in evidence:
				if key not in ["kind", "state", "turn", "value"]:
					return {"success": false}
			if not evidence.get("value") is String or evidence["value"].length() > 256:
				return {"success": false}
	return response.duplicate(true)


static func valid_build(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		if key not in ["item", "ability", "nature", "evs", "ivs", "moves"]:
			return false
	if not value.get("moves") is Array or value["moves"].size() > 4:
		return false
	for move: Variant in value["moves"]:
		if not move is String or move.length() > 100 or move.is_empty():
			return false
	for key: String in ["item", "ability", "nature"]:
		if value.has(key) and (not value[key] is String or value[key].length() > 100):
			return false
	for key: String in ["evs", "ivs"]:
		if not value.get(key) is Dictionary:
			return false
		var total := 0
		for stat: Variant in value[key]:
			var amount: Variant = value[key][stat]
			if stat not in ["hp", "atk", "def", "spa", "spd", "spe"] or typeof(amount) not in [TYPE_INT, TYPE_FLOAT]:
				return false
			if not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or amount < 0 or amount > (252 if key == "evs" else 31):
				return false
			total += int(amount)
		if key == "evs" and total > 510:
			return false
	return true


static func signature(response: Dictionary) -> String:
	var material: Array = []
	for row: Dictionary in response.get("suggestions", []):
		material.append([row.get("groupId"), row.get("variantId"), row.get("confidence"), row.get("build")])
	return JSON.stringify(material).sha256_text()


static func preserve_revealed_moves(build: Dictionary, opponent: Dictionary) -> Dictionary:
	var result := build.duplicate(true)
	var moves: Array[String] = []
	for row: Dictionary in opponent.get("moves", []):
		var move := str(row.get("name", ""))
		if move != "" and move not in moves and moves.size() < 4:
			moves.append(move)
	for move: String in build.get("moves", []):
		if move not in moves and moves.size() < 4:
			moves.append(move)
	result["moves"] = moves
	return result
