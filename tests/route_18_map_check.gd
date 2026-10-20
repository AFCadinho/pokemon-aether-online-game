extends SceneTree

const BASE := "res://scenes/overworld/kanto/"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var route := (load(BASE+"routes/kanto_route_18.tscn") as PackedScene).instantiate()
	var west := (load(BASE+"routes/kanto_route_17.tscn") as PackedScene).instantiate()
	var gate := (load(BASE+"transition_buildings/route_17_18_gate.tscn") as PackedScene).instantiate()
	var city := (load(BASE+"towns/fuchsia_city/fuchsia_city.tscn") as PackedScene).instantiate()
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	var visual: Node = route.get_node("Visual")
	var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(visual,"res://generated/tiled_visuals/route_18/route_18.visual.tileset.tres")
	_check(errors.is_empty(), "Route 18 imported atlas validates: "+str(errors))
	_check(visual.get_meta("tiled_visual_map").width == 64 and visual.get_meta("tiled_visual_map").height == 52, "artist dimensions preserved")
	var grass: TileMapLayer
	for marker_name in ["TallGrass","Tallgrass","Grass"]:
		grass = route.get_node_or_null("Tiles/"+marker_name) as TileMapLayer
		if grass != null: break
	_check(route.encounter_area_id == "kanto_route_18" and grass != null and grass.get_used_cells().size() == 60, "authored grass markers and Route 18 encounter identity retained")
	_check(route.allows_land_mount_dismount() and route.northbound_blocked_regions.is_empty(), "Route 18 keeps normal movement and dismount rules")
	_check(not gate.land_mount_required_entry and gate.preserve_land_mount_on_transition, "south gate allows walking entry and preserves riding")
	var attendant: Node = gate.get_node("Entities/NPCs/GateNPC")
	_check(attendant.guarded_transition_id == "kanto_route_17_18_gate__to_route17", "attendant checks Route 17 entry")
	_check(attendant.allowed_dialogue_id == "cycling_road_south_gate", "attendant explains mount and direction rules")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[west,"ToRoute18Gate",gate,"FromWest","right"],[gate,"ToWest",west,"FromRoute18Gate","left"],[gate,"ToEast",route,"FromRoute17Gate","right"],[route,"ToRoute17Gate",gate,"FromEast","left"],[route,"ToFuchsiaCity",city,"FromRoute18","right"],[city,"ToRoute18",route,"FromFuchsiaCity","left"]]:
		var exit_node: Node = leg[0].get_node("Exits/"+leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "paired destination and arrival")
		_check(exit_node.monitoring and not exit_node.get_node("CollisionShape2D").disabled, "exit enabled")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit signal connected")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "authoritative catalog endpoints match")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "authoritative spawn matches")
		var col: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		_check(col.get_cell_source_id(Vector2i(arrival.position/32)) == -1, "arrival ground clear")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.position), "actual player shape avoids immediate return")
	# Derive the usable opening from the authored sensor and terrain, including
	# child-shape offsets. Preserve manual doorway and arrival placements.
	for aperture in [[west,"ToRoute18Gate"],[route,"ToRoute17Gate"],[route,"ToFuchsiaCity"],[city,"ToRoute18"],[gate,"ToWest"],[gate,"ToEast"]]:
		var door: Area2D = aperture[0].get_node("Exits/"+aperture[1])
		var shape: CollisionShape2D = door.get_node("CollisionShape2D")
		var center := door.position+shape.position
		var half: Vector2 = shape.shape.size/2
		var open_rows := 0
		for y in range(ceili((center.y-half.y-16)/32),floori((center.y+half.y-16)/32)+1):
			var cell := Vector2i(floori(door.position.x/32),y)
			if aperture[0].find_map_tilemap_layer("Collision").get_cell_source_id(cell) != -1: continue
			open_rows += 1
			_check(player.overlaps_exit_at(door,_point(cell)), "actual player enters across entire authored opening")
		_check(open_rows > 0, "door has a walkable approach")
	for y in range(20,25):
		_check(city.find_map_tilemap_layer("Collision").get_cell_source_id(Vector2i(-1,y)) != -1, "failed west transfer stays within Fuchsia")
	# Exercise player collision rules on the complete imported route.
	route.add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = route
	player.resolved_map_cache = route
	player.collision_tilemap = route.get_node("Tiles/Collision")
	player.water_tilemap = route.get_node("Tiles/Water")
	for y in range(52):
		_check(not player.can_move_to(_point(Vector2i(0,y))), "west boundary contained by scenery")
		if y < 21 or y > 25: _check(not player.can_move_to(_point(Vector2i(63,y))), "east outside opening contained")
	for x in range(64):
		for y in [0,51]: _check(not player.can_move_to(_point(Vector2i(x,y))), "north/south edges contained")
	for y in range(21,26): _check(not player.can_move_to(_point(Vector2i(64,y))), "failed transfer cannot escape east")
	for cell in [Vector2i(12,38),Vector2i(20,34),Vector2i(17,41),Vector2i(24,42)]:
		_check(not player.can_move_to(_point(cell)), "shaft and worksite props are solid")
	for cell in [Vector2i(10,4),Vector2i(30,6)]:
		_check(player.water_tilemap.get_cell_source_id(cell) != -1 and not player.can_move_to(_point(cell)), "lake requires Surf")
	var reached := _reachable(player.collision_tilemap,player.water_tilemap)
	for cell in [Vector2i(route.get_node("Spawns/FromRoute17Gate").position/32),Vector2i(63,23),Vector2i(27,30),Vector2i(27,32),Vector2i(35,35),Vector2i(37,40),Vector2i(37,42),Vector2i(30,44)]:
		_check(reached.has(cell) and player.can_move_to(_point(cell)), "road, grass, stairs and quarry landings reachable")
	if grass != null:
		for cell in grass.get_used_cells():
			if player.collision_tilemap.get_cell_source_id(cell) == -1: _check(reached.has(cell), "all unobstructed tall grass accessible")
	# Real mount eligibility checks apply only to the Cycling Road side.
	player.land_mount_activity_active = false
	for exit_node in [gate.get_node("Exits/ToWest")]:
		_check(exit_node.get_travel_block_reason(player) == "ui.cycling_road.mount_required", "restricted passage rejects walking")
		player.land_mount_activity_active = true
		player.active_mount_id = "cyclizar"
		_check(exit_node.get_travel_block_reason(player).is_empty(), "restricted passage accepts riding")
		player.land_mount_activity_active = false
	for exit_node in [route.get_node("Exits/ToRoute17Gate"),west.get_node("Exits/ToRoute18Gate"),gate.get_node("Exits/ToEast"),route.get_node("Exits/ToFuchsiaCity"),city.get_node("Exits/ToRoute18")]:
		_check(exit_node.get_travel_block_reason(player).is_empty(), "Route 18/Fuchsia passage remains open on foot")
	gate.free()
	west.free()
	city.free()
	route.free()
	if not failed: print("PASS Route 18: atlas, six transfers, full openings, safe arrivals, terrain and mount checks")
	quit(1 if failed else 0)

func _reachable(collision: TileMapLayer,water: TileMapLayer) -> Dictionary:
	var queue: Array[Vector2i] = [Vector2i(8,23)]
	var seen := {Vector2i(8,23):true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if not Rect2i(0,0,64,52).has_point(next) or seen.has(next): continue
			if collision.get_cell_source_id(next) == -1 and water.get_cell_source_id(next) == -1:
				seen[next] = true
				queue.append(next)
	return seen

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)

func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
