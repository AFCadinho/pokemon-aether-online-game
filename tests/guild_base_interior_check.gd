extends SceneTree

var failed := false
const ROOM_ROOT := "res://scenes/overworld/kanto/guild_base/"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var rooms: Dictionary = {}
	for room: String in ["main_hall", "left_room", "right_room", "elevator", "elevator_cabin"]:
		var map: Node2D = load(ROOM_ROOT + room + ".tscn").instantiate()
		map.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:" + room)
		root.add_child(map)
		rooms[room] = map
		_check(map.get_map_id() == "guild_base:kanto_vermilion_city:7:" + room, room + " keeps server instance identity")
		_check(not map.allows_land_mounts(), room + " blocks riding indoors")
		_check(map.get_weather_profile() == "disabled", room + " excludes exterior weather")
		for door: Area2D in map.get_node("Exits").get_children():
			var target: Node = load(door.target_scene_path).instantiate()
			_check(target.has_node("Spawns/" + door.target_spawn_name), room + ": " + str(door.name) + " has a return spawn")
			target.free()
		if room in ["left_room", "right_room"]:
			_check(map.get_node("Visual").get_child_count() == 2, room + " contains only the two empty terrain layers")
			_check(map.get_node("Entities/Furniture").get_child_count() == 0, room + " begins unfurnished")
	var world: Node = load("res://scripts/world/world.gd").new()
	world._configure_authorized_map_instance(rooms["main_hall"], {"mapId": "guild_base:kanto_vermilion_city:7:main_hall"})
	_check(rooms["main_hall"].guild_id == 7, "World applies the authorized instance to the loaded template")
	var room_bounds: Dictionary = world._get_map_visual_bounds(rooms["right_room"])
	_check(room_bounds.get("valid", false) and room_bounds.get("rect") == Rect2(0, 0, 736, 608), "the room keeps correct camera limits")
	world.free()
	var cabin: Node2D = rooms["elevator_cabin"]
	_check(cabin.get_node("Visual/LiftControls").position == Vector2(10, 12), "the cabin preserves the authored control panel offset")
	_check(cabin.get_node("Visual/ExitThreshold").position == Vector2(16, -16) and cabin.get_node("Visual/ExitMat").position == Vector2(16, -10), "the cabin preserves the authored doorway offsets")
	_check(cabin.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(160, 112, 160, 208), "the cabin masks padding and constrains the camera to its interior")
	_check(not cabin.get_node("Exits/ToElevator").contains_world_position(cabin.get_node("Spawns/FromElevator").position), "arrival in the cabin does not immediately trigger its return door")
	_check(not rooms["elevator"].get_node("Exits/ToCabin").contains_world_position(rooms["elevator"].get_node("Spawns/FromCabin").position), "returning from the cabin does not immediately re-enter it")
	cabin.configure_guild_base_instance("guild_base:kanto_vermilion_city:8:elevator_cabin")
	_check(cabin.guild_id == 8 and cabin.get_map_id() == "guild_base:kanto_vermilion_city:8:elevator_cabin", "the cabin is a reusable private Guild template")
	var hall: Node2D = rooms["main_hall"]
	hall.configure_guild_base_instance("guild_base:kanto_vermilion_city:8:main_hall")
	_check(hall.guild_id == 8 and hall.get_map_id() != rooms["left_room"].get_map_id(), "another guild reuses the room scene with a distinct instance")
	var city: Node2D = load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn").instantiate()
	_check(city.get_node("Entities/NPCs/GuildRegistrarNPC").position == Vector2(1136, 560), "the moved registrar stays beside the garden gate")
	_check(city.has_node("Exits/ToGuildBase") and city.has_node("Spawns/FromGuildBase"), "the city building has a two-way entrance")
	city.free()
	for map: Node in rooms.values():
		map.free()
	await process_frame
	print("guild_base_interior_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)
