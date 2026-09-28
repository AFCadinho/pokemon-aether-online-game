extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const ROUTE_21 := "res://scenes/overworld/kanto/routes/kanto_route_21.tscn"
const CINNABAR := "res://scenes/overworld/kanto/towns/cinnabar_island/cinnabar_island.tscn"
const VERMILION := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const DOCKS := "res://scenes/overworld/kanto/towns/vermilion_docks/vermilion_docks.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var route_21 := _open(ROUTE_21)
	var cinnabar := _open(CINNABAR)
	var vermilion := _open(VERMILION)
	var docks := _open(DOCKS)
	if route_21 == null or cinnabar == null or vermilion == null or docks == null:
		quit(1)
		return

	_check_water(route_21, Vector2i(50, 90), 3690)
	_check_water(cinnabar, Vector2i(64, 72), 2212)
	_check_water(vermilion, Vector2i(80, 64), 654)
	_check_water(docks, Vector2i(64, 48), 2290)
	_expect(_water(cinnabar, 32, 1) and _water(route_21, 26, 88),
		"Route 21 and Cinnabar arrivals are Surf water")
	_expect(not _water(cinnabar, 33, 10), "Cinnabar north landing is land")

	_check_exit(route_21, "ToCinnabarIsland", CINNABAR, "FromRoute21", Vector2(832, 2864))
	_check_exit(cinnabar, "ToRoute21", ROUTE_21, "FromCinnabarIsland", Vector2(1024, 16))
	_check_exit(vermilion, "ToDocks", DOCKS, "FromVermilionCity", Vector2(1328, 2032))
	_check_exit(docks, "ToVermilionCity", VERMILION, "FromDocks", Vector2(1008, 16))
	_expect(_position(cinnabar, "FromRoute21") == Vector2(1040, 48), "Cinnabar north arrival")
	_expect(_position(route_21, "FromCinnabarIsland") == Vector2(848, 2832), "Route 21 south arrival")
	_expect(_position(vermilion, "FromDocks") == Vector2(1328, 2000), "Vermilion docks arrival")
	_expect(_position(docks, "FromVermilionCity") == Vector2(1008, 48), "Docks city arrival")
	_expect(cinnabar.get_node_or_null("Visual/ObjectsTop") != null, "Cinnabar imported visual in scene")
	_expect(docks.get_node_or_null("Visual/ObjectsTop") != null, "Docks imported visual in scene")
	_expect(vermilion.get_node_or_null("Visual/PavementEdges") != null,
		"Vermilion scene uses the restored city visual")

	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var areas: Dictionary = catalog.get("areas", {})
	var transitions: Dictionary = catalog.get("transitions", {})
	_expect(areas.has("kanto_cinnabar_island") and areas.has("kanto_vermilion_docks"),
		"Cinnabar and docks are registered for staff teleport")
	for transition_id in ["kanto_route_21__to_cinnabar_island", "kanto_cinnabar_island__to_route21",
		"kanto_vermilion_city__to_docks", "kanto_vermilion_docks__to_city"]:
		_expect(transitions.has(transition_id), "catalog has " + transition_id)

	route_21.queue_free()
	cinnabar.queue_free()
	vermilion.queue_free()
	docks.queue_free()
	print("CINNABAR_VERMILION_IMPORT ", "PASS" if not failed else "FAIL")
	quit(1 if failed else 0)


func _open(path: String) -> Node:
	var scene := load(path) as PackedScene
	if scene == null:
		_expect(false, "load " + path)
		return null
	var map := scene.instantiate()
	root.add_child(map)
	return map


func _water(map: Node, x: int, y: int) -> bool:
	return bool(map.call("is_water_tile_for_actor", Vector2(x * 32 + 16, y * 32 + 16), null))


func _check_water(map: Node, size: Vector2i, expected: int) -> void:
	var water_count := 0
	for y in range(size.y):
		for x in range(size.x):
			if _water(map, x, y):
				water_count += 1
	_expect(water_count == expected, "%s recognizes %d open-water tiles" % [map.name, expected])


func _check_exit(map: Node, exit_name: String, target_path: String, target_spawn: String, center: Vector2) -> void:
	var exit_node: Node = map.get_node("Exits/" + exit_name)
	_expect(exit_node.target_scene_path == target_path and exit_node.target_spawn_name == target_spawn,
		"%s leads to its matching arrival" % exit_name)
	_expect(exit_node.contains_world_position(center), "%s covers the map edge" % exit_name)


func _position(map: Node, spawn_name: String) -> Vector2:
	return map.get_node("Spawns/" + spawn_name).position


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failed = true
		push_error("FAIL: " + description)
