extends RefCounted

class_name BagItemEffectPreview

const SUPPORTED_EFFECT_TYPES := {
	"heal_hp": true,
	"cure_status": true,
	"revive": true,
	"change_ability": true,
}

const STATUS_LABELS := {
	"psn": "pokemon.status.poisoned",
	"tox": "pokemon.status.badly_poisoned",
	"brn": "pokemon.status.burned",
	"par": "pokemon.status.paralyzed",
	"slp": "pokemon.status.asleep",
	"frz": "pokemon.status.frozen",
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
	var ability_effect := _first_effect_of_type(gameplay, "change_ability")
	if not ability_effect.is_empty():
		return _preview_ability_change(pokemon, ability_effect)

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
		label = _text("ui.bag.preview.fainted_to", {"current": current_hp, "max": max_hp})
	elif cured_status != "" and pokemon.current_hp == current_hp:
		label = _text("ui.bag.preview.status_to_healthy", {"status": _status_label(cured_status)})
	elif cured_status != "":
		label += _text("ui.bag.preview.status_suffix", {"status": _status_label(cured_status)})
	if str(gameplay.get("quantityPolicy", "single")) != "single" and consumed_quantity < requested_quantity:
		label += _text("ui.bag.preview.uses_suffix", {
			"used": consumed_quantity,
			"requested": requested_quantity,
		})

	return {
		"canApply": true,
		"label": label,
		"tooltip": _text("ui.bag.preview.tooltip", {
			"pokemon": pokemon.species,
			"used": consumed_quantity,
			"result": label,
		}),
		"usedQuantity": consumed_quantity,
		"previousHp": pokemon.current_hp,
		"currentHp": current_hp,
		"maxHp": max_hp,
		"previousStatus": _normalize_status(pokemon.status),
		"status": status,
		"revived": revived,
	}


static func _preview_ability_change(pokemon: Pokemon, effect: Dictionary) -> Dictionary:
	var mode := str(effect.get("mode", "")).strip_edges().to_lower()
	var current_ability := str(pokemon.ability).strip_edges()
	var current_name := _ability_name(current_ability)
	var possible_abilities := _unique_ability_ids(pokemon.possible_abilities)

	# The backend publishes possibleAbilities in primary, secondary, hidden order.
	# An empty list can occur on a legacy payload; let the authoritative server
	# decide instead of blocking an otherwise valid item client-side.
	if possible_abilities.is_empty():
		return {
			"canApply": true,
			"label": _text(
				"ui.bag.preview.ability_hidden_generic"
				if mode == "hidden"
				else "ui.bag.preview.ability_cycle_generic",
				{"current": current_name}
			),
			"tooltip": _text("ui.bag.preview.ability_server_check", {
				"pokemon": pokemon.species,
				"current": current_name,
			}),
			"usedQuantity": 1,
		}

	if mode == "hidden":
		var hidden_ability := possible_abilities[-1] if possible_abilities.size() > 1 else ""
		if hidden_ability == "":
			return _ability_no_effect_preview(
				pokemon,
				"ui.bag.preview.no_hidden_ability",
				"ui.bag.preview.no_hidden_ability_tooltip"
			)
		var hidden_name := _ability_name(hidden_ability)
		if pokemon.hidden_ability and _normalize_ability_id(current_ability) == hidden_ability:
			return _ability_no_effect_preview(
				pokemon,
				"ui.bag.preview.hidden_ability_active",
				"ui.bag.preview.hidden_ability_active_tooltip",
				{"ability": hidden_name}
			)
		return {
			"canApply": true,
			"label": _text("ui.bag.preview.ability_change", {
				"current": current_name,
				"next": hidden_name,
			}),
			"tooltip": _text("ui.bag.preview.hidden_ability_tooltip", {
				"pokemon": pokemon.species,
				"current": current_name,
				"next": hidden_name,
			}),
			"usedQuantity": 1,
		}

	var unlocked_abilities := possible_abilities.duplicate()
	if not pokemon.hidden_ability and unlocked_abilities.size() > 1:
		unlocked_abilities.remove_at(unlocked_abilities.size() - 1)
	if unlocked_abilities.size() <= 1:
		return _ability_no_effect_preview(
			pokemon,
			"ui.bag.preview.no_alternative_ability",
			"ui.bag.preview.no_alternative_ability_tooltip"
		)

	var current_id := _normalize_ability_id(current_ability)
	var current_index := unlocked_abilities.find(current_id)
	var next_ability: String = unlocked_abilities[0]
	if current_index >= 0:
		next_ability = unlocked_abilities[(current_index + 1) % unlocked_abilities.size()]
	var next_name := _ability_name(next_ability)
	return {
		"canApply": next_ability != current_id,
		"label": _text("ui.bag.preview.ability_change", {
			"current": current_name,
			"next": next_name,
		}),
		"tooltip": _text("ui.bag.preview.ability_change_tooltip", {
			"pokemon": pokemon.species,
			"current": current_name,
			"next": next_name,
		}),
		"usedQuantity": 1,
	}


static func _ability_no_effect_preview(
	pokemon: Pokemon,
	label_key: String,
	tooltip_key: String,
	values: Dictionary = {}
) -> Dictionary:
	var localized_values := values.duplicate()
	localized_values["pokemon"] = pokemon.species
	return {
		"canApply": false,
		"label": _text(label_key, localized_values),
		"tooltip": _text(tooltip_key, localized_values),
		"usedQuantity": 0,
	}


static func _first_effect_of_type(gameplay: Dictionary, effect_type: String) -> Dictionary:
	for effect_value: Variant in gameplay.get("effects", []):
		if not (effect_value is Dictionary):
			continue
		var effect := effect_value as Dictionary
		if str(effect.get("type", "")).strip_edges().to_lower() == effect_type:
			return effect
	return {}


static func _unique_ability_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		var ability_id := _normalize_ability_id(str(value))
		if ability_id != "" and not result.has(ability_id):
			result.append(ability_id)
	return result


static func _normalize_ability_id(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


static func _ability_name(ability_id: String) -> String:
	var normalized_id := _normalize_ability_id(ability_id)
	var fallback := " ".join(normalized_id.split("-", false)).capitalize()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var localizer := (main_loop as SceneTree).root.get_node_or_null("ContentLocalization")
		if localizer != null and localizer.has_method("display_name"):
			return str(localizer.call("display_name", "abilities", normalized_id, fallback))
	return fallback


static func _no_effect_label(fainted: bool, current_hp: int, max_hp: int, status: String) -> String:
	if fainted:
		return _text("ui.bag.preview.fainted")
	if current_hp >= max_hp and status == "":
		return _text("ui.bag.preview.full_hp")
	return _text("ui.bag.preview.no_effect")


static func _no_effect_tooltip(pokemon: Pokemon, fainted: bool, current_hp: int, max_hp: int, status: String) -> String:
	if fainted:
		return _text("ui.bag.preview.fainted_tooltip", {"pokemon": pokemon.species})
	if current_hp >= max_hp and status == "":
		return _text("ui.bag.preview.full_hp_tooltip", {"pokemon": pokemon.species})
	if status != "":
		return _text("ui.bag.preview.cannot_cure", {
			"pokemon": pokemon.species,
			"status": _status_label(status).to_lower(),
		})
	return _text("ui.bag.preview.no_effect_tooltip", {"pokemon": pokemon.species})


static func _status_label(status: String) -> String:
	var key := str(STATUS_LABELS.get(_normalize_status(status), "ui.bag.preview.status"))
	return _text(key)


static func _text(key: String, values: Dictionary = {}) -> String:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var manager := (main_loop as SceneTree).root.get_node_or_null("LocalizationManager")
		if manager != null:
			return str(manager.call("text", key, values))
	return key


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
