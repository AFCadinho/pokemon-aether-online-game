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
	for x in range(10,14):
		for y in range(3,27):
			_check(collision.get_cell_source_id(Vector2i(x,y)) == -1, "clear central passage %s" % Vector2i(x,y))
	for cell in [Vector2i(0,0), Vector2i(3,4), Vector2i(7,10), Vector2i(8,17), Vector2i(5,11), Vector2i(16,22), Vector2i(4,23)]:
		_check(collision.get_cell_source_id(cell) != -1, "walls and furniture blocked %s" % cell)
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
