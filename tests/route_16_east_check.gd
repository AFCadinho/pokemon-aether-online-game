extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn"
const CITY := "res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var route := (load(ROUTE) as PackedScene).instantiate()
	var city := (load(CITY) as PackedScene).instantiate()
	root.add_child(route)
	root.add_child(city)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	route.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	_check(route.map_id == "kanto_route_16_east" and route.world_access_area_type == "route", "route has its own identity")
	_check(route.music_profile_id == "kanto.routes_3_10_16_22", "Route 16 uses its regional route music")
	var visual: Node = route.get_node("Visual")
	var dimensions: Dictionary = visual.get_meta("tiled_visual_map")
	_check(dimensions.width == 52 and dimensions.height == 57, "complete original artist dimensions")
	_check(str(visual.get_meta("tiled_source_path")).ends_with("/Route 16 East.tmx"), "requested artist source is used")
	var validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(visual,"res://generated/tiled_visuals/route_16_east/route_16_east.visual.tileset.tres").is_empty(), "compact atlas resolves all visual cells")
	for layer_name in ["TreeTop","ObjectsTop"]:
		_check(visual.get_node(layer_name).z_index >= 2048, "crowns and upper scenery draw above players")
	for surfing in [false,true]:
		player.surf_activity_active = surfing
		for x in range(52):
			for y in [0,56]:
				_check(not player.can_move_to(_point(Vector2i(x,y))), "north and south edges remain contained, including Surf")
		for y in range(57):
			_check(not player.can_move_to(_point(Vector2i(0,y))), "west edge including pending gate is contained")
			_check(player.can_move_to(_point(Vector2i(51,y))) == (y >= 19 and y <= 23), "east edge opens only toward Celadon")
		for y in range(19,24):
			_check(not player.can_move_to(_point(Vector2i(52,y))), "denied transfer cannot walk outside the route")
	player.surf_activity_active = false
	_check(not player.can_move_to(_point(Vector2i(20,50))), "pond requires Surf")
	player.surf_activity_active = true
	_check(player.can_move_to(_point(Vector2i(20,50))), "pond supports Surf")
	player.surf_activity_active = false
	for tile in [Vector2i(15,11),Vector2i(1,28),Vector2i(5,32),Vector2i(32,24),Vector2i(18,38),Vector2i(26,19),Vector2i(30,19),Vector2i(31,25),Vector2i(30,38)]:
		_check(not player.can_move_to(_point(tile)), "solid sprite footprint remains blocked: " + str(tile))
	var reached := _reachable(player,Vector2i(50,21),Rect2i(0,0,52,57))
	_check(not reached.has(Vector2i(6,29)), "sleeping Snorlax blocks access to Cycling Road")
	route.get_node("Entities/StaticEncounters/Snorlax").apply_status({"encounterId":"snorlax_route_16","completed":true})
	reached = _reachable(player,Vector2i(50,21),Rect2i(0,0,52,57))
	for tile in [Vector2i(6,29),Vector2i(14,13),Vector2i(20,10),Vector2i(42,30),Vector2i(28,18),Vector2i(28,19),Vector2i(28,36),Vector2i(28,37),Vector2i(28,40),Vector2i(28,41),Vector2i(28,43)]:
		_check(reached.has(tile), "paths, stair runs and landings are reachable: " + str(tile))
	var grass: TileMapLayer = route.get_node("Tiles/TallGrass")
	_check(grass.get_used_cells().size() == 164, "both authored grass fields have gameplay markers")
	for tile in grass.get_used_cells():
		_check(reached.has(tile), "every grass tile is accessible")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[route,"ToCeladonCity",city,"FromRoute16East","right"],[city,"ToRoute16East",route,"FromCeladonCity","left"]]:
		var exit_node: Node = leg[0].get_node("Exits/"+leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "paired destinations and arrivals match")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit handles body entry")
		_check(leg[2].get_node("Tiles/Collision").get_cell_source_id(Vector2i(arrival.position/32.0)) == -1, "arrival is walkable")
		for target_exit in leg[2].get_node("Exits").get_children():
			for offset in [Vector2.ZERO,Vector2(0,-16),Vector2(0,8)]:
				_check(not target_exit.contains_world_position(arrival.position+offset), "arrival avoids immediate return")
		var definition: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(definition.sourceMapId == leg[0].map_id and definition.destinationAreaId == leg[2].map_id, "catalog authorizes the correct endpoint")
		_check(definition.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "server arrival matches scene marker")
	for y in range(19,24):
		_check(reached.has(Vector2i(51,y)) and player.overlaps_exit_at(route.get_node("Exits/ToCeladonCity"),_point(Vector2i(51,y))), "entire five-tile route aperture is usable")
	player.reparent(city.get_node("Entities/Players"))
	player.refresh_map_layers()
	var city_reached := _reachable(player,Vector2i(78,17),Rect2i(0,0,80,70))
	for y in range(29,34):
		_check(city_reached.has(Vector2i(0,y)) and player.overlaps_exit_at(city.get_node("Exits/ToRoute16East"),_point(Vector2i(0,y))), "entire five-tile Celadon aperture connects to city streets")
		_check(not player.can_move_to(_point(Vector2i(-1,y))), "denied transfer cannot walk outside Celadon")
	_check(route.get_node("Exits").get_child_count() == 2 and route.has_node("Exits/ToRoute16Gate"), "Celadon and the completed Cycling Road gate are the only active transfers")
	_check(catalog.areas[route.map_id].areaType == "route", "catalog classifies Route 16 East correctly")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.scene_for_map(route.map_id) == ROUTE and loader.module_for_scene(ROUTE) == loader.EXTENDED_MODULE_NAME, "browser travel can load Route 16 East")
	route.free()
	city.free()
	print("ROUTE_16_EAST ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _point(tile: Vector2i) -> Vector2:
	return Vector2(tile)*32+Vector2(16,16)

func _reachable(player: Node,start: Vector2i,bounds: Rect2i) -> Dictionary:
	var reached := {start:true}
	var pending: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < pending.size():
		var tile := pending[cursor]
		cursor += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = tile+direction
			if bounds.has_point(next) and not reached.has(next) and player.can_move_to(_point(next)):
				reached[next] = true
				pending.append(next)
	return reached

func _check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
