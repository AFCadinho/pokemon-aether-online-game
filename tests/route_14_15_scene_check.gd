extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const ROUTE_13 := "res://scenes/overworld/kanto/routes/kanto_route_13.tscn"
const ROUTE_14 := "res://scenes/overworld/kanto/routes/kanto_route_14.tscn"
const ROUTE_15 := "res://scenes/overworld/kanto/routes/kanto_route_15.tscn"
const FUCHSIA_GATE := "res://scenes/overworld/kanto/transition_buildings/route_15_fuchsia_gate.tscn"
const HORIZONTAL_TEMPLATE := "res://scenes/overworld/kanto/reusable_interiors/horizontal_transition_building_template.tscn"
const ROUTE_11_12_GATE := "res://scenes/overworld/kanto/routes/connections/route_12_west.tscn"
const COLLISION_LAYER_NAMES: Array[String] = ["Collision"]

class GuardTestPlayer extends CharacterBody2D:
	var last_direction := Vector2.UP
	func get_feet_position() -> Vector2:
		return global_position

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
	var template := (load(HORIZONTAL_TEMPLATE) as PackedScene).instantiate()
	var route11_12_gate := (load(ROUTE_11_12_GATE) as PackedScene).instantiate()
	# Resolve the ready-time feet marker without entering the tree or requesting NPC metadata.
	for building: Node2D in [gate, route11_12_gate]:
		var attendant := building.get_node("Entities/NPCs/GateNPC")
		attendant.feet_marker = attendant.get_node("FeetMarker")

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
	_check_horizontal_tile_collision(gate, template)
	_check_horizontal_tile_collision(route11_12_gate, template)
	await _check_guard_interaction(gate)
	await _check_guard_interaction(route11_12_gate)

	route11_12_gate.free()
	template.free()
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
	player.collision_tilemap = player._find_tilemap_layer(gate, COLLISION_LAYER_NAMES)
	_expect(player.can_move_to(gate_spawn.global_position), "Player can stand at the gate arrival point")
	_expect(player.can_move_to(gate.get_node("Spawns/FromFuchsiaCity").global_position), "Future Fuchsia arrival point is walkable")
	_expect(route.get_node("Tiles/Collision").get_cell_source_id(Vector2i(5, 14)) == -1,
		"Return arrival on Route 15 is walkable")
	for y in range(9, 12):
		_expect(player.can_move_to(Vector2(80, y * 32 + 16)),
			"Future Fuchsia doorway has no client movement blockade")
	player.free()


func _check_horizontal_tile_collision(map: Node2D, template: Node2D) -> void:
	_expect(not map.has_node("Collision"), "%s has no obsolete root collision layer" % map.name)
	_expect(map.find_children("*", "StaticBody2D", true, false).is_empty(),
		"%s uses tiles instead of physical wall or doorway blockers" % map.name)
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var expected := template.get_node("Tiles/Collision") as TileMapLayer
	var cells_match := collision.get_used_cells().size() == expected.get_used_cells().size()
	for tile: Vector2i in expected.get_used_cells():
		cells_match = cells_match and collision.get_cell_source_id(tile) == expected.get_cell_source_id(tile)
		cells_match = cells_match and collision.get_cell_atlas_coords(tile) == expected.get_cell_atlas_coords(tile)
	_expect(cells_match and collision.tile_set == expected.tile_set,
		"%s inherits its collision tiles from the horizontal template" % map.name)
	var player: Node2D = (load("res://scripts/world/player.gd") as GDScript).new()
	map.get_node("Entities/Players").add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = map
	player.resolved_map_cache = map
	player.collision_tilemap = player._find_tilemap_layer(map, COLLISION_LAYER_NAMES)
	_expect(player.collision_tilemap == collision, "%s player resolves the authored Tiles/Collision layer" % map.name)
	for tile: Vector2i in [Vector2i(2, 1), Vector2i(17, 4), Vector2i(11, 6)]:
		_expect(not player.can_move_to(Vector2(tile) * 32 + Vector2(16, 16)),
			"%s authored wall tiles block movement" % map.name)
	for y in range(9, 12):
		for x in [2, 17]:
			_expect(player.can_move_to(Vector2(x * 32 + 16, y * 32 + 16)),
				"%s doorway stays clear for server-authorized transitions" % map.name)
	player.free()


func _check_guard_interaction(map: Node2D) -> void:
	var guard := map.get_node("Entities/NPCs/GateNPC")
	_expect(guard._get_npc_metadata_id() == "horizontal_gate_attendant",
		"%s attendant resolves shared server dialogue" % map.name)
	_expect(not guard.requires_party_pokemon and not guard.requires_staff_role,
		"%s attendant can speak without local access requirements" % map.name)
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var guard_tile: Vector2i = guard._to_tile(guard.get_feet_position())
	var approach_tile := guard_tile + Vector2i.DOWN * 2
	_expect(collision.get_cell_source_id(guard_tile + Vector2i.DOWN) != -1,
		"%s counter separates the attendant from the player" % map.name)
	_expect(collision.get_cell_source_id(approach_tile) == -1,
		"%s two-tile attendant approach is walkable" % map.name)
	# Use the real detector and player collider in physics, without running NPC/API setup.
	var fixture := Node2D.new()
	var detector := guard.get_node("InteractionArea").duplicate() as Area2D
	fixture.add_child(detector)
	detector.position += guard.position
	var source_player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var player := GuardTestPlayer.new()
	player.add_child(source_player.get_node("DetectionShape").duplicate())
	source_player.free()
	fixture.add_child(player)
	player.position = Vector2(approach_tile) * 32 + Vector2(16, 16)
	get_root().add_child(fixture)
	await physics_frame
	await physics_frame
	_expect(detector.get_overlapping_bodies().has(player),
		"%s detector recognizes the player across the counter" % map.name)
	_expect(guard._is_player_facing_npc(player),
		"%s player can address the attendant across the counter" % map.name)
	player.last_direction = Vector2.DOWN
	_expect(not guard._is_player_facing_npc(player), "%s player must face the attendant" % map.name)
	player.last_direction = Vector2.UP
	player.position += Vector2.DOWN * 32
	_expect(not guard._is_player_facing_npc(player), "%s speech does not extend beyond two tiles" % map.name)
	fixture.free()


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
