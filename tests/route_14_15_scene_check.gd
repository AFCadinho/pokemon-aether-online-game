extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const ROUTE_13 := "res://scenes/overworld/kanto/routes/kanto_route_13.tscn"
const ROUTE_14 := "res://scenes/overworld/kanto/routes/kanto_route_14.tscn"
const ROUTE_15 := "res://scenes/overworld/kanto/routes/kanto_route_15.tscn"
const FUCHSIA_GATE := "res://scenes/overworld/kanto/transition_buildings/route_15_fuchsia_gate.tscn"

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
	var gate := (load(FUCHSIA_GATE) as PackedScene).instantiate()

	_expect(route14.map_id == "kanto_route_14", "Route 14 scene has its canonical map ID")
	_expect(route15.map_id == "kanto_route_15", "Route 15 scene has its canonical map ID")
	_check_visual(route14, 48, 76, "/Route 14.tmx")
	_check_visual(route15, 104, 40, "/Route 15.tmx")
	var route15_visual := route15.get_node("Visual")
	var imported_layer_count := 0
	for child: Node in route15_visual.get_children():
		if child is TileMapLayer and bool(child.get_meta("tiled_visual_layer", false)):
			imported_layer_count += 1
	_expect(imported_layer_count == 9,
		"Route 15 renders the nine imported Tiled layers without stale duplicate layers")
	_expect(route14.has_node("Tiles/Collision"), "Route 14 has a collision layer")
	_expect(route15.has_node("Tiles/Collision"), "Route 15 has a collision layer")
	_expect(areas.has("kanto_route_14") and areas.has("kanto_route_15"), "Routes 14 and 15 are registered")
	_check_link(route13, route14, "ToRoute14", "kanto_route_13__to_route14", "kanto_route_14", ROUTE_14, "FromRoute13", transitions)
	_check_link(route14, route13, "ToRoute13", "kanto_route_14__to_route13", "kanto_route_13", ROUTE_13, "FromRoute14", transitions)
	_check_link(route14, route15, "ToRoute15", "kanto_route_14__to_route15", "kanto_route_15", ROUTE_15, "FromRoute14", transitions)
	_check_link(route15, route14, "ToRoute14", "kanto_route_15__to_route14", "kanto_route_14", ROUTE_14, "FromRoute15", transitions)
	_check_link(route15, gate, "ToFuchsiaGate", "kanto_route_15__to_fuchsia_gate", "kanto_route_15_fuchsia_gate", FUCHSIA_GATE, "FromRoute15", transitions)
	_check_link(gate, route15, "ToEast", "kanto_route_15_fuchsia_gate__to_route15", "kanto_route_15", ROUTE_15, "FromFuchsiaGate", transitions)
	_check_fuchsia_gate(route15, gate, areas)

	gate.free()
	route13.free()
	route14.free()
	route15.free()
	quit(1 if failed else 0)


func _check_fuchsia_gate(route: Node2D, gate: Node2D, areas: Dictionary) -> void:
	_expect(areas.has("kanto_route_15_fuchsia_gate"), "Fuchsia gate is registered")
	_expect(gate.get_node("Visuals").scene_file_path == "res://generated/tiled_visuals/transition_building_horizontal/transition_building_horizontal.visual.tscn",
		"Fuchsia gate uses the shared horizontal template visual")
	_expect(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled",
		"Fuchsia gate inherits indoor lighting and weather")
	var entrance := route.get_node("Exits/ToFuchsiaGate") as Area2D
	var shape := entrance.get_node("CollisionShape2D").shape as RectangleShape2D
	_expect(entrance.position == Vector2(144, 448) and shape.size == Vector2(32, 64),
		"Route 15 doorway matches the west_to_fuchsia TMX connection marker")
	var route_spawn := route.get_node("Spawns/FromFuchsiaGate") as Marker2D
	var gate_spawn := gate.get_node("Spawns/FromRoute15") as Marker2D
	_expect(route_spawn.position == Vector2(176, 464), "Route 15 return uses the artist's arrival tile")
	_expect(not entrance.contains_world_position(route_spawn.global_position), "Route 15 arrival avoids an immediate return transition")
	_expect(not gate.get_node("Exits/ToEast").contains_world_position(gate_spawn.global_position), "Gate arrival avoids an immediate return transition")
	for y in range(13, 15):
		_expect(route.get_node("Tiles/Collision").get_cell_source_id(Vector2i(4, y)) == -1,
			"Route 15 gate entrance tiles are walkable")
	var west := gate.get_node("Exits/ToWest") as Area2D
	_expect(not west.monitoring and west.get_node("CollisionShape2D").disabled,
		"Future Fuchsia exit stays inactive until its destination exists")
	var player: Node2D = (load("res://scripts/world/player.gd") as GDScript).new()
	gate.get_node("Entities/Players").add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = gate
	player.resolved_map_cache = gate
	player.collision_tilemap = gate.get_node("Collision")
	_expect(player.can_move_to(gate_spawn.global_position), "Player can stand at the gate arrival point")
	_expect(player.can_move_to(gate.get_node("Spawns/FromFuchsiaCity").global_position), "Future Fuchsia arrival point is walkable")
	_expect(route.get_node("Tiles/Collision").get_cell_source_id(Vector2i(5, 14)) == -1,
		"Return arrival on Route 15 is walkable")
	for y in range(9, 12):
		_expect(not player.can_move_to(Vector2(80, y * 32 + 16)),
			"Player cannot leave through the unfinished Fuchsia doorway")
	player.free()


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
	# Match World's lookup for both legacy and authorized map transitions.
	var marker := destination_scene.get_node_or_null("Spawns/" + str(exit.target_spawn_name)) as Marker2D
	_expect(exit.transition_id == transition_id, "%s uses its registered transition" % exit_name)
	_expect(exit.target_scene_path == destination_path, "%s targets the connected scene" % exit_name)
	_expect(exit.target_spawn_name == spawn_name, "%s names the matching arrival marker" % exit_name)
	_expect(record.get("sourceMapId") == source.map_id and record.get("destinationAreaId") == destination_id, "%s catalog endpoints match the scenes" % transition_id)
	_expect(destination.get("mapId") == destination_id and destination.get("spawnMarker") == spawn_name, "%s catalog destination and marker match" % transition_id)
	if marker != null:
		_expect(Vector2(spawn.get("x", -1.0), spawn.get("y", -1.0)) == marker.global_position, "%s catalog coordinates match the scene marker" % transition_id)
	else:
		_expect(false, "%s scene contains its target spawn marker" % transition_id)
	_expect(exit.body_entered.is_connected(Callable(exit, "_on_body_entered")), "%s transition trigger is connected" % exit_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failed = true
		push_error("FAIL: %s" % message)
