extends RefCounted

class_name BattleOwnedFormProjection

const STAT_KEYS := ["hp", "atk", "def", "spa", "spd", "spe"]


static func merge_stats(fallback_value: Variant, live_value: Variant) -> Dictionary:
	var merged: Dictionary = {}
	_apply_positive_stats(merged, fallback_value)
	_apply_positive_stats(merged, live_value)
	return merged


static func apply_live_form_to_hover(
	hover_data: Dictionary,
	display_data: Dictionary,
	temporary_species: String
) -> void:
	if temporary_species.strip_edges() == "":
		return

	hover_data["species"] = temporary_species
	hover_data["displaySpecies"] = temporary_species

	var live_stats := merge_stats(hover_data.get("stats", {}), display_data.get("stats", {}))
	if not live_stats.is_empty():
		hover_data["stats"] = live_stats

	var live_ability := str(display_data.get(
		"ability",
		display_data.get("baseAbility", display_data.get("base_ability", ""))
	)).strip_edges()
	if live_ability != "":
		hover_data["ability"] = live_ability
		hover_data["possibleAbilities"] = [live_ability]

	var live_types_value: Variant = display_data.get("types", [])
	if live_types_value is Array and not (live_types_value as Array).is_empty():
		hover_data["types"] = (live_types_value as Array).duplicate(true)


static func has_positive_stats(value: Variant) -> bool:
	var normalized: Dictionary = {}
	_apply_positive_stats(normalized, value)
	return not normalized.is_empty()


static func _apply_positive_stats(target: Dictionary, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var source := value as Dictionary
	for stat_key: String in STAT_KEYS:
		if not source.has(stat_key):
			continue
		var stat_value := int(source.get(stat_key, 0))
		if stat_value > 0:
			target[stat_key] = stat_value
