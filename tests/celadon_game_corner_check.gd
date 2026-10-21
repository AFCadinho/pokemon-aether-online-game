extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const SCENE_PATH := DIRECTORY + "game_corner.tscn"
const MAP_ID := "kanto_celadon_game_corner"
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var corner := (load(SCENE_PATH) as PackedScene).instantiate()
	var city := (load(DIRECTORY + "celadon_city.tscn") as PackedScene).instantiate()
	var spawn := corner.get_node("Spawns/FromOutside") as Marker2D
	_check(corner.map_id == MAP_ID and corner.world_access_group_id == city.map_id, "Game Corner shares Celadon access settings")
	_check(corner.world_access_area_type == "interior" and corner.lighting_profile == "indoor" and corner.weather_profile == "disabled", "Indoor lighting and weather")
	# Black canvas padding is not public floor. Flood beyond the map bounds
	# to prove the actual playable floor is enclosed.
	var seat_count := 0
	for bank: Vector3i in [Vector3i(3, 8, 3), Vector3i(9, 9, 3), Vector3i(17, 9, 3), Vector3i(23, 8, 3), Vector3i(6, 13, 4), Vector3i(20, 13, 4)]:
		for y in range(bank.y, bank.y + bank.z):
			for x: int in [bank.x - 1, bank.x + 2]:
				seat_count += 1
	_check(seat_count == 40, "All forty playing positions were checked")
	_check(corner.get_node("Visual/Objects").z_index < corner.get_node("Entities").z_index, "Cushions draw below the player")
	var entrance := city.get_node("Exits/ToGameCorner")
	var exit_node := corner.get_node("Exits/ToOutside")
	var city_spawn := city.get_node("Spawns/FromGameCorner") as Marker2D
	_check(entrance.target_scene_path == SCENE_PATH and entrance.target_spawn_name == "FromOutside", "City door enters Game Corner")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromGameCorner", "Game Corner returns to its own city door")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Arrivals face away from their return triggers")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "Arrivals avoid immediate bounce-back")
	_check(entrance.contains_world_position(Vector2(1264, 864)), "Entry covers the upper half of the visible city doorway at (39,27)")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID) and catalog.areas[MAP_ID].locationGroupId == city.map_id, "Server knows this city interior")
	for pair: Array in [[entrance, corner, spawn], [exit_node, city, city_spawn]]:
		var transition: Area2D = pair[0]
		_check(transition.is_connected("body_entered", Callable(transition, "_on_body_entered")), "Player entry signal is connected")
		_check(catalog.transitions.has(transition.transition_id), "Transition is registered on the server")
		var destination: Dictionary = catalog.transitions[transition.transition_id].destination
		_check(destination.mapId == pair[1].map_id and destination.spawnMarker == str(pair[2].name), "Canonical server arrival marker")
		_check(destination.position == {"x": pair[2].position.x, "y": pair[2].position.y}, "Server arrival matches scene coordinates")
	_check(corner.get_node("Exits").get_child_count() == 2, "City and Rocket Hideout are connected")
	_check(LOADER.module_for_scene(SCENE_PATH) == LOADER.EXTENDED_MODULE_NAME, "Browser can load Game Corner")
	var errors: Array[String] = VALIDATOR.new().validate(corner.get_node("Visual"), "res://generated/tiled_visuals/celadon_game_corner/celadon_game_corner.visual.tileset.tres")
	_check(errors.is_empty(), "Imported atlas layout: " + str(errors))
	corner.free()
	city.free()
	print("CELADON_GAME_CORNER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
