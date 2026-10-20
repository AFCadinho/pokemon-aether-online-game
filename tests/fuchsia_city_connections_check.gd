extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_15_fuchsia_gate.tscn"

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	root.add_child(city)
	root.add_child(gate)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	city.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	var ground: TileMapLayer = city.get_node("Visual/Ground")
	_check(ground.get_used_rect() == Rect2i(0, 0, 72, 50) and ground.get_used_cells().size() == 3600, "complete artist visual is imported")
	var validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(city.get_node("Visual"), "res://generated/tiled_visuals/fuchsia_city/fuchsia_city.visual.tileset.tres").is_empty(), "compact atlas is valid")
	_check(city.get_node("Visual/ObjectsTop").z_index > city.get_node("Entities").z_index, "upper scenery draws above players")
	var stairs := preload("res://scripts/world/horizontal_stair_elevation.gd")
	for cell in [Vector2i(12,12), Vector2i(17,33), Vector2i(38,41), Vector2i(43,9)]:
		var point := Vector2(cell)*32+Vector2(16,16)
		var up_direction := Vector2.RIGHT if cell.x == 43 else Vector2.LEFT
		_check(stairs.elevation_for_stair_exit(city, point, point + up_direction*32, up_direction) == stairs.ELEVATION_UP, "horizontal stairs retain their climb presentation")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city, "ToRoute15Gate", gate, "FromFuchsiaCity", "right"], [gate, "ToWest", city, "FromRoute15Gate", "left"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip destination matches")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces away from doorway")
		_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "exit signal is connected")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "server catalog matches runtime")
		var collision: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		_check(collision.get_cell_source_id(collision.local_to_map(arrival.position)) == -1, "arrival is free of collision")
		for destination_exit in leg[2].get_node("Exits").get_children():
			for offset in [Vector2.ZERO, Vector2(0,-16), Vector2(0,8)]:
				_check(not destination_exit.contains_world_position(arrival.global_position + offset), "arrival cannot immediately retrigger")
	# Exercise the actual player's collision and water rules, including Surf.
	for surfing in [false, true]:
		player.surf_activity_active = surfing
		for x in range(72):
			for y in [0,49]: _check(not player.can_move_to(Vector2(x,y)*32+Vector2(16,16)), "north/south perimeter is contained")
		for y in range(50):
			for x in [0,71]: _check(not player.can_move_to(Vector2(x,y)*32+Vector2(16,16)), "west/east perimeter is contained")
	player.surf_activity_active = false
	_check(not player.can_move_to(Vector2(44,30)*32+Vector2(16,16)), "pond requires Surf")
	player.surf_activity_active = true
	_check(player.can_move_to(Vector2(44,30)*32+Vector2(16,16)), "pond allows Surf")
	player.surf_activity_active = false
	var visited := {Vector2i(65,22): true}
	var pending: Array[Vector2i] = [Vector2i(65,22)]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if not Rect2i(0,0,72,50).has_point(next) or visited.has(next): continue
			if player.can_move_to(Vector2(next)*32+Vector2(16,16)):
				visited[next] = true
				pending.append(next)
	for cell in [Vector2i(36,6),Vector2i(37,6),Vector2i(38,6),Vector2i(7,9),Vector2i(37,22),Vector2i(7,11),Vector2i(22,11),Vector2i(31,36),Vector2i(54,27),Vector2i(54,37),Vector2i(54,12),Vector2i(21,45),Vector2i(17,33)]:
		_check(visited.has(cell), "city streets, stairs and bridge are reachable: " + str(cell))
	for y in range(21,24):
		var point := Vector2(67,y)*32+Vector2(16,16)
		_check(player.can_move_to(point) and city.get_node("Exits/ToRoute15Gate").contains_world_position(point), "full three-tile gate aperture is usable")
		_check(not player.can_move_to(Vector2(68,y)*32+Vector2(16,16)), "failed transfer cannot walk through gate facade")
	city.free()
	gate.free()
	print("FUCHSIA_CITY_CONNECTIONS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
