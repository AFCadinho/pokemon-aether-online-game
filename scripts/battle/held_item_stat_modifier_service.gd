extends RefCounted

class_name HeldItemStatModifierService

## Resolves static held-item stat modifiers for presentation purposes.
##
## The stored Pokemon stats remain the unmodified calculated stats. Battle
## effects which depend on field state, ability, status, or stat stages do not
## belong here; those are resolved by the battle engine and existing UI state.

const STAT_KEYS := ["atk", "def", "spa", "spd", "spe"]

static func effective_stats(stats_value: Variant, item_value: Variant, species_value: Variant = "") -> Dictionary:
	var stats: Dictionary = {}
	if stats_value is Dictionary:
		stats = (stats_value as Dictionary).duplicate(true)

	var modifiers := stat_modifiers(item_value, species_value)
	for stat_key: String in STAT_KEYS:
		if not modifiers.has(stat_key) or not stats.has(stat_key):
			continue
		stats[stat_key] = int(floor(float(int(stats[stat_key])) * float(modifiers[stat_key])))
	return stats

static func stat_modifiers(item_value: Variant, species_value: Variant = "") -> Dictionary:
	var item_id := _normalize_id(item_value)
	var species_id := _normalize_id(species_value)
	match item_id:
		"choice-band":
			return {"atk": 1.5}
		"choice-scarf":
			return {"spe": 1.5}
		"choice-specs":
			return {"spa": 1.5}
		"assault-vest":
			return {"spd": 1.5}
		"light-ball":
			if species_id == "pikachu":
				return {"atk": 2.0, "spa": 2.0}
		"thick-club":
			if species_id in ["cubone", "marowak", "marowak-alola"]:
				return {"atk": 2.0}
		"deep-sea-tooth":
			if species_id == "clamperl":
				return {"spa": 2.0}
		"deep-sea-scale":
			if species_id == "clamperl":
				return {"spd": 2.0}
		"metal-powder":
			if species_id == "ditto":
				return {"def": 2.0}
		"quick-powder":
			if species_id == "ditto":
				return {"spe": 2.0}
	return {}

static func _normalize_id(value: Variant) -> String:
	return str(value).strip_edges().to_lower().replace(" ", "-").replace("_", "-")
