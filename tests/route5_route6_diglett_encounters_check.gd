extends SceneTree

const ROUTE_5_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_5.tscn"
const ROUTE_6_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_6.tscn"
const DIGLETT_SCENES := [
	"res://scenes/overworld/kanto/caves/diglett_cave/route_2_entrance.tscn",
	"res://scenes/overworld/kanto/caves/diglett_cave/tunnel.tscn",
	"res://scenes/overworld/kanto/caves/diglett_cave/route_11_entrance.tscn",
]
const ROUTE_6_TRAINERS := [
	"kanto_route_6_bug_catcher_keigo",
	"kanto_route_6_camper_ricky",
	"kanto_route_6_picnicker_nancy",
	"kanto_route_6_bug_catcher_elijah",
	"kanto_route_6_picnicker_isabelle",
	"kanto_route_6_camper_jeff",
]

var failed := false


func _init() -> void:
	_check_map(ROUTE_5_SCENE, "kanto_route_5", "grass_encounter_chance")
	var route_6_metadata := FileAccess.get_file_as_string(ROUTE_6_SCENE)
	_check(route_6_metadata.contains('encounter_area_id = "kanto_route_6"'), "Route 6 uses its FRLG encounter table")
	_check(route_6_metadata.contains("grass_encounter_chance = 0.21"), "Route 6 has a grass chance fallback")
	var route_6_source := FileAccess.get_file_as_string(ROUTE_6_SCENE)
	_check(route_6_source.contains("surf_encounter_chance = 0.1"), "Route 6 has a surf chance fallback")
	for trainer_id in ROUTE_6_TRAINERS:
		_check(route_6_source.contains('trainer_id = "%s"' % trainer_id), "%s is configured on Route 6" % trainer_id)

	for scene_path in DIGLETT_SCENES:
		_check_map(scene_path, "kanto_digletts_cave", "cave_encounter_chance")
		var cave_map := _instantiate_map(scene_path)
		if cave_map != null:
			_check(str(cave_map.get("battle_environment_id")) == "cave", "%s uses cave battle environment" % scene_path)
			cave_map.free()

	quit(1 if failed else 0)


func _check_map(scene_path: String, expected_area_id: String, chance_property: String) -> void:
	var map := _instantiate_map(scene_path)
	if map == null:
		return
	_check(str(map.get("encounter_area_id")) == expected_area_id, "%s points at %s encounters" % [scene_path, expected_area_id])
	_check(float(map.get(chance_property)) > 0.0, "%s has a wild encounter chance fallback" % scene_path)
	map.free()


func _instantiate_map(scene_path: String) -> Node:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		_check(false, "%s loads as a scene" % scene_path)
		return null
	return packed_scene.instantiate()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
