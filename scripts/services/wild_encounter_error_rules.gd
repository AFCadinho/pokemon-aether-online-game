class_name WildEncounterErrorRules
extends RefCounted


static func message_lines(response: Dictionary) -> Array[String]:
	match error_code(response):
		"fishing_rod_required":
			return ["You need a fishing rod before you can fish here."]
		"fishing_rod_not_owned":
			return [
				"That fishing rod is no longer available in your Bag.",
				"Your fishing access has been refreshed.",
			]
		"fishing_level_required":
			var detail := _detail(response)
			return ["Fishing Level %d is required for this rod. Your Fishing Level is %d." % [
				int(detail.get("requiredFishingLevel", 1)),
				int(detail.get("currentFishingLevel", 1)),
			]]
		"fishing_badges_required":
			var detail := _detail(response)
			return ["You need %d %s badges for this rod. You currently have %d." % [
				int(detail.get("requiredBadges", 0)),
				str(detail.get("region", "regional")).capitalize(),
				int(detail.get("currentBadges", 0)),
			]]
		"encounter_type_not_found":
			return ["Nothing seems to be biting with this rod here."]
		"fishing_authentication_required":
			return [
				"Your fishing access could not be verified.",
				"Please log in again.",
			]
		"fishing_rod_validation_unavailable":
			return [
				"Fishing is temporarily unavailable.",
				"Please try again in a moment.",
			]
		"no_usable_pokemon":
			return [
				"None of your Pokemon are able to battle.",
				"Heal your party at a Pokemon Center before trying again.",
			]
		_:
			return []


static func error_code(response: Dictionary) -> String:
	var detail := _detail(response)
	var code := str(detail.get(
		"code",
		response.get("errorCode", response.get("code", ""))
	)).strip_edges().to_lower()
	if code != "":
		return code

	# Backward compatibility while older Showdown API instances still return
	# only their human-readable validation error.
	var error_message := str(response.get("error", "")).strip_edges().to_lower()
	if error_message == "player 1 has no usable pokemon":
		return "no_usable_pokemon"

	return ""


static func _detail(response: Dictionary) -> Dictionary:
	var detail_value: Variant = response.get("detail", {})
	if detail_value is Dictionary and not (detail_value as Dictionary).is_empty():
		return detail_value as Dictionary
	var body_value: Variant = response.get("body", {})
	if body_value is Dictionary:
		var nested_value: Variant = (body_value as Dictionary).get("detail", {})
		if nested_value is Dictionary:
			return nested_value as Dictionary
	return {}
