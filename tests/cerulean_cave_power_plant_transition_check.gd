extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"

var failed := false


func _initialize() -> void:
	var payload_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_expect(payload_value is Dictionary, "World access catalog is valid JSON")
	if not payload_value is Dictionary:
		quit(1)
		return

	var payload := payload_value as Dictionary
	var areas := payload.get("areas", {}) as Dictionary
	var transitions := payload.get("transitions", {}) as Dictionary
	for map_id in [
		"kanto_cerulean_cave",
		"kanto_cerulean_cave_2f",
		"kanto_cerulean_cave_b1f",
		"kanto_power_plant",
	]:
		_expect(areas.has(map_id), "%s is catalogued for staff teleport" % map_id)

	_check_transition(
		transitions,
		"kanto_cerulean_city__to_cerulean_cave",
		"kanto_cerulean_city",
		"kanto_cerulean_cave",
		"FromCerulean"
	)
	_check_transition(
		transitions,
		"kanto_cerulean_cave__to_cerulean_city",
		"kanto_cerulean_cave",
		"kanto_cerulean_city",
		"FromCeruleanCave"
	)

	for stair in ["A", "B", "C", "D", "E", "F"]:
		var suffix: String = stair.to_lower()
		_check_transition(
			transitions,
			"kanto_cerulean_cave__to_2f_%s" % suffix,
			"kanto_cerulean_cave",
			"kanto_cerulean_cave_2f",
			"From1F%s" % stair
		)
		_check_transition(
			transitions,
			"kanto_cerulean_cave_2f__to_1f_%s" % suffix,
			"kanto_cerulean_cave_2f",
			"kanto_cerulean_cave",
			"From2F%s" % stair
		)
	for stair in ["G", "H"]:
		var suffix: String = stair.to_lower()
		_check_transition(
			transitions,
			"kanto_cerulean_cave__to_b1f_%s" % suffix,
			"kanto_cerulean_cave",
			"kanto_cerulean_cave_b1f",
			"From1F%s" % stair
		)
		_check_transition(
			transitions,
			"kanto_cerulean_cave_b1f__to_1f_%s" % suffix,
			"kanto_cerulean_cave_b1f",
			"kanto_cerulean_cave",
			"FromB1F%s" % stair
		)

	_check_transition(
		transitions,
		"kanto_route_10__to_power_plant",
		"kanto_route_10",
		"kanto_power_plant",
		"FromRoute10"
	)
	_check_transition(
		transitions,
		"kanto_power_plant__to_route_10",
		"kanto_power_plant",
		"kanto_route_10",
		"FromPowerPlant"
	)
	_check_transition(
		transitions,
		"kanto_power_plant__to_route_10_northwest",
		"kanto_power_plant",
		"kanto_route_10",
		"FromPowerPlant"
	)

	var indoor_scenes := [
		"res://scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn",
		"res://scenes/overworld/kanto/caves/cerulean_cave/2f.tscn",
		"res://scenes/overworld/kanto/caves/cerulean_cave/b1f.tscn",
		"res://scenes/overworld/kanto/interiors/power_plant.tscn",
		"res://scenes/overworld/kanto/routes/route5/daycare.tscn",
		"res://scenes/overworld/kanto/interiors/underground_path/route_5_entrance.tscn",
		"res://scenes/overworld/kanto/interiors/underground_path/route_6_entrance.tscn",
		"res://scenes/overworld/kanto/interiors/underground_path/tunnel.tscn",
		"res://scenes/overworld/kanto/caves/diglett_cave/route_2_entrance.tscn",
		"res://scenes/overworld/kanto/caves/diglett_cave/route_11_entrance.tscn",
	]
	for scene_path in indoor_scenes:
		var source := FileAccess.get_file_as_string(scene_path)
		_expect(
			source.contains("res://scripts/world/floor_visibility_mask.gd"),
			"Indoor scene has a floor visibility mask: %s" % scene_path
		)
		_expect(
			source.contains("FloorVisibilityMask") and source.contains("constrain_camera_to_active_floor = true"),
			"Indoor scene clips outside its active floor: %s" % scene_path
		)

	_expect(
		FileAccess.get_file_as_string(
			"res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
		).contains("res://scripts/world/floor_visibility_mask.gd"),
		"Pokémon Centers inherit their indoor floor mask from the shared template"
	)

	if failed:
		quit(1)
		return
	print("Cerulean Cave, Power Plant and Kanto indoor masks verified.")
	quit(0)


func _check_transition(
	transitions: Dictionary,
	transition_id: String,
	source_map_id: String,
	destination_map_id: String,
	spawn_marker: String
) -> void:
	var transition_value: Variant = transitions.get(transition_id, null)
	_expect(transition_value is Dictionary, "Transition exists: %s" % transition_id)
	if not transition_value is Dictionary:
		return
	var transition := transition_value as Dictionary
	var destination := transition.get("destination", {}) as Dictionary
	_expect(
		transition.get("sourceMapId", "") == source_map_id,
		"Transition source is correct: %s" % transition_id
	)
	_expect(
		transition.get("destinationAreaId", "") == destination_map_id,
		"Transition destination is correct: %s" % transition_id
	)
	_expect(
		destination.get("spawnMarker", "") == spawn_marker,
		"Transition landing is correct: %s" % transition_id
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failed = true
		push_error("FAIL: %s" % message)
