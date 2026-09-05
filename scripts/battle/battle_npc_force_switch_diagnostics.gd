extends RefCounted

class_name BattleNpcForceSwitchDiagnostics

const PREFIX := "[PAO NPC Force Switch Debug]"


static func build_snapshot(
	stage: String,
	trainer_name: String,
	attempt: int,
	player_id: String,
	state_requests: Dictionary,
	state_decisions: Dictionary,
	response: Dictionary = {}
) -> Dictionary:
	var snapshot := {
		"stage": stage,
		"trainer": trainer_name,
		"attempt": attempt,
		"playerId": player_id,
		"state": _projection_summary(state_requests, state_decisions, player_id),
	}
	if response.is_empty():
		return snapshot

	var response_requests := _dictionary_value(response.get("requests", {}))
	var response_decisions := _dictionary_value(response.get("decisions", {}))
	snapshot["response"] = {
		"success": bool(response.get("success", false)),
		"npcChoiceSkipped": bool(response.get("npcChoiceSkipped", false)),
		"npcChoiceSkipReason": str(response.get("npcChoiceSkipReason", "")),
		"eventSeq": int(response.get("eventSeq", -1)),
		"projection": _projection_summary(
			response_requests,
			response_decisions,
			player_id
		),
	}
	return snapshot


static func _projection_summary(
	requests: Dictionary,
	decisions: Dictionary,
	player_id: String
) -> Dictionary:
	var request := _dictionary_value(requests.get(player_id, {}))
	var decision := _dictionary_value(decisions.get(player_id, {}))
	var force_switches: Array[bool] = []
	var force_switch_value: Variant = request.get("forceSwitch", [])
	if force_switch_value is Array:
		for value: Variant in force_switch_value as Array:
			force_switches.append(bool(value))

	var active_value: Variant = request.get("active", [])
	var active_count := (active_value as Array).size() if active_value is Array else 0
	return {
		"requestPresent": not request.is_empty(),
		"requestWait": bool(request.get("wait", false)),
		"requestTeamPreview": bool(request.get("teamPreview", false)),
		"requestForceSwitch": force_switches,
		"requestActiveCount": active_count,
		"decisionPresent": not decision.is_empty(),
		"decisionStatus": str(decision.get("status", "")),
		"decisionKind": str(decision.get("decisionKind", "")),
		"decisionGeneration": int(decision.get("decisionGeneration", -1)),
		"decisionIdDigest": _identity_digest(decision.get("decisionId", "")),
		"party": _party_summary(request),
	}


static func _party_summary(request: Dictionary) -> Array[Dictionary]:
	var side := _dictionary_value(request.get("side", {}))
	var pokemon_value: Variant = side.get("pokemon", [])
	if not (pokemon_value is Array):
		return []

	var summary: Array[Dictionary] = []
	var pokemon: Array = pokemon_value as Array
	for index in range(pokemon.size()):
		var member := _dictionary_value(pokemon[index])
		if member.is_empty():
			continue
		var condition := str(member.get("condition", "")).strip_edges().to_lower()
		summary.append({
			"requestIndex": index + 1,
			"partySlot": int(member.get("partySlot", -1)),
			"metadataSlot": int(member.get("metadataSlot", -1)),
			"pokemonKeyDigest": _identity_digest(member.get("pokemonKey", "")),
			"identDigest": _identity_digest(member.get("ident", "")),
			"active": bool(member.get("active", false)),
			"fainted": bool(member.get("fainted", false)) or condition.ends_with(" fnt"),
		})
	return summary


static func _identity_digest(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	return normalized.sha256_text().left(10) if normalized != "" else ""


static func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
