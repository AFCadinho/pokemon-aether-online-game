extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const MapEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")
const CeruleanCityScript := preload("res://scripts/world/kanto/towns/cerulean_city.gd")

var failed := false


func _init() -> void:
	var city := CeruleanCityScript.new()
	city.set("encounter_area_id", "kanto_cerulean_city")
	city.set("grass_encounter_chance", 0.21)
	_check_equal(str(city.get("encounter_area_id")), "kanto_cerulean_city", "Cerulean encounter area id")
	_check_float_approx(float(city.call("get_wild_encounter_chance", "grass")), 0.21, "Cerulean grass chance")
	_check_float_approx(float(city.call("get_wild_encounter_chance", "surf")), 0.1, "Cerulean Surf chance")

	var city_source := FileAccess.get_file_as_string(CITY_SCENE)
	_check_true(city_source.contains('encounter_area_id = "kanto_cerulean_city"'), "Cerulean scene selects its encounter table")
	_check_true(city_source.contains("grass_encounter_chance = 0.21"), "Cerulean scene enables grass encounters")
	_check_true(
		city_source.contains('[node name="TallGrass" type="TileMapLayer" parent="Tiles"')
		and city_source.contains("tile_map_data = PackedByteArray"),
		"Cerulean exposes encounter tall grass"
	)

	for encounter_type: String in ["grass", "surf", "old_rod", "good_rod", "super_rod"]:
		var encounter := MapEncounterProvider.resolve_wild_encounter(city, Vector2.ZERO, encounter_type)
		_check_true(bool(encounter.get("available", false)), "Cerulean %s encounter resolves" % encounter_type)
		_check_equal(str(encounter.get("area_id", "")), "kanto_cerulean_city", "Cerulean %s area" % encounter_type)
		_check_equal(str(encounter.get("encounter_type", "")), encounter_type, "Cerulean %s type" % encounter_type)

	city.free()
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
