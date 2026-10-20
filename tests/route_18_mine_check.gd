extends SceneTree

const MINE := "res://scenes/overworld/kanto/caves/route_18_mine/route_18_mine.tscn"
const SURFACE := "res://scenes/overworld/kanto/routes/kanto_route_18.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var mine := (load(MINE) as PackedScene).instantiate()
	var surface := (load(SURFACE) as PackedScene).instantiate()
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	var visual: Node = mine.get_node("Visual")
	var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(visual,"res://generated/tiled_visuals/route_18_mine/route_18_mine.visual.tileset.tres")
	_check(errors.is_empty(), "mine compact atlas validates: "+str(errors))
	_check(visual.get_meta("tiled_visual_map").width == 42 and visual.get_meta("tiled_visual_map").height == 32, "artist dimensions preserved")
	_check(mine.map_id == "kanto_route_18_mine" and mine.world_access_area_type == "interior", "dedicated mine identity")
	_check(mine.lighting_profile == "indoor" and mine.weather_profile == "disabled" and mine.battle_environment_id == "cave", "underground environment")
	_check(mine.allows_land_mounts() and mine.allows_land_mount_dismount() and not mine.land_mount_required_entry, "optional riding without Cycling Road restrictions")
	var loader: Node = load("res://scripts/services/web_asset_module_service.gd").new()
	_check(loader.scene_for_map(mine.map_id) == MINE, "browser loads mine map pack")
	loader.free()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[surface,"ToUndergroundMine",mine,"FromRoute18","right",Vector2i(10,38)],[mine,"ToRoute18",surface,"FromUndergroundMine","left",Vector2i(4,9)]]:
		var exit_node: Node = leg[0].get_node("Exits/"+leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "stairs paired in both directions")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces away from stairs")
		_check(exit_node.monitoring and not exit_node.get_node("CollisionShape2D").disabled, "stairs enabled")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "stair signal connected")
		_check(exit_node.get_travel_block_reason(player).is_empty(), "stairs accept walking")
		_check(exit_node.contains_world_position(_point(leg[5])) and player.overlaps_exit_at(exit_node,_point(leg[5])), "actual player enters at authored staircase")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "authoritative endpoints match")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "authoritative arrival matches")
		_check(leg[2].find_map_tilemap_layer("Collision").get_cell_source_id(Vector2i(arrival.position/32)) == -1, "arrival on clear ground")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.position), "actual player shape cannot immediately return")
	_check(mine.get_node("Spawns/FromRoute18").position == _point(Vector2i(5,9)), "authored mine landing retained")
	_check(surface.get_node("Spawns/FromUndergroundMine").position == _point(Vector2i(9,38)), "authored surface landing retained")
	mine.add_child(player)
	_configure_player(player,mine)
	for x in range(42):
		for y in [0,31]: _check(not player.can_move_to(_point(Vector2i(x,y))), "north/south perimeter contained")
	for y in range(32):
		for x in [0,41]: _check(not player.can_move_to(_point(Vector2i(x,y))), "east/west perimeter contained")
	for y in range(12,21):
		for x in range(13,29): _check(not player.can_move_to(_point(Vector2i(x,y))), "complete central rock rib blocks movement")
	for cell in [Vector2i(5,11),Vector2i(7,13),Vector2i(6,18),Vector2i(5,24),Vector2i(10,26),Vector2i(34,8),Vector2i(31,12),Vector2i(4,18),Vector2i(34,27),Vector2i(3,9),Vector2i(4,8),Vector2i(4,10)]:
		_check(not player.can_move_to(_point(cell)), "standing rocks, work props and stair sides block movement at %s" % cell)
	var reached := _reachable(player,Rect2i(0,0,42,32),Vector2i(5,9))
	for cell in [Vector2i(4,9),Vector2i(20,7),Vector2i(35,16),Vector2i(24,26),Vector2i(20,10),Vector2i(30,16),Vector2i(20,22),Vector2i(10,16),Vector2i(10,9),Vector2i(11,10),Vector2i(29,22)]:
		_check(reached.has(cell), "work fronts, floor details and loop around rock rib reachable at %s" % cell)
	for y in range(32):
		for x in range(42):
			var cell := Vector2i(x,y)
			if player.can_move_to(_point(cell)): _check(reached.has(cell), "every walkable mine tile connected to stairs")
	mine.remove_child(player)
	surface.add_child(player)
	_configure_player(player,surface)
	var surface_reached := _reachable(player,Rect2i(0,0,64,52),Vector2i(60,23))
	for cell in [Vector2i(9,38),Vector2i(10,38)]:
		_check(surface_reached.has(cell), "surface shaft and return landing reachable from Route 18 road")
	# Route 18's lake edge must also contain a surfing player after a failed save/transfer.
	player.surf_activity_active = true
	_check(player.can_move_to(_point(Vector2i(10,4))), "Surf positive control on interior lake water")
	for y in range(52):
		_check(not player.can_move_to(_point(Vector2i(0,y))), "Surf cannot leave west edge")
		if y < 21 or y > 25: _check(not player.can_move_to(_point(Vector2i(63,y))), "Surf cannot leave east outside transition")
	for x in range(64):
		for y in [0,51]: _check(not player.can_move_to(_point(Vector2i(x,y))), "Surf cannot leave north/south edges")
	player.surf_activity_active = false
	for cell in [Vector2i(12,38),Vector2i(10,37),Vector2i(11,37),Vector2i(10,39),Vector2i(11,39)]:
		_check(not player.can_move_to(_point(cell)), "denied or failed transfer cannot escape shaft footprint")
	mine.free()
	surface.free()
	if not failed: print("PASS Route 18 mine: atlas, round trip, safe authored landings, cave loop and contained boundaries")
	quit(1 if failed else 0)

func _configure_player(player: Node,map: Node) -> void:
	player.map_layers_initialized = true
	player.map_layers_owner = map
	player.resolved_map_cache = map
	player.collision_tilemap = map.find_map_tilemap_layer("Collision")
	player.water_tilemap = map.find_map_tilemap_layer("Water")

func _reachable(player: Node,bounds: Rect2i,start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start:true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if not bounds.has_point(next) or seen.has(next) or not player.can_move_to(_point(next)): continue
			seen[next] = true
			queue.append(next)
	return seen

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)

func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
