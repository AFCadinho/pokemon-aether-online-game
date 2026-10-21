extends SceneTree
var failed := false
func _init() -> void:
	run.call_deferred()
func run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn") as PackedScene).instantiate()
	var house := (load("res://scenes/overworld/kanto/routes/route_16_east_house.tscn") as PackedScene).instantiate()
	root.add_child(route)
	root.add_child(house)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	house.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	var reached := {Vector2i(9,14):true}
	var queue: Array[Vector2i] = [Vector2i(9,14)]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = tile + delta
			if not reached.has(next) and player.can_move_to(point(next)):
				check(Rect2i(4,8,13,8).has_point(next), "room cannot escape into black padding")
				if not Rect2i(0,0,22,20).has_point(next):
					continue
				reached[next] = true
				queue.append(next)
	for tile in [Vector2i(4,9),Vector2i(11,8),Vector2i(14,10),Vector2i(6,12),Vector2i(12,14),Vector2i(16,14)]:
		check(not player.can_move_to(point(tile)), "solid furniture blocks movement " + str(tile))
	for x in range(8,11):
		check(reached.has(Vector2i(x,15)), "entire three-tile doorway is reachable")
		check(player.overlaps_exit_at(house.get_node("Exits/ToRoute16East"),point(Vector2i(x,15))), "exit covers the full doorway")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[route,"ToHouse",house,"FromRoute16East","up"],[house,"ToRoute16East",route,"FromHouse","down"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "paired scene and spawn")
		check(exit_node.transition_facing_direction == leg[4], "arrival facing")
		check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "entry signal connected")
		player.reparent(leg[2].get_node("Entities/Players"))
		player.refresh_map_layers()
		check(player.can_move_to(arrival.position), "arrival is walkable " + leg[3])
		for other_exit in leg[2].get_node("Exits").get_children():
			check(not player.overlaps_exit_at(other_exit,arrival.position), "arrival avoids immediate return " + leg[3])
		var definition: Dictionary = catalog.transitions[exit_node.transition_id]
		check(definition.sourceMapId == leg[0].map_id and definition.destinationAreaId == leg[2].map_id, "server endpoints match")
		check(definition.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "server spawn matches")
	player.reparent(route.get_node("Entities/Players"))
	player.refresh_map_layers()
	check(player.can_move_to(point(Vector2i(14,13))), "exterior door is walkable")
	check(player.overlaps_exit_at(route.get_node("Exits/ToHouse"),point(Vector2i(14,13))), "exterior door detects entry")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	check(loader.scene_for_map(house.map_id) == house.scene_file_path, "web module resolves house")
	var validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	check(validator.validate(house.get_node("Visual"),"res://generated/tiled_visuals/route_16_east_house/route_16_east_house.visual.tileset.tres").is_empty(), "visual atlas resolves")
	route.free()
	house.free()
	print("ROUTE_16_EAST_HOUSE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func point(tile: Vector2i) -> Vector2:
	return Vector2(tile)*32+Vector2(16,16)
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
