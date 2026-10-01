extends SceneTree

const PORT := "res://scenes/overworld/kanto/towns/vermilion_city/port_interior.tscn"
const CITY := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const DOCKS := "res://scenes/overworld/kanto/towns/vermilion_docks/vermilion_docks.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var port: Node = load(PORT).instantiate()
	var city: Node = load(CITY).instantiate()
	var docks: Node = load(DOCKS).instantiate()
	for map in [port, city, docks]:
		root.add_child(map)
	_check(port.lighting_profile == "indoor" and port.weather_profile == "disabled", "indoor lighting and weather")
	for path in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Tiles/Collision", "FloorVisibilityMask"]:
		_check(port.has_node(path), "required node " + path)
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(port.get_node("Visual"), "res://generated/tiled_visuals/vermilion_port_interior/vermilion_port_interior.visual.tileset.tres").is_empty(), "compact atlas is valid")
	var collision := port.get_node("Tiles/Collision") as TileMapLayer
	for name in ["FromCity", "FromDocks"]:
		var spawn := port.get_node("Spawns/" + name) as Node2D
		_check(collision.get_cell_source_id(collision.local_to_map(spawn.position)) == -1, name + " arrival is clear")
		for exit_node in port.get_node("Exits").get_children():
			_check(not exit_node.contains_world_position(spawn.global_position), name + " avoids immediate exit")
	for entry in [[city, "ToDocks", PORT, "FromCity"], [docks, "ToVermilionCity", PORT, "FromDocks"], [port, "ToCity", CITY, "FromDocks"], [port, "ToDocks", DOCKS, "FromVermilionCity"]]:
		var exit_node: Node = entry[0].get_node("Exits/" + entry[1])
		_check(exit_node.target_scene_path == entry[2] and exit_node.target_spawn_name == entry[3], "matching connection " + str(entry[1]))
		var target: Node = port if entry[2] == PORT else (city if entry[2] == CITY else docks)
		var spawn := target.get_node("Spawns/" + entry[3]) as Node2D
		for target_exit in target.get_node("Exits").get_children():
			_check(not target_exit.contains_world_position(spawn.global_position), "return arrival avoids exit loops")
		if target.has_method("is_water_tile_for_actor"):
			_check(not target.is_water_tile_for_actor(spawn.global_position, null), "return arrival is dry")
		var target_collision := target.get_node_or_null("Tiles/Collision") as TileMapLayer
		if target_collision != null:
			_check(target_collision.get_cell_source_id(target_collision.local_to_map(spawn.position)) == -1, "return arrival has no collision")
	var city_exit: Node = city.get_node("Exits/ToDocks")
	var city_collision := city.get_node("Tiles/Collision") as TileMapLayer
	var entrance := Vector2(1040, 2128)
	_check(city_exit.contains_world_position(entrance), "city entrance covers the visible port doorway")
	_check(city_collision.get_cell_source_id(city_collision.local_to_map(entrance)) == -1, "city doorway is reachable without collision changes")
	_check(not city.is_water_tile_for_actor(entrance, null), "city doorway is dry")
	_check(port.get_node("Exits/ToCity").transition_facing_direction == "down", "return to city faces away from the doorway")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(port.map_id), "port is registered")
	for id in ["kanto_vermilion_city__to_port_interior", "kanto_vermilion_docks__to_port_interior", "kanto_vermilion_city_port_interior__to_city", "kanto_vermilion_city_port_interior__to_docks"]:
		_check(catalog.transitions.has(id), "authorized transition " + id)
	for map in [port, city, docks]:
		map.free()
	print("VERMILION_PORT_INTERIOR ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
