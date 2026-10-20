extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_16.tscn") as PackedScene).instantiate()
	var visual: Node = map.get_node("Visual")
	var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(visual,"res://generated/tiled_visuals/route_16/route_16.visual.tileset.tres")
	_check(errors.is_empty(), "imported atlas passes layout checks: " + str(errors))
	_check(map.map_id == "kanto_route_16" and map.world_access_area_type == "route", "map identity")
	_check(map.encounter_area_id == "kanto_route_16" and is_equal_approx(map.grass_encounter_chance,0.21), "existing Route 16 grass encounters")
	_check(visual.get_meta("tiled_visual_map").width == 48 and visual.get_meta("tiled_visual_map").height == 48, "artist dimensions")
	var grass: TileMapLayer = map.get_node("Tiles/TallGrass")
	_check(grass.get_used_cells().size() == 50 and grass.get_used_cells().size() == visual.get_node("Grass").get_used_cells().size(), "all artist grass is playable")
	_check(visual.position == Vector2(-256, 0), "wider visual preserves runtime coordinates")
	_check(map.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(-256, 0, 1536, 1536), "outside mask follows the wider visual")
	var collision: TileMapLayer = map.get_node("Tiles/Collision")
	var water: TileMapLayer = map.get_node("Tiles/Water")
	for cell in grass.get_used_cells():
		_check(visual.get_node("Grass").get_cell_source_id(cell + Vector2i(8, 0)) != -1 and collision.get_cell_source_id(cell) == -1, "grass has art and clear ground")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	map.add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = map
	player.resolved_map_cache = map
	player.collision_tilemap = collision
	player.water_tilemap = water
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	state.current_map = map
	map.encounter_area_id = "" # Offline movement check: no encounter metadata HTTP.
	root.add_child(map)
	state.acquire_overworld_input_lock(&"route16_boundary_check")
	for x in range(15,24): _check(not player.can_move_to(_point(Vector2i(x,48))), "real movement cannot leave map after failed south transfer")
	for y in range(48):
		for x in [0,39]: _check(not player.can_move_to(_point(Vector2i(x,y))), "west/east edges contained")
	for x in range(40):
		for y in [0,47]:
			if y == 47 and x >= 15 and x <= 23:
				_check(player.can_move_to(_point(Vector2i(x,y))) and map.get_node("Exits/ToRoute17").contains_world_position(_point(Vector2i(x,y))), "full southern seam transfers to Route 17")
			else:
				_check(collision.get_cell_source_id(Vector2i(x,y)) != -1 and not player.can_move_to(_point(Vector2i(x,y))), "non-transition edges contained even while Surfing")
	for x in range(15,24):
		_check(not player.call("_is_story_grid_step_blocked",_point(Vector2i(x,17)),_point(Vector2i(x,18)),Vector2.DOWN), "bridge approach unguarded")
		_check(not player.call("_is_story_grid_step_blocked",_point(Vector2i(x,45)),_point(Vector2i(x,46)),Vector2.DOWN), "former Route 17 guard no longer blocks bridge")
	for y in range(18,47):
		for x in [14,24]: _check(not player.can_move_to(_point(Vector2i(x,y))), "outer bridge rails block sideways movement")
	for y in range(33,45): _check(not player.can_move_to(_point(Vector2i(19,y))), "center divider blocks movement")
	for cell in [Vector2i(15,32),Vector2i(23,32),Vector2i(15,45),Vector2i(23,45)]:
		_check(player.can_move_to(_point(cell)) and water.get_cell_source_id(cell) == -1, "both bridge lanes stay dry and clear")
	var reached := _reachable(collision,water,Vector2i(32,14))
	for cell in grass.get_used_cells(): _check(reached.has(cell), "all tall grass accessible from gate")
	for cell in [Vector2i(9,18),Vector2i(15,45),Vector2i(23,45),Vector2i(34,13),Vector2i(34,14)]: _check(reached.has(cell), "patio, both bridge lanes and gate connected: " + str(cell))
	_check(map.get_node("Exits").get_child_count() == 2 and not map.has_node("Entities/NPCs/Route17Guard"), "Route 17 is connected and its temporary guard is removed")
	state.release_overworld_input_lock(&"route16_boundary_check")
	state.current_map = previous
	map.free()
	if not failed: print("PASS Route 16: visual atlas, grass, boundaries, bridge rails and open Route 17 seam")
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
			if not Rect2i(0,0,40,48).has_point(next) or seen.has(next): continue
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
