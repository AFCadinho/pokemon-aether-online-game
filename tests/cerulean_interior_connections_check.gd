extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const INTERIORS := [
	{
		"id": "house_1",
		"scene": "res://scenes/overworld/kanto/towns/cerulean_city/house1.tscn",
		"map_id": "kanto_cerulean_city_house_1",
		"city_spawn": "FromHouse1",
		"city_exit": "ToHouse1",
		"interior_spawn": "FromCeruleanCity",
		"interior_exit": "ToCeruleanCity",
		"template": "BlueHouseTemplate",
		"spawn_position": Vector2(784, 944),
	},
	{
		"id": "pokemon_center",
		"scene": "res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
		"map_id": "kanto_cerulean_city_pokemon_center",
		"city_spawn": "FromPokemonCenter",
		"city_exit": "ToPokemonCenter",
		"interior_spawn": "FromOutside",
		"interior_exit": "ToOutside",
		"template": "Visuals",
		"spawn_position": Vector2(1072, 1360),
	},
	{
		"id": "gym",
		"scene": "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn",
		"map_id": "kanto_cerulean_city_gym",
		"city_spawn": "FromGym",
		"city_exit": "ToGym",
		"interior_spawn": "FromCeruleanCity",
		"interior_exit": "ToCeruleanCity",
		"template": "PewterGymTemplate/Visuals",
		"spawn_position": Vector2(1584, 1360),
	},
	{
		"id": "bike_store",
		"scene": "res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn",
		"map_id": "kanto_cerulean_city_bike_store",
		"city_spawn": "FromBikeStore",
		"city_exit": "ToBikeStore",
		"interior_spawn": "FromCeruleanCity",
		"interior_exit": "ToCeruleanCity",
		"template": "BlueHouseTemplate",
		"spawn_position": Vector2(656, 1680),
	},
	{
		"id": "house_2",
		"scene": "res://scenes/overworld/kanto/towns/cerulean_city/house2.tscn",
		"map_id": "kanto_cerulean_city_house_2",
		"city_spawn": "FromHouse2",
		"city_exit": "ToHouse2",
		"interior_spawn": "FromCeruleanCity",
		"interior_exit": "ToCeruleanCity",
		"template": "BlueHouseTemplate",
		"spawn_position": Vector2(1168, 1680),
	},
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := await _instantiate(CITY_SCENE)
	for interior_value: Variant in INTERIORS:
		var interior_data := interior_value as Dictionary
		await _check_interior(city, interior_data)
	_check_catalog_interior_count()
	city.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_catalog_interior_count() -> void:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://generated/world_access_catalog.json")
	)
	_check(parsed is Dictionary, "World access catalog remains valid JSON")
	if not parsed is Dictionary:
		return
	var areas := (parsed as Dictionary).get("areas", {}) as Dictionary
	var transitions := (parsed as Dictionary).get("transitions", {}) as Dictionary
	var cerulean_interiors := 0
	for area_value: Variant in areas.values():
		var area := area_value as Dictionary
		if (
			str(area.get("locationGroupId", "")) == "kanto_cerulean_city"
			and str(area.get("areaType", "")) == "interior"
		):
			cerulean_interiors += 1
	_check(cerulean_interiors == 5, "Cerulean City exposes exactly five interiors in the world catalog")
	for interior_value: Variant in INTERIORS:
		var interior_data := interior_value as Dictionary
		var map_id := str(interior_data.get("map_id", ""))
		var scene_path := str(interior_data.get("scene", ""))
		var spawn_marker := str(interior_data.get("interior_spawn", ""))
		var area := areas.get(map_id, {}) as Dictionary
		_check(not area.is_empty(), "%s is registered as a world-access area" % map_id)
		_check(str(area.get("scenePath", "")) == scene_path, "%s exposes its canonical scene path" % map_id)
		var spawn_points := area.get("spawnPoints", {}) as Dictionary
		var spawn_point := spawn_points.get(spawn_marker.to_snake_case(), {}) as Dictionary
		_check(str(spawn_point.get("spawnMarker", "")) == spawn_marker, "%s exposes its arrival marker for teleport" % map_id)
		_check(bool(spawn_point.get("safeForStaffTeleport", false)), "%s arrival marker is staff-teleport safe" % map_id)
		var enter_transition_id := "kanto_cerulean_city__to_%s" % str(interior_data.get("id", ""))
		var enter_transition := transitions.get(enter_transition_id, {}) as Dictionary
		_check(str(enter_transition.get("destinationAreaId", "")) == map_id, "%s is authorized by the city door transition" % map_id)
		var return_transition := transitions.get("%s__to_outside" % map_id, {}) as Dictionary
		_check(str(return_transition.get("destinationAreaId", "")) == "kanto_cerulean_city", "%s is authorized to return outside" % map_id)


func _check_interior(city: Node, data: Dictionary) -> void:
	var label := str(data.get("id", "interior"))
	var scene_path := str(data.get("scene", ""))
	var city_spawn_name := str(data.get("city_spawn", ""))
	var city_exit_name := str(data.get("city_exit", ""))
	var interior_spawn_name := str(data.get("interior_spawn", ""))
	var interior_exit_name := str(data.get("interior_exit", ""))
	var city_spawn := city.get_node_or_null("Spawns/%s" % city_spawn_name) as Marker2D
	var city_exit := city.get_node_or_null("Exits/%s" % city_exit_name)

	_check(city_spawn != null, "Cerulean City has the %s outside spawn" % label)
	_check(city_exit != null, "Cerulean City has the %s door exit" % label)
	if city_spawn != null:
		_check(city_spawn.position == data.get("spawn_position"), "%s spawn is placed at its matching exterior door" % label)
		var city_collision := city.find_map_tilemap_layer("Collision") as TileMapLayer
		var spawn_cell := city_collision.local_to_map(city_spawn.position)
		_check(city_collision.get_cell_source_id(spawn_cell) < 0, "%s outside spawn is walkable" % label)
	if city_exit != null:
		_check(str(city_exit.get("target_scene_path")) == scene_path, "%s door targets its interior scene" % label)
		_check(str(city_exit.get("target_spawn_name")) == interior_spawn_name, "%s door targets its interior arrival" % label)

	var interior := await _instantiate(scene_path)
	_check(str(interior.get("map_id")) == str(data.get("map_id", "")), "%s exposes unique map metadata" % label)
	_check(str(interior.get("world_access_group_id")) == "kanto_cerulean_city", "%s belongs to Cerulean City" % label)
	_check(interior.get_node_or_null(str(data.get("template", ""))) != null, "%s uses its requested visual template" % label)
	_check(interior.find_map_tilemap_layer("Collision") != null, "%s resolves an interior collision layer" % label)
	if str(data.get("template", "")) == "BlueHouseTemplate":
		_check(
			interior.get_node_or_null("BlueHouseTemplate/PokeAetherHouseTemplateBlue") != null,
			"%s uses the imported blue house visual" % label
		)
		_check(
			interior.get_node_or_null("BlueHouseTemplate/Collision") != null,
			"%s uses the shared house collision template" % label
		)
	_check(interior.get_node_or_null("Spawns/%s" % interior_spawn_name) != null, "%s has an interior arrival" % label)
	var interior_exit := interior.get_node_or_null("Exits/%s" % interior_exit_name)
	_check(interior_exit != null, "%s has a return exit" % label)
	if interior_exit != null:
		_check(str(interior_exit.get("target_scene_path")) == CITY_SCENE, "%s returns to Cerulean City" % label)
		_check(str(interior_exit.get("target_spawn_name")) == city_spawn_name, "%s returns to its matching outside spawn" % label)
	if label == "gym":
		_check(interior.get_node_or_null("PewterGymTemplate/Entities") == null, "Cerulean Gym does not inherit Pewter NPC content")
	interior.queue_free()
	await process_frame


func _instantiate(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path)
	if packed == null:
		return Node.new()
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	return instance


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
