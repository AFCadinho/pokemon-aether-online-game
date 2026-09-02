class_name WildEncounterErrorRules
extends RefCounted


static func message_lines(response: Dictionary) -> Array[String]:
	var code := error_code(response)
	if code in [
		"fishing_rod_required",
		"fishing_rod_not_owned",
		"fishing_level_required",
		"fishing_badges_required",
		"encounter_type_not_found",
		"wild_encounter_not_found",
		"fishing_authentication_required",
		"fishing_rod_validation_unavailable",
		"no_usable_pokemon",
	]:
		return [BackendErrorLocalizationService.message(response)]
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
