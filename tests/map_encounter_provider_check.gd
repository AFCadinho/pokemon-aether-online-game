extends SceneTree

const MapEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")

var failed := false


func _init() -> void:
	_check_map_level_encounter()
	_check_region_encounter()
	_check_region_type_filter()
	_check_fishing_alias()
	quit(1 if failed else 0)


func _check_map_level_encounter() -> void:
	var map := _MapWithEncounterChance.new()

	var encounter := MapEncounterProvider.resolve_wild_encounter(map, Vector2(16.0, 16.0), "grass")
	_check_true(bool(encounter.get("available", false)), "map encounter should be available")
	_check_equal(str(encounter.get("area_id", "")), "test_grass", "map area id")
	_check_equal(str(encounter.get("encounter_type", "")), "grass", "map encounter type")
	_check_float_approx(float(encounter.get("chance", 0.0)), 0.35, "map encounter chance")
	_check_true(bool(encounter.get("use_map_trigger", false)), "map encounter should use map trigger")
	map.free()


func _check_region_encounter() -> void:
	var map := Node2D.new()
	var regions := Node2D.new()
	regions.name = "EncounterRegions"
	map.add_child(regions)

	var region := _make_region("pond", Rect2(64.0, 64.0, 32.0, 32.0), "test_water", "surf", 0.22)
	regions.add_child(region)

	var encounter := MapEncounterProvider.resolve_wild_encounter(map, Vector2(80.0, 80.0), "surf")
	_check_true(bool(encounter.get("available", false)), "region encounter should be available")
	_check_equal(str(encounter.get("area_id", "")), "test_water", "region area id")
	_check_equal(str(encounter.get("encounter_type", "")), "surf", "region encounter type")
	_check_float_approx(float(encounter.get("chance", 0.0)), 0.22, "region encounter chance")
	_check_true(not bool(encounter.get("use_map_trigger", true)), "region encounter should use direct chance")
	map.free()


func _check_region_type_filter() -> void:
	var map := Node2D.new()
	var regions := Node2D.new()
	regions.name = "EncounterRegions"
	map.add_child(regions)
	regions.add_child(_make_region("grass_a", Rect2(0.0, 0.0, 32.0, 32.0), "test_grass", "grass", 1.0))

	var encounter := MapEncounterProvider.resolve_wild_encounter(map, Vector2(16.0, 16.0), "surf")
	_check_true(not bool(encounter.get("available", false)), "region should not match another encounter type")
	map.free()


func _check_fishing_alias() -> void:
	var map := Node2D.new()
	var regions := Node2D.new()
	regions.name = "EncounterRegions"
	map.add_child(regions)
	regions.add_child(_make_region("fishing_a", Rect2(0.0, 0.0, 32.0, 32.0), "test_fish", "fish", 1.0))

	var encounter := MapEncounterProvider.resolve_wild_encounter(map, Vector2(16.0, 16.0), "fishing")
	_check_true(bool(encounter.get("available", false)), "fishing should resolve to fish encounter type")
	_check_equal(str(encounter.get("encounter_type", "")), "fish", "fishing alias encounter type")
	map.free()


func _make_region(region_id: String, rect: Rect2, area_id: String, encounter_type: String, chance: float) -> Area2D:
	var area := Area2D.new()
	area.name = region_id
	area.position = rect.position + rect.size * 0.5
	area.set_meta("pao_placeholder_type", "encounter_region")
	area.set_meta("pao_resource_id", region_id)
	area.set_meta("pao_encounter_area_id", area_id)
	area.set_meta("pao_encounter_type", encounter_type)
	area.set_meta("pao_encounter_chance", chance)
	area.set_meta("pao_region_rect", rect)

	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size

	var collision := CollisionShape2D.new()
	collision.shape = rectangle
	area.add_child(collision)
	return area


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


class _MapWithEncounterChance:
	extends Node2D

	var grass_encounter_chance := 0.35

	func get_wild_encounter_area_id() -> String:
		return "test_grass"

	func should_trigger_wild_encounter(_encounter_type: String = "grass") -> bool:
		return true
