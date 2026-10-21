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
	_check(visual.get_meta("tiled_visual_map").width == 48 and visual.get_meta("tiled_visual_map").height == 72, "artist map dimensions")
	_check(map.map_id == "kanto_route_17" and map.world_access_area_type == "route", "map identity")
	_check(visual.position == Vector2(-256, 0), "wider visual preserves runtime coordinates")
	_check(map.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(-256, 0, 1536, 2304), "outside mask follows the wider visual")
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
		var seam_y: int = 47 if leg[0] == route16 else 0
		for x in range(15,24):
			var point := _point(Vector2i(x,seam_y))
			_check(player.overlaps_exit_at(exit_node,point), "full nine-column seam transfers")
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
	for surfing in [false,true]:
		player.surf_activity_active = surfing
	player.surf_activity_active = false
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
	_check(opening_rows > 0, "south gate has a clear approach")
	state.release_overworld_input_lock(&"route17_map_check")
	state.current_map = previous
	map.free()
	route16.free()
	if not failed: print("PASS Route 17: atlas, round trip, complete seam, bridge lanes, side platform and open Route 18 gate")
	quit(1 if failed else 0)


func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)

func _check(condition: bool,message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
