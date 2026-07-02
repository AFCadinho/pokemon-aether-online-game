extends RefCounted

class_name PvpRankedBanlists

const STATE_NOT_LOADED := "not_loaded"
const STATE_LOADING := "loading"
const STATE_READY := "ready"
const STATE_ERROR := "error"

const CATEGORIES: Array[String] = ["pokemon", "items", "moves", "abilities"]
const CATEGORY_LABELS := {
	"pokemon": "Pokemon",
	"items": "Items",
	"moves": "Moves",
	"abilities": "Abilities",
}
const EMPTY_MESSAGES := {
	"pokemon": "No banned Pokemon.",
	"items": "No banned items.",
	"moves": "No banned moves.",
	"abilities": "No banned abilities.",
}


static func not_loaded() -> Dictionary:
	return {
		"state": STATE_NOT_LOADED,
		"success": false,
		"message": "Banlists have not loaded yet.",
		"metadata": _empty_metadata(),
		"banlists": _empty_banlists(),
	}


static func loading() -> Dictionary:
	return {
		"state": STATE_LOADING,
		"success": false,
		"message": "Loading...",
		"metadata": _empty_metadata(),
		"banlists": _empty_banlists(),
	}


static func normalize_response(response: Dictionary) -> Dictionary:
	var normalized := {
		"state": STATE_ERROR,
		"success": bool(response.get("success", false)),
		"message": "",
		"metadata": _empty_metadata(),
		"banlists": _empty_banlists(),
		"raw": response.duplicate(true),
	}

	if not bool(response.get("success", false)):
		normalized["message"] = _failure_message(response)
		return normalized

	var banlists_value: Variant = response.get("banlists", {})
	if not (banlists_value is Dictionary):
		normalized["message"] = "Failed to load banlists: malformed response."
		return normalized

	normalized["state"] = STATE_READY
	normalized["success"] = true
	normalized["message"] = "Ranked banlists loaded."
	normalized["metadata"] = _metadata_from_response(response)
	normalized["banlists"] = _banlists_from_response(banlists_value as Dictionary)
	return normalized


static func is_ready(result: Dictionary) -> bool:
	return str(result.get("state", "")).strip_edges() == STATE_READY and bool(result.get("success", false))


static func category_label(category: String) -> String:
	return str(CATEGORY_LABELS.get(category, category.capitalize()))


static func empty_message(category: String) -> String:
	return str(EMPTY_MESSAGES.get(category, "No bans in this category."))


static func category_bans(result: Dictionary, category: String) -> Array[Dictionary]:
	var banlists_value: Variant = result.get("banlists", {})
	if not (banlists_value is Dictionary):
		return []
	var values: Variant = (banlists_value as Dictionary).get(category, [])
	if values is Array:
		var bans: Array[Dictionary] = []
		for item: Variant in values as Array:
			if item is Dictionary:
				bans.append((item as Dictionary).duplicate(true))
		return bans
	return []


static func display_message(result: Dictionary) -> String:
	var message := str(result.get("message", "")).strip_edges()
	if message != "":
		return message
	if str(result.get("state", "")) == STATE_ERROR:
		return "Failed to load banlists."
	return "Loading..."


static func _empty_metadata() -> Dictionary:
	return {
		"rulesetId": "",
		"formatId": "",
		"formatKey": "",
		"formatName": "",
		"version": "",
		"banlistHash": "",
		"updatedAt": "",
	}


static func _empty_banlists() -> Dictionary:
	var banlists := {}
	for category: String in CATEGORIES:
		banlists[category] = []
	return banlists


static func _metadata_from_response(response: Dictionary) -> Dictionary:
	return {
		"rulesetId": str(response.get("rulesetId", "")).strip_edges(),
		"formatId": str(response.get("formatId", "")).strip_edges(),
		"formatKey": str(response.get("formatKey", response.get("formatId", ""))).strip_edges(),
		"formatName": str(response.get("formatName", response.get("formatId", ""))).strip_edges(),
		"version": str(response.get("version", "")).strip_edges(),
		"banlistHash": str(response.get("banlistHash", response.get("hash", ""))).strip_edges(),
		"updatedAt": str(response.get("updatedAt", "")).strip_edges(),
	}


static func _banlists_from_response(raw_banlists: Dictionary) -> Dictionary:
	var banlists := _empty_banlists()
	for category: String in CATEGORIES:
		var values: Variant = raw_banlists.get(category, [])
		if not (values is Array):
			continue
		var bans: Array[Dictionary] = []
		for item: Variant in values as Array:
			var ban := _normalize_ban(item)
			if not ban.is_empty():
				bans.append(ban)
		banlists[category] = bans
	return banlists


static func _normalize_ban(value: Variant) -> Dictionary:
	if value is Dictionary:
		var item: Dictionary = value as Dictionary
		var id := str(item.get("id", item.get("value", ""))).strip_edges()
		if id == "":
			return {}
		var label := str(item.get("label", "")).strip_edges()
		if label == "":
			label = _display_label(id)
		return {"id": id, "label": label}
	var raw := str(value).strip_edges()
	if raw == "":
		return {}
	return {"id": raw, "label": _display_label(raw)}


static func _display_label(identifier: String) -> String:
	var parts := identifier.replace("_", "-").split("-", false)
	var labels: Array[String] = []
	for part: String in parts:
		if part == "":
			continue
		labels.append(part.capitalize())
	return " ".join(labels) if not labels.is_empty() else identifier


static func _failure_message(response: Dictionary) -> String:
	var error := str(response.get("error", response.get("detail", ""))).strip_edges()
	if error != "":
		if error.to_lower().contains("timed out") or error.to_lower().contains("unavailable"):
			return "Server unavailable."
		return "Failed to load banlists: %s" % error
	var status := str(response.get("status", "")).strip_edges()
	if status != "" and status != "0":
		return "Failed to load banlists (%s)." % status
	return "Failed to load banlists."
