extends SceneTree

const MapEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")
const PalletTownScript := preload("res://scripts/world/kanto/towns/pallet_town.gd")

var failed := false


func _init() -> void:
	var pallet_town := PalletTownScript.new()
	_check_true(pallet_town != null, "Pallet Town scene instantiates")
	if pallet_town == null:
		quit(1)
		return

	_check_equal(str(pallet_town.call("get_wild_encounter_area_id")), "kanto_pallet_town", "Pallet Town encounter area id")
	_check_float_approx(float(pallet_town.call("get_wild_encounter_chance", "surf")), 0.1, "Pallet Town surf chance")
	_check_float_approx(float(pallet_town.call("get_wild_encounter_chance", "fish")), 1.0, "Pallet Town fish chance")
	_check_float_approx(float(pallet_town.call("get_wild_encounter_chance", "grass")), 0.0, "Pallet Town grass chance")

	var surf_encounter := MapEncounterProvider.resolve_wild_encounter(pallet_town, Vector2(320.0, 896.0), "surf")
	_check_true(bool(surf_encounter.get("available", false)), "Pallet Town surf encounter resolves")
	_check_equal(str(surf_encounter.get("area_id", "")), "kanto_pallet_town", "Pallet Town surf area")
	_check_equal(str(surf_encounter.get("encounter_type", "")), "surf", "Pallet Town surf type")

	var old_rod_encounter := MapEncounterProvider.resolve_wild_encounter(pallet_town, Vector2(320.0, 896.0), "fishing")
	_check_true(bool(old_rod_encounter.get("available", false)), "Pallet Town fishing encounter resolves")
	_check_equal(str(old_rod_encounter.get("encounter_type", "")), "old_rod", "Pallet Town fishing alias")
	_check_float_approx(float(pallet_town.call("get_wild_encounter_chance", "good_rod")), 1.0, "Pallet Town Good Rod chance")
	_check_float_approx(float(pallet_town.call("get_wild_encounter_chance", "super_rod")), 1.0, "Pallet Town Super Rod chance")

	pallet_town.free()
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return

	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _check_float_approx(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
