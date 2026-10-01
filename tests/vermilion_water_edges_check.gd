extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city: Node = load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn").instantiate()
	root.add_child(city)
	_check_water_animation(city.get_node("Visual"))
	var game_state := root.get_node("GameState")
	var original_map: Node = game_state.current_map
	game_state.current_map = city
	var player: Node = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	city.get_node("Entities/Players").add_child(player)
	await process_frame
	player.refresh_map_layers()
	var water := city.get_node("Tiles/Water") as TileMapLayer
	var ground := city.get_node("Visual/Ground") as TileMapLayer
	var collision := city.get_node("Tiles/Collision") as TileMapLayer
	var shore_count := 0
	var surfable_count := 0
	for cell in water.get_used_cells():
		var center := water.to_global(water.map_to_local(cell))
		_check(city.is_water_tile_for_actor(center, player), "painted water recognized at %s" % cell)
		player.surf_activity_active = false
		_check(not player.can_move_to(center), "walking blocked at %s" % cell)
		var ground_cell := ground.local_to_map(ground.to_local(center))
		if ground.get_cell_source_id(ground_cell) != city.water_source_id or ground.get_cell_atlas_coords(ground_cell) != city.water_atlas_coords:
			shore_count += 1
		var collision_cell := collision.local_to_map(collision.to_local(center))
		if collision.get_cell_source_id(collision_cell) == -1 and not MapCharacterBlocking.is_position_blocked_by_character(city, center):
			player.surf_activity_active = true
			_check(player.can_move_to(center), "Surf can enter unblocked water at %s" % cell)
			surfable_count += 1
	_check(shore_count > 0, "covers painted shore outside imported open water")
	_check(surfable_count > 0, "covers water without hard collision")
	var dock_arrival := city.get_node("Spawns/FromDocks") as Node2D
	_check(not city.is_water_tile_for_actor(dock_arrival.global_position, player), "dock arrival remains dry")
	_check(city.is_water_tile_for_actor(Vector2(16, 1616), player), "imported open water remains water")
	print("Checked %d painted cells, %d additional shore cells" % [water.get_used_cells().size(), shore_count])
	for entry in [
		["res://scenes/overworld/kanto/routes/kanto_route_21.tscn", Vector2i(50, 90), 3690],
		["res://scenes/overworld/kanto/towns/cinnabar_island/cinnabar_island.tscn", Vector2i(64, 72), 2212],
		["res://scenes/overworld/kanto/towns/vermilion_docks/vermilion_docks.tscn", Vector2i(75, 30), 1939],
	]:
		var other: Node = load(entry[0]).instantiate()
		root.add_child(other)
		var count := 0
		for y in range(entry[1].y):
			for x in range(entry[1].x):
				if other.is_water_tile_for_actor(Vector2(x * 32 + 16, y * 32 + 16), null):
					count += 1
		_check(count == entry[2], "%s retains its water coverage" % other.name)
		other.free()
	game_state.current_map = original_map
	city.free()
	print("VERMILION_WATER_EDGES ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _check_water_animation(visual: Node) -> void:
	var fingerprint = preload("res://tests/support/visual_atlas_fingerprint.gd").new()
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/vermilion_water_animation_report.json"))
	var actual: Dictionary = fingerprint.capture(visual)
	for key in ["fingerprint", "cells", "layers", "usedTiles"]:
		_check(actual[key] == report.before[key], "water animation preserves original visual " + key)
	var catalog := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_animation_assets/catalog.json"))
	for entry: Dictionary in data.tiles:
		if entry.group == "water":
			catalog[entry.source_pixel_sha256] = entry
	var signatures = load("res://tools/vermilion_water_animation.gd")._animation_signatures(visual)
	for hash in report.preserved_animations:
		var previous: Array = report.preserved_animations[hash]
		var current: Array = signatures.get(hash,[])
		_check(current.size() == previous.size(), "existing grass frame count preserved")
		for f in mini(current.size(),previous.size()):
			_check(current[f].hash == previous[f].hash, "existing grass pixels preserved")
			_check(is_equal_approx(current[f].duration,previous[f].duration), "existing grass timing preserved")
			_check(is_equal_approx(current[f].speed,previous[f].speed), "existing grass speed preserved")
	var layers: Array[TileMapLayer] = []
	preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd").new()._collect(visual,layers)
	var water_tiles := {}
	var tiles := layers[0].tile_set
	var water_colors := [Color8(16,96,184),Color8(24,104,192),Color8(24,112,208)]
	for i in tiles.get_source_count():
		var sid := tiles.get_source_id(i)
		var source := tiles.get_source(sid) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var first := image.get_region(source.get_tile_texture_region(coords,0))
			var hash: String = fingerprint._hash(first.get_data())
			if not catalog.has(hash):
				continue
			var entry: Dictionary = catalog[hash]
			water_tiles[str(sid)+str(coords)] = true
			_check(source.get_tile_animation_frames_count(coords) == 16, "water has sixteen frames")
			for f in source.get_tile_animation_frames_count(coords):
				var frame := image.get_region(source.get_tile_texture_region(coords,f))
				_check(fingerprint._hash(frame.get_data()) == entry.frame_hashes[f], "water frame artwork matches catalog")
				_check(is_equal_approx(source.get_tile_animation_frame_duration(coords,f),0.16), "water timing matches Cerulean")
				for y in 32:
					for x in 32:
						if not first.get_pixel(x,y) in water_colors:
							_check(first.get_pixel(x,y) == frame.get_pixel(x,y), "shore artwork stays fixed")
	var count := 0
	for layer in layers:
		for cell in layer.get_used_cells():
			if water_tiles.has(str(layer.get_cell_source_id(cell))+str(layer.get_cell_atlas_coords(cell))):
				count += 1
	_check(count == int(report.animated_cells.water), "all reported water cells animate")
	_check(water_tiles.size() == int(report.animated_types), "all reported shore variants animate")
