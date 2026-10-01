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
	_check(docks.get_node("Visual").get_meta("tiled_visual_map").width == 75 and docks.get_node("Visual").get_meta("tiled_visual_map").height == 30, "new port exterior size")
	_check(validator.validate(docks.get_node("Visual"), "res://generated/tiled_visuals/vermilion_port_exterior/vermilion_port_exterior.visual.tileset.tres").is_empty(), "port exterior compact atlas is valid")
	_check(docks.get_node("Spawns/FromVermilionCity").position == Vector2(1040,48), "port arrival matches TMX tile 32,1")
	_check(docks.get_node("Exits/ToVermilionCity").contains_world_position(Vector2(1040,16)), "port north exit matches TMX")
	_check(not docks.is_water_tile_for_actor(Vector2(1424,624), null), "gangway approach tile is dry")
	for path in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "Tiles/Collision"]:
		_check(docks.has_node(path), "port exterior required node " + path)
	var collision := port.get_node("Tiles/Collision") as TileMapLayer
	for name in ["FromNorth", "FromSouth"]:
		var spawn := port.get_node("Spawns/" + name) as Node2D
		_check(collision.get_cell_source_id(collision.local_to_map(spawn.position)) == -1, name + " arrival is clear")
		for exit_node in port.get_node("Exits").get_children():
			_check(not exit_node.contains_world_position(spawn.global_position), name + " avoids immediate exit")
	for entry in [[city, "ToPortNorth", PORT, "FromNorth"], [city, "ToPortSouth", PORT, "FromSouth"], [city, "ToDocks", DOCKS, "FromVermilionCity"], [docks, "ToVermilionCity", CITY, "FromDocks"], [port, "ToNorth", CITY, "FromPortNorth"], [port, "ToSouth", CITY, "FromPortSouth"]]:
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
	var city_collision := city.get_node("Tiles/Collision") as TileMapLayer
	for entry in [["ToPortNorth", Vector2(1040, 1904), "down"], ["ToPortSouth", Vector2(1040, 2128), "up"], ["ToDocks", Vector2(1040, 2224), "down"]]:
		var city_exit: Node = city.get_node("Exits/" + entry[0])
		_check(city_exit.contains_world_position(entry[1]), "entrance covers " + str(entry[0]))
		_check(city_collision.get_cell_source_id(city_collision.local_to_map(entry[1])) == -1, "entrance is walkable " + str(entry[0]))
		_check(not city.is_water_tile_for_actor(entry[1], null), "entrance is dry " + str(entry[0]))
		_check(city_exit.transition_facing_direction == entry[2], "arrival faces into destination " + str(entry[0]))
	_check(port.get_node("Spawns/FromNorth").position == Vector2(368,208), "north entry arrives in north of room")
	_check(port.get_node("Spawns/FromSouth").position == Vector2(368,816), "south entry arrives in south of room")
	_check(port.get_node("Exits/ToNorth").transition_facing_direction == "up", "north return faces out")
	_check(port.get_node("Exits/ToSouth").transition_facing_direction == "down", "south return faces out")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(port.map_id), "port is registered")
	for id in ["kanto_vermilion_city__to_port_interior_north", "kanto_vermilion_city__to_port_interior_south", "kanto_vermilion_city_port_interior__to_city_north", "kanto_vermilion_city_port_interior__to_city_south", "kanto_vermilion_city__to_docks", "kanto_vermilion_docks__to_city"]:
		_check(catalog.transitions.has(id), "authorized transition " + id)
	for map in [port, city, docks]:
		map.free()
	print("VERMILION_PORT_INTERIOR ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
