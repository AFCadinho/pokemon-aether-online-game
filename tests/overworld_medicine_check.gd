extends SceneTree

const Preview := preload("res://scripts/ui/bag_item_effect_preview.gd")
const OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.call("set_locale", "en")
	_check_preview_and_eligibility()
	_check_status_and_revive_previews()
	_check_overlay_contract()
	quit(1 if failed else 0)


func _check_preview_and_eligibility() -> void:
	var pokemon := Pokemon.new("Rattata", 10)
	pokemon.current_hp = 42
	pokemon.max_hp = 90
	pokemon.stats["hp"] = 90
	var potion := _gameplay("up_to_requested", [{"type":"heal_hp", "mode":"fixed", "amount":20}])
	var super_potion := _gameplay("up_to_requested", [{"type":"heal_hp", "mode":"fixed", "amount":50}])
	var max_potion := _gameplay("single", [{"type":"heal_hp", "mode":"full"}])

	_check(Preview.supports(potion), "generic medicine gameplay is recognized")
	var potion_preview: Dictionary = Preview.preview(pokemon, potion, 1)
	_check_equal(potion_preview.get("label"), "42/90 -> 62/90", "Potion preview uses authoritative metadata amount")
	var multi_preview: Dictionary = Preview.preview(pokemon, potion, 5)
	_check_equal(multi_preview.get("usedQuantity"), 3, "Potion preview caps useful quantity")
	_check_equal(multi_preview.get("currentHp"), 90, "multiple Potions cap at maximum HP")
	_check_equal(Preview.preview(pokemon, super_potion, 1).get("currentHp"), 90, "Super Potion preview uses 50 HP")
	_check_equal(Preview.preview(pokemon, max_potion, 5).get("usedQuantity"), 1, "full healing consumes at most one")

	pokemon.current_hp = 90
	var full_preview: Dictionary = Preview.preview(pokemon, potion, 1)
	_check_equal(full_preview.get("canApply"), false, "full HP target is ineligible")
	_check_equal(full_preview.get("label"), "Full HP", "full HP target explains ineligibility")


func _check_status_and_revive_previews() -> void:
	var pokemon := Pokemon.new("Rattata", 10)
	pokemon.current_hp = 70
	pokemon.max_hp = 90
	pokemon.stats["hp"] = 90
	pokemon.status = "psn"
	var antidote := _gameplay("single", [{"type":"cure_status", "statuses":["psn", "tox"]}])
	var burn_heal := _gameplay("single", [{"type":"cure_status", "statuses":["brn"]}])
	var full_restore := _gameplay("single", [
		{"type":"heal_hp", "mode":"full"},
		{"type":"cure_status", "statuses":["psn", "tox", "brn", "par", "slp", "frz"]},
	])

	_check_equal(Preview.preview(pokemon, antidote, 4).get("label"), "Poisoned -> Healthy", "status cure preview")
	_check_equal(Preview.preview(pokemon, burn_heal, 1).get("canApply"), false, "wrong status is ineligible")
	var restore_preview: Dictionary = Preview.preview(pokemon, full_restore, 3)
	_check_equal(restore_preview.get("currentHp"), 90, "Full Restore preview restores HP")
	_check_equal(restore_preview.get("status"), "", "Full Restore preview cures status")
	_check_equal(restore_preview.get("usedQuantity"), 1, "Full Restore consumes one")

	pokemon.current_hp = 0
	pokemon.status = ""
	var revive := _gameplay("single", [{"type":"revive", "hpPercent":50, "rounding":"floor", "minimumHp":1}])
	var revive_preview: Dictionary = Preview.preview(pokemon, revive, 5)
	_check_equal(revive_preview.get("label"), "Fainted -> 45/90", "Revive preview uses floor half HP")
	_check_equal(Preview.preview(pokemon, antidote, 1).get("canApply"), false, "status cure cannot target fainted Pokemon")


func _check_overlay_contract() -> void:
	var source := _read_text(OVERLAY_SCRIPT)
	_check(source.contains("BAG_ITEM_EFFECT_PREVIEW.supports"), "Bag recognizes gameplay effects generically")
	_check(source.contains("BAG_ITEM_EFFECT_PREVIEW.preview"), "Bag delegates medicine previews")
	_check(source.contains("PlayerSave.replace_party_from_state(party_value as Array)"), "successful use applies authoritative server party")
	_check(source.contains('"gameplay": gameplay'), "inventory normalization preserves gameplay metadata")
	_check(source.contains('func _is_trade_evolution_item_id'), "Bag recognizes the Linking Cord as a Pokemon item")
	_check(source.contains('func _present_item_trade_evolution'), "Bag presents an item-triggered evolution")
	_check(source.contains('await play_evolution_overlay(evolution)'), "item-triggered evolution uses the evolution overlay")
	_check(not source.contains("Restores 60 HP to one Pokemon."), "conflicting Super Potion 60 HP fallback is removed")
	_check(source.contains("bag_inventory_items = _normalize_bag_inventory_items(inventory_value)"), "successful use refreshes inventory")


func _gameplay(quantity_policy: String, effects: Array) -> Dictionary:
	return {
		"target": "pokemon",
		"contexts": ["field"],
		"quantityPolicy": quantity_policy,
		"effects": effects,
	}


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % message)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("FAIL %s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
