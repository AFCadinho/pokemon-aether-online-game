extends RefCounted

class_name PvpRankedTeamValidation

const STATE_NOT_CHECKED := "not_checked"
const STATE_CHECKING := "checking"
const STATE_VALID := "valid"
const STATE_INVALID := "invalid"
const STATE_ERROR := "error"
const STATE_NOT_RANKED := "not_ranked"


static func not_checked() -> Dictionary:
	return {
		"state": STATE_NOT_CHECKED,
		"success": false,
		"valid": false,
		"errors": [],
		"issues": [],
		"warnings": [],
		"message": "Server validation has not run yet.",
		"teamHash": "",
	}


static func checking() -> Dictionary:
	return {
		"state": STATE_CHECKING,
		"success": false,
		"valid": false,
		"errors": [],
		"issues": [],
		"warnings": [],
		"message": "Checking ranked team with server...",
		"teamHash": "",
	}


static func not_ranked() -> Dictionary:
	return {
		"state": STATE_NOT_RANKED,
		"success": true,
		"valid": true,
		"errors": [],
		"issues": [],
		"warnings": [],
		"message": "Server ranked validation is only required for ranked queues.",
		"teamHash": "",
	}


static func normalize_response(response: Dictionary) -> Dictionary:
	var normalized := {
		"state": STATE_ERROR,
		"success": bool(response.get("success", false)),
		"valid": false,
		"errors": [],
		"issues": [],
		"warnings": _warning_messages(response.get("warnings", [])),
		"message": "",
		"teamHash": "",
		"raw": response.duplicate(true),
	}

	if not bool(response.get("success", false)):
		normalized["message"] = _failure_message(response)
		normalized["errors"] = [normalized["message"]]
		normalized["issues"] = [{"message": normalized["message"]}]
		return normalized

	var valid := bool(response.get("valid", false))
	var issues := _issue_details(response.get("errors", []))
	var errors := _messages_from_issues(issues)
	normalized["valid"] = valid
	normalized["errors"] = errors
	normalized["issues"] = issues
	normalized["teamHash"] = _team_hash(response)
	if valid:
		normalized["state"] = STATE_VALID
		normalized["message"] = "Ranked Ready"
	elif errors.is_empty():
		normalized["state"] = STATE_INVALID
		normalized["message"] = "Team is not eligible."
		normalized["errors"] = ["Team is not eligible for ranked queue."]
		normalized["issues"] = [{"message": "Team is not eligible for ranked queue."}]
	else:
		normalized["state"] = STATE_INVALID
		normalized["message"] = "Team is not eligible."
	return normalized


static func allows_ranked_join(result: Dictionary) -> bool:
	return str(result.get("state", "")).strip_edges() == STATE_VALID and bool(result.get("valid", false))


static func party_signature(party: Array) -> String:
	var parts: Array[String] = []
	for entry: Variant in party:
		if entry is Dictionary:
			var pokemon: Dictionary = entry as Dictionary
			parts.append("%s:%s" % [
				str(pokemon.get("instanceId", pokemon.get("instance_id", ""))).strip_edges(),
				JSON.stringify(_legality_signature_fields(pokemon)),
			])
		elif entry is Object:
			var object := entry as Object
			parts.append("%s:%s" % [
				str(object.get("instance_id")).strip_edges(),
				JSON.stringify({
					"species": object.get("species"),
					"level": object.get("level"),
					"item": object.get("item"),
					"ability": object.get("ability"),
					"nature": object.get("nature"),
					"moves": object.get("moves"),
					"evs": object.get("evs"),
					"ivs": object.get("ivs"),
				}),
			])
	return "|".join(parts)


static func _legality_signature_fields(pokemon: Dictionary) -> Dictionary:
	return {
		"species": pokemon.get("species", pokemon.get("speciesId", "")),
		"level": pokemon.get("level", 1),
		"item": pokemon.get("heldItemId", pokemon.get("item", "")),
		"ability": pokemon.get("ability", pokemon.get("abilityId", "")),
		"nature": pokemon.get("nature", pokemon.get("natureId", "")),
		"moves": pokemon.get("moves", []),
		"evs": pokemon.get("evs", {}),
		"ivs": pokemon.get("ivs", {}),
		"happiness": pokemon.get("happiness", pokemon.get("friendship", null)),
		"teraType": pokemon.get("teraType", pokemon.get("tera_type", "")),
	}


static func display_errors(result: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var value: Variant = result.get("errors", [])
	if value is Array:
		for item: Variant in value as Array:
			var text := str(item).strip_edges()
			if text != "":
				errors.append(text)
	return errors


static func display_issues(result: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var value: Variant = result.get("issues", [])
	if value is Array:
		for item: Variant in value as Array:
			if item is Dictionary:
				issues.append((item as Dictionary).duplicate(true))
			else:
				var text := str(item).strip_edges()
				if text != "":
					issues.append({"message": text})
	return issues


static func display_message(result: Dictionary) -> String:
	var message := str(result.get("message", "")).strip_edges()
	if message != "":
		return message
	return "Server validation unavailable." if str(result.get("state", "")) == STATE_ERROR else "Server validation pending."


static func _error_messages(value: Variant) -> Array[String]:
	return _messages_from_issues(_issue_details(value))


static func _messages_from_issues(issues: Array[Dictionary]) -> Array[String]:
	var messages: Array[String] = []
	for issue: Dictionary in issues:
		var message := _issue_message(issue)
		if message != "":
			messages.append(message)
	return messages


static func _issue_details(value: Variant) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if not (value is Array):
		return issues
	for item: Variant in value as Array:
		if item is Dictionary:
			var issue := (item as Dictionary).duplicate(true)
			if not issue.has("message"):
				issue["message"] = _issue_message(issue)
			issues.append(issue)
		else:
			var message := str(item).strip_edges()
			if message != "":
				issues.append({"message": message})
	return issues


static func _warning_messages(value: Variant) -> Array[String]:
	var messages: Array[String] = []
	if not (value is Array):
		return messages
	for item: Variant in value as Array:
		var message := _issue_message(item)
		if message != "":
			messages.append(message)
	return messages


static func _issue_message(value: Variant) -> String:
	if value is Dictionary:
		var issue: Dictionary = value as Dictionary
		var message := str(issue.get("message", "")).strip_edges()
		if message != "":
			return message
		var code := str(issue.get("code", "")).strip_edges()
		if code != "":
			return code.replace("_", " ").capitalize()
		return ""
	return str(value).strip_edges()


static func _failure_message(response: Dictionary) -> String:
	var error := str(response.get("error", response.get("detail", ""))).strip_edges()
	if error != "":
		return error
	var status := str(response.get("status", "")).strip_edges()
	if status != "" and status != "0":
		return "Server validation failed (%s)." % status
	return "Server validation failed."


static func _team_hash(response: Dictionary) -> String:
	var team_value: Variant = response.get("team", {})
	if team_value is Dictionary:
		return str((team_value as Dictionary).get("teamHash", "")).strip_edges()
	return ""
