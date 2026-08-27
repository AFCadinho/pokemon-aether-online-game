extends SceneTree

const POPULATION := {
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn": {
		"Entities/NPCs/PatrolOfficer": "kanto_cerulean_city_patrol_officer",
		"Entities/NPCs/WaterwayVisitorMaya": "kanto_cerulean_city_waterway_visitor_maya",
		"Entities/NPCs/BikeEnthusiastTheo": "kanto_cerulean_city_bike_enthusiast_theo",
		"Entities/Pokemon/Squirtle": "kanto_cerulean_city_squirtle_1",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/house1.tscn": {
		"Entities/NPCs/OnixTrainer": "kanto_cerulean_city_house_1_onix_trainer",
		"Entities/Pokemon/Onix": "kanto_cerulean_city_house_1_onix_1",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/house2.tscn": {
		"Entities/NPCs/Resident": "kanto_cerulean_city_house_2_resident",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn": {
		"Entities/NPCs/BikeShopOwner": "kanto_cerulean_city_bike_store_owner",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn": {
		"Entities/NPCs/PartnerMoveTutor": "kanto_cerulean_city_pokemon_center_move_tutor",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn": {
		"Entities/NPCs/GymGuide": "kanto_cerulean_city_gym_guide",
		"Entities/NPCs/GymLeaderMisty": "kanto_alpha_gym_misty",
		"Entities/Pokemon/Staryu": "kanto_cerulean_city_gym_staryu_1",
	},
}

const COLLISION_PATHS := {
	"cerulean_city.tscn": "Tiles/Collision",
	"house1.tscn": "BlueHouseTemplate/Collision",
	"house2.tscn": "BlueHouseTemplate/Collision",
	"bike_store.tscn": "BlueHouseTemplate/Collision",
	"pokemon_center.tscn": "Collision",
	"cerulean_gym.tscn": "PewterGymTemplate/Collision",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in POPULATION:
		_check_scene(scene_path, POPULATION[scene_path])
	quit(1 if failed else 0)


func _check_scene(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var map := packed.instantiate()
	root.add_child(map)
	var collision_path := str(COLLISION_PATHS[scene_path.get_file()])
	var collision := map.get_node_or_null(collision_path) as TileMapLayer
	_check(collision != null, "%s exposes collision data" % scene_path.get_file())
	for node_path_value: Variant in expected:
		var node_path := str(node_path_value)
		var entity := map.get_node_or_null(node_path) as Node2D
		_check(entity != null, "%s places %s" % [scene_path.get_file(), node_path.get_file()])
		if entity == null:
			continue
		var expected_id := str(expected[node_path_value])
		var actual_id := str(entity.get("overworld_pokemon_id")) if "/Pokemon/" in node_path else str(entity.get("npc_id"))
		_check(actual_id == expected_id, "%s uses its canonical content ID" % node_path.get_file())
		if collision != null:
			var cell := collision.local_to_map(collision.to_local(entity.global_position))
			_check(collision.get_cell_source_id(cell) == -1, "%s stands on a walkable tile" % node_path.get_file())
	var misty := map.get_node_or_null("Entities/NPCs/GymLeaderMisty")
	if misty != null:
		_check(str(misty.get("trainer_id")) == "kanto_alpha_gym_misty", "Misty uses the registered Cerulean alpha battle")
		_check(misty.get("npc_profile") != null, "Misty has her Cascade Badge profile")
	map.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
