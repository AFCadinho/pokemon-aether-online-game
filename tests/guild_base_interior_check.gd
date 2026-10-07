extends SceneTree

var failed := false
const ROOM_ROOT := "res://scenes/overworld/kanto/guild_base/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var rooms: Dictionary = {}
	for room: String in ["main_hall", "left_room", "right_room", "elevator"]:
		var map: Node2D = load(ROOM_ROOT + room + ".tscn").instantiate()
		map.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:" + room)
		root.add_child(map)
		rooms[room] = map
		_check(map.get_map_id() == "guild_base:kanto_vermilion_city:7:" + room, room + " keeps server instance identity")
		_check(not map.allows_land_mounts(), room + " blocks riding indoors")
		_check(map.get_weather_profile() == "disabled", room + " excludes exterior weather")
		var collision := map.get_node("Collision") as TileMapLayer
		_check(collision.tile_set != null and collision.get_used_cells().size() > 0, room + " builds physical terrain collision")
		_check(collision.get_cell_tile_data(Vector2i(-1, -1)).get_collision_polygons_count(0) == 1, room + " supplies a physical blocking polygon")
		var start := Vector2i((map.get_node("Spawns").get_child(0) as Node2D).position / 32.0)
		for spawn: Node2D in map.get_node("Spawns").get_children():
			var tile := Vector2i(spawn.position / 32.0)
			_check(map.is_walkable_tile(tile) and collision.get_cell_source_id(tile) == -1, room + ": " + str(spawn.name) + " arrives on clear floor")
			_check(_reachable(map, start, tile), room + ": " + str(spawn.name) + " connects to the room entrance")
		for door: Area2D in map.get_node("Exits").get_children():
			_check(_reachable(map, start, Vector2i(door.position / 32.0)), room + ": " + str(door.name) + " is reachable")
			var target: Node = load(door.target_scene_path).instantiate()
			_check(target.has_node("Spawns/" + door.target_spawn_name), room + ": " + str(door.name) + " has a return spawn")
			target.free()
		if room in ["left_room", "right_room"]:
			_check(map.get_node("Visual").get_child_count() == 2, room + " contains only the two empty terrain layers")
			_check(map.get_node("Entities/Furniture").get_child_count() == 0, room + " begins unfurnished")
	var world: Node = load("res://scripts/world/world.gd").new()
	world._configure_authorized_map_instance(rooms["main_hall"], {"mapId": "guild_base:kanto_vermilion_city:7:main_hall"})
	_check(rooms["main_hall"].guild_id == 7, "World applies the authorized instance to the loaded template")
	var mirrored_bounds: Dictionary = world._get_map_visual_bounds(rooms["right_room"])
	_check(mirrored_bounds.get("valid", false) and mirrored_bounds.get("rect") == Rect2(0, 0, 736, 608), "the mirrored room keeps correct camera limits")
	world.free()
	var hall: Node2D = rooms["main_hall"]
	_check(not hall.is_walkable_tile(Vector2i(15, 30)), "the fountain blocks its floor footprint")
	_check(not hall.is_walkable_tile(Vector2i(15, 19)), "the fixed lobby furniture blocks its footprint")
	hall.configure_guild_base_instance("guild_base:kanto_vermilion_city:8:main_hall")
	_check(hall.guild_id == 8 and hall.get_map_id() != rooms["left_room"].get_map_id(), "another guild reuses the room scene with a distinct instance")
	var city: Node2D = load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn").instantiate()
	_check(city.get_node("Entities/NPCs/GuildRegistrarNPC").position == Vector2(1136, 560), "the moved registrar stays beside the garden gate")
	_check(city.has_node("Exits/ToGuildBase") and city.has_node("Spawns/FromGuildBase"), "the city building has a two-way entrance")
	var city_collision := city.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(city_collision.get_cell_source_id(Vector2i(52, 10)) == -1 and city_collision.get_cell_source_id(Vector2i(52, 11)) == -1, "city entrance and return tiles are clear")
	city.free()
	for map: Node in rooms.values():
		map.free()
	await process_frame
	print("guild_base_interior_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable(map: Node, start: Vector2i, destination: Vector2i) -> bool:
	if not map.is_walkable_tile(start) or not map.is_walkable_tile(destination):
		return false
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		if tile == destination:
			return true
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := tile + offset
			if not visited.has(next) and map.is_walkable_tile(next):
				visited[next] = true
				queue.append(next)
	return false


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)
