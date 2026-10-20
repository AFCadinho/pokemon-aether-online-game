extends SceneTree

const ROUTE16 := "res://scenes/overworld/kanto/routes/kanto_route_16.tscn"
const ROUTE17 := "res://scenes/overworld/kanto/routes/kanto_route_17.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load(ROUTE17) as PackedScene).instantiate()
	var route16 := (load(ROUTE16) as PackedScene).instantiate()
	var visual: Node = map.get_node("Visual")
	var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(visual,"res://generated/tiled_visuals/route_17/route_17.visual.tileset.tres")
	_check(errors.is_empty(), "compact imported atlas validates: " + str(errors))
	_check(visual.get_meta("tiled_visual_map").width == 40 and visual.get_meta("tiled_visual_map").height == 72, "artist map dimensions")
	_check(map.map_id == "kanto_route_17" and map.world_access_area_type == "route", "map identity")
	var collision: TileMapLayer = map.get_node("Tiles/Collision")
	var water: TileMapLayer = map.get_node("Tiles/Water")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[route16,"ToRoute17",map,"FromRoute16","down"],[map,"ToRoute16",route16,"FromRoute17","up"]]:
		var exit_node: Node = leg[0].get_node("Exits/"+leg[1])
		var spawn: Node = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip destination and spawn")
		_check(exit_node.monitoring and not exit_node.get_node("CollisionShape2D").disabled, "both transfers enabled")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit signal connected")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "client/server route identities agree")
		_check(entry.destination.position == {"x":spawn.position.x,"y":spawn.position.y}, "server spawn position agrees")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,spawn.position), "actual player shape avoids immediate return")
		var col: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		var wat: TileMapLayer = leg[2].find_map_tilemap_layer("Water")
		_check(col.get_cell_source_id(Vector2i(spawn.position/32.0)) == -1 and wat.get_cell_source_id(Vector2i(spawn.position/32.0)) == -1, "arrival on clear dry bridge")
		var seam_y: int = 47 if leg[0] == route16 else 0
		for x in range(15,24):
			var point := _point(Vector2i(x,seam_y))
			_check(player.overlaps_exit_at(exit_node,point), "full nine-column seam transfers")
			_check(leg[0].find_map_tilemap_layer("Collision").get_cell_source_id(Vector2i(x,seam_y)) == -1, "seam is not capped")
			var beyond_y: int = 48 if leg[0] == route16 else -1
			_check(leg[0].find_map_tilemap_layer("Collision").get_cell_source_id(Vector2i(x,beyond_y)) != -1, "outside cap prevents escape when transfer is denied or fails")
	map.add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = map
	player.resolved_map_cache = map
	player.collision_tilemap = collision
	player.water_tilemap = water
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	state.current_map = map
	root.add_child(map)
	state.acquire_overworld_input_lock(&"route17_map_check")
	for x in range(15,24): _check(not player.can_move_to(_point(Vector2i(x,-1))), "real movement cannot leave map after failed north transfer")
	for y in range(72):
		for x in [0,39]: _check(not player.can_move_to(_point(Vector2i(x,y))), "outer east/west edge contained")
	for x in range(40):
		_check(collision.get_cell_source_id(Vector2i(x,71)) != -1, "south edge contained")
		if x < 15 or x > 23: _check(not player.can_move_to(_point(Vector2i(x,0))), "northern water edges contained")
	for y in range(0,56):
		for x in [15,16,17,18,20,21,22,23]:
			_check(player.can_move_to(_point(Vector2i(x,y))) and water.get_cell_source_id(Vector2i(x,y)) == -1, "both full bridge lanes stay dry and clear")
		_check(not player.can_move_to(_point(Vector2i(24,y))), "east bridge rail blocks water access")
		if y < 26 or y > 31: _check(not player.can_move_to(_point(Vector2i(14,y))), "west rail outside platform opening blocks movement")
	for span in [[5,16],[21,32],[37,46]]:
		for y in range(span[0],span[1]+1): _check(not player.can_move_to(_point(Vector2i(19,y))), "center dividers block crossing")
	var reached := _reachable(collision,water,Vector2i(17,2))
	for y in range(24,34):
		for x in range(8,15):
			if collision.get_cell_source_id(Vector2i(x,y)) == -1:
				_check(water.get_cell_source_id(Vector2i(x,y)) == -1 and reached.has(Vector2i(x,y)), "all unobstructed platform floor accessible and dry")
	for cell in [Vector2i(15,55),Vector2i(23,55),Vector2i(17,60),Vector2i(32,59)]:
		_check(reached.has(cell), "bridge connects to southern plaza and gate approach")
	_check(not map.has_node("Entities/NPCs/Route18Guard"), "temporary Route 18 closure removed")
	_check(map.get_node("Exits").get_child_count() == 2, "north bridge and south gate exits available")
	var south_exit: Area2D = map.get_node("Exits/ToRoute18Gate")
	var south_shape: CollisionShape2D = south_exit.get_node("CollisionShape2D")
	var center := south_exit.position+south_shape.position
	var half: Vector2 = south_shape.shape.size/2
	var opening_rows := 0
	for y in range(ceili((center.y-half.y-16)/32),floori((center.y+half.y-16)/32)+1):
		var cell := Vector2i(floori(south_exit.position.x/32),y)
		if collision.get_cell_source_id(cell) != -1: continue
		opening_rows += 1
		_check(reached.has(cell), "entire authored southern gate approach reachable")
		_check(player.overlaps_exit_at(south_exit,_point(cell)), "full authored gate throat transfers")
	_check(opening_rows > 0, "south gate has a clear approach")
	_check(reached.has(Vector2i(map.get_node("Spawns/FromRoute18Gate").position/32)), "authored gate landing connects to road")
	state.release_overworld_input_lock(&"route17_map_check")
	state.current_map = previous
	map.free()
	route16.free()
	if not failed: print("PASS Route 17: atlas, round trip, complete seam, bridge lanes, side platform and open Route 18 gate")
	quit(1 if failed else 0)

func _reachable(collision: TileMapLayer,water: TileMapLayer,start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start:true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if not Rect2i(0,0,40,72).has_point(next) or seen.has(next): continue
			if collision.get_cell_source_id(next) == -1 and water.get_cell_source_id(next) == -1:
				seen[next] = true
				queue.append(next)
	return seen

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)

func _check(condition: bool,message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
