extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const ROUTE_13 := "res://scenes/overworld/kanto/routes/kanto_route_13.tscn"
const ROUTE_14 := "res://scenes/overworld/kanto/routes/kanto_route_14.tscn"
const ROUTE_15 := "res://scenes/overworld/kanto/routes/kanto_route_15.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var payload_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_expect(payload_value is Dictionary, "World access catalog is valid JSON")
	if not payload_value is Dictionary:
		quit(1)
		return
	var catalog := payload_value as Dictionary
	var areas := catalog.get("areas", {}) as Dictionary
	var transitions := catalog.get("transitions", {}) as Dictionary
	var route13 := (load(ROUTE_13) as PackedScene).instantiate()
	var route14 := (load(ROUTE_14) as PackedScene).instantiate()
	var route15 := (load(ROUTE_15) as PackedScene).instantiate()

	_expect(route14.map_id == "kanto_route_14", "Route 14 scene has its canonical map ID")
	_expect(route15.map_id == "kanto_route_15", "Route 15 scene has its canonical map ID")
	_check_visual(route14, 48, 76, "/Route 14.tmx")
	_check_visual(route15, 104, 40, "/Route 15.tmx")
	_expect(route14.has_node("Tiles/Collision"), "Route 14 has a collision layer")
	_expect(route15.has_node("Tiles/Collision"), "Route 15 has a collision layer")
	_expect(areas.has("kanto_route_14") and areas.has("kanto_route_15"), "Routes 14 and 15 are registered")
	_check_link(route13, route14, "ToRoute14", "kanto_route_13__to_route14", "kanto_route_14", ROUTE_14, "FromRoute13", transitions)
	_check_link(route14, route13, "ToRoute13", "kanto_route_14__to_route13", "kanto_route_13", ROUTE_13, "FromRoute14", transitions)
	_check_link(route14, route15, "ToRoute15", "kanto_route_14__to_route15", "kanto_route_15", ROUTE_15, "FromRoute14", transitions)
	_check_link(route15, route14, "ToRoute14", "kanto_route_15__to_route14", "kanto_route_14", ROUTE_14, "FromRoute15", transitions)

	route13.free()
	route14.free()
	route15.free()
	quit(1 if failed else 0)


func _check_visual(map: Node, width: int, height: int, source_suffix: String) -> void:
	var visual := map.get_node("Visual")
	var visual_map := visual.get_meta("tiled_visual_map", {}) as Dictionary
	var source_path := str(visual.get_meta("tiled_source_path", ""))
	_expect(visual_map.get("width") == width and visual_map.get("height") == height, "%s visual dimensions match its TMX" % map.name)
	_expect(source_path.ends_with(source_suffix), "%s visual points to the imported artist TMX" % map.name)


func _check_link(
	source: Node,
	destination_scene: Node,
	exit_name: String,
	transition_id: String,
	destination_id: String,
	destination_path: String,
	spawn_name: String,
	transitions: Dictionary
) -> void:
	var exit := source.get_node("Exits/" + exit_name)
	var record_value: Variant = transitions.get(transition_id, null)
	_expect(record_value is Dictionary, "Catalog contains %s" % transition_id)
	if not record_value is Dictionary:
		return
	var record := record_value as Dictionary
	var destination := record.get("destination", {}) as Dictionary
	var spawn := destination.get("position", {}) as Dictionary
	var marker := destination_scene.get_node("Spawns/" + str(exit.target_spawn_name)) as Marker2D
	_expect(exit.transition_id == transition_id, "%s uses its registered transition" % exit_name)
	_expect(exit.target_scene_path == destination_path, "%s targets the connected scene" % exit_name)
	_expect(exit.target_spawn_name == spawn_name, "%s names the matching arrival marker" % exit_name)
	_expect(record.get("sourceMapId") == source.map_id and record.get("destinationAreaId") == destination_id, "%s catalog endpoints match the scenes" % transition_id)
	_expect(destination.get("mapId") == destination_id and destination.get("spawnMarker") == spawn_name, "%s catalog destination and marker match" % transition_id)
	_expect(Vector2(spawn.get("x", -1.0), spawn.get("y", -1.0)) == marker.position, "%s catalog coordinates match the scene marker" % transition_id)
	_expect(exit.body_entered.is_connected(Callable(exit, "_on_body_entered")), "%s transition trigger is connected" % exit_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failed = true
		push_error("FAIL: %s" % message)
