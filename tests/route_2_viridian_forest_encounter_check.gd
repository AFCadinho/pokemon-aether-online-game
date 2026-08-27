extends SceneTree

const MapEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")

const MAP_CASES: Array[Dictionary] = [
	{
		"scene_path": "res://scenes/overworld/kanto/routes/kanto_route_2.tscn",
		"area_id": "kanto_route_2",
		"label": "Route 2",
	},
	{
		"scene_path": "res://scenes/overworld/kanto/routes/viridian_forest.tscn",
		"area_id": "kanto_viridian_forest",
		"label": "Viridian Forest",
	},
	{
		"scene_path": "res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
		"area_id": "kanto_route_24",
		"label": "Route 24",
	},
]

var failed := false


func _init() -> void:
	for map_case: Dictionary in MAP_CASES:
		_check_map_encounter(map_case)
	quit(1 if failed else 0)


func _check_map_encounter(map_case: Dictionary) -> void:
	var scene_source := FileAccess.get_file_as_string(str(map_case["scene_path"]))
	_check_true(scene_source != "", "%s scene source should load" % map_case["label"])
	if scene_source == "":
		return

	var expected_area_assignment := 'encounter_area_id = "%s"' % map_case["area_id"]
	_check_true(scene_source.contains(expected_area_assignment), "%s scene should configure its encounter area" % map_case["label"])
	_check_true(scene_source.contains("grass_encounter_chance = 0.21"), "%s scene should configure its fallback encounter chance" % map_case["label"])
	if str(map_case["area_id"]) == "kanto_route_24":
		_check_true(
			scene_source.contains('[node name="TallGrass" type="TileMapLayer" parent="Tiles"]'),
			"Route 24 should expose a TallGrass encounter mask"
		)
		_check_true(
			scene_source.contains('[node name="Water" type="TileMapLayer" parent="Tiles"'),
			"Route 24 should retain its semantic Water layer for Surf and fishing"
		)
	if str(map_case["area_id"]) == "kanto_route_2":
		_check_true(
			scene_source.contains('[node name="NPCs" type="Node2D" parent="Entities"'),
			"Route 2 should expose the Entities/NPCs container"
		)
		_check_true(
			scene_source.contains('[node name="Players" type="Node2D" parent="Entities"'),
			"Route 2 should expose the Entities/Players container"
		)

	var map := MapMetadataScript.new()
	map.encounter_area_id = str(map_case["area_id"])
	map.grass_encounter_chance = 0.21
	var encounter := MapEncounterProvider.resolve_wild_encounter(map, Vector2.ZERO, "grass")
	_check_true(bool(encounter.get("available", false)), "%s grass encounter should be available" % map_case["label"])
	_check_equal(str(encounter.get("area_id", "")), str(map_case["area_id"]), "%s encounter area id" % map_case["label"])
	_check_float_approx(float(encounter.get("chance", 0.0)), 0.21, "%s encounter chance" % map_case["label"])
	_check_true(bool(encounter.get("use_map_trigger", false)), "%s should use its map trigger" % map_case["label"])
	map.free()


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
