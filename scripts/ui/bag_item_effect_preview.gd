extends RefCounted

class_name BagItemEffectPreview

const SUPPORTED_EFFECT_TYPES := {
	"heal_hp": true,
	"cure_status": true,
	"revive": true,
}

const STATUS_LABELS := {
	"psn": "Poisoned",
	"tox": "Badly Poisoned",
	"brn": "Burned",
	"par": "Paralyzed",
	"slp": "Asleep",
	"frz": "Frozen",
}


static func supports(gameplay: Dictionary) -> bool:
	if str(gameplay.get("target", "")).strip_edges().to_lower() != "pokemon":
		return false
	var contexts_value: Variant = gameplay.get("contexts", [])
	if not (contexts_value is Array) or not (contexts_value as Array).has("field"):
		return false
	var effects_value: Variant = gameplay.get("effects", [])
	if not (effects_value is Array) or (effects_value as Array).is_empty():
		return false
	for effect_value: Variant in effects_value as Array:
		if not (effect_value is Dictionary):
			return false
		var effect_type := str((effect_value as Dictionary).get("type", "")).strip_edges().to_lower()
		if not SUPPORTED_EFFECT_TYPES.has(effect_type):
			return false
	return true


static func preview(pokemon: Pokemon, gameplay: Dictionary, requested_quantity: int) -> Dictionary:
	if pokemon == null or not supports(gameplay):
		return {}

	var max_hp: int = max(pokemon.max_hp, int(pokemon.stats.get("hp", pokemon.max_hp)), 1)
	var current_hp: int = clampi(pokemon.current_hp, 0, max_hp)
	var status: String = _normalize_status(pokemon.status)
	var was_fainted: bool = current_hp <= 0
	var quantity: int = max(requested_quantity, 1)
	if str(gameplay.get("quantityPolicy", "single")) == "single":
		quantity = 1

	var consumed_quantity: int = 0
	var cured_status := ""
	var revived := false
	for effect_value: Variant in gameplay.get("effects", []):
		var effect: Dictionary = effect_value as Dictionary
		match str(effect.get("type", "")).strip_edges().to_lower():
			"heal_hp":
				if current_hp <= 0 or current_hp >= max_hp:
					continue
				var missing_hp: int = max_hp - current_hp
				var mode: String = str(effect.get("mode", "fixed")).strip_edges().to_lower()
				var used: int = 1
				var restored: int = missing_hp
				if mode == "fixed":
					var amount: int = max(int(effect.get("amount", 0)), 0)
					if amount <= 0:
						continue
					used = min(quantity, int(ceil(float(missing_hp) / float(amount))))
					restored = min(missing_hp, used * amount)
				current_hp = min(current_hp + restored, max_hp)
				consumed_quantity = max(consumed_quantity, used)
			"cure_status":
				if current_hp <= 0 or status == "":
					continue
				var configured_statuses: Array = effect.get("statuses", [])
				if configured_statuses.has(status):
					cured_status = status
					status = ""
					consumed_quantity = max(consumed_quantity, 1)
			"revive":
				if current_hp > 0:
					continue
				var hp_percent: int = clampi(int(effect.get("hpPercent", 0)), 1, 100)
				var minimum_hp: int = max(int(effect.get("minimumHp", 1)), 1)
				current_hp = min(max(minimum_hp, int(floor(float(max_hp * hp_percent) / 100.0))), max_hp)
				status = ""
				revived = true
				consumed_quantity = max(consumed_quantity, 1)

	if consumed_quantity <= 0:
		return {
			"canApply": false,
			"label": _no_effect_label(was_fainted, current_hp, max_hp, status),
			"tooltip": _no_effect_tooltip(pokemon, was_fainted, current_hp, max_hp, status),
			"usedQuantity": 0,
		}

	var label: String = "%s/%s -> %s/%s" % [pokemon.current_hp, max_hp, current_hp, max_hp]
	if revived:
		label = "Fainted -> %s/%s" % [current_hp, max_hp]
	elif cured_status != "" and pokemon.current_hp == current_hp:
		label = "%s -> Healthy" % _status_label(cured_status)
	elif cured_status != "":
		label += " · %s -> Healthy" % _status_label(cured_status)
	if str(gameplay.get("quantityPolicy", "single")) != "single" and consumed_quantity < requested_quantity:
		label += " · uses %s/%s" % [consumed_quantity, requested_quantity]

	return {
		"canApply": true,
		"label": label,
		"tooltip": "%s\nItems used: %s\n%s" % [pokemon.species, consumed_quantity, label],
		"usedQuantity": consumed_quantity,
		"previousHp": pokemon.current_hp,
		"currentHp": current_hp,
		"maxHp": max_hp,
		"previousStatus": _normalize_status(pokemon.status),
		"status": status,
		"revived": revived,
	}


static func _no_effect_label(fainted: bool, current_hp: int, max_hp: int, status: String) -> String:
	if fainted:
		return "Fainted"
	if current_hp >= max_hp and status == "":
		return "Full HP"
	return "No effect"


static func _no_effect_tooltip(pokemon: Pokemon, fainted: bool, current_hp: int, max_hp: int, status: String) -> String:
	if fainted:
		return "%s is fainted; this item cannot affect it." % pokemon.species
	if current_hp >= max_hp and status == "":
		return "%s is already at full HP." % pokemon.species
	if status != "":
		return "%s cannot cure %s." % [pokemon.species, _status_label(status).to_lower()]
	return "This item would have no effect on %s." % pokemon.species


static func _status_label(status: String) -> String:
	return str(STATUS_LABELS.get(_normalize_status(status), "Status"))


static func _normalize_status(value: String) -> String:
	match value.strip_edges().to_lower():
		"psn", "poison", "poisoned":
			return "psn"
		"tox", "toxic", "badly_poisoned", "badlypoisoned":
			return "tox"
		"brn", "burn", "burned":
			return "brn"
		"par", "paralysis", "paralyzed", "paralysed":
			return "par"
		"slp", "sleep", "sleeping", "asleep":
			return "slp"
		"frz", "freeze", "frozen":
			return "frz"
	return ""
