extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	var original_map: Node = game_state.current_map
	var first := _make_map("FirstMap")
	var second := _make_map("SecondMap")
	root.add_child(first.map)
	root.add_child(second.map)
	var player: Node = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	first.players.add_child(player)
	game_state.current_map = first.map
	await process_frame

	player.refresh_map_layers()
	_check(player.collision_tilemap == first.collision, "initial refresh resolves the active map")
	var warm_generation: int = player.map_layer_cache_generation
	for index in range(25):
		player._resolve_current_map()
		player._get_ledge_directions_for_tile(Vector2(index * 32, 0))
		player.can_move_to(Vector2(index * 32, 0))
		player.is_standing_on_tall_grass()
		player._get_sand_footprint_offset(Vector2(index * 32, 0))
	_check(player.map_layer_cache_generation == warm_generation,
		"warm movement reuses map layers, including absent terrain layers")

	first.players.remove_child(player)
	second.players.add_child(player)
	game_state.current_map = second.map
	player.can_move_to(Vector2.ZERO)
	_check(player.collision_tilemap == second.collision, "reparenting refreshes layers for the new map")
	_check(player.map_layer_cache_generation == warm_generation + 1,
		"map changes perform exactly one lazy refresh")

	second.collision.name = "PreviousCollision"
	var replacement_collision := TileMapLayer.new()
	replacement_collision.name = "Collision"
	replacement_collision.tile_set = TileSet.new()
	replacement_collision.tile_set.tile_size = Vector2i(32, 32)
	second.tiles.add_child(replacement_collision)
	player.refresh_map_layers()
	_check(player.map_layer_cache_generation == warm_generation + 2,
		"explicit refresh remains available for runtime map construction")
	_check(player.collision_tilemap == replacement_collision,
		"explicit refresh adopts runtime layer replacements")
	game_state.current_map = original_map
	player.free()
	first.map.free()
	second.map.free()
	print("player_map_layer_cache_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _make_map(map_name: String) -> Dictionary:
	var map := Node2D.new()
	map.name = map_name
	var entities := Node2D.new()
	entities.name = "Entities"
	map.add_child(entities)
	var players := Node2D.new()
	players.name = "Players"
	entities.add_child(players)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	map.add_child(tiles)
	var collision := TileMapLayer.new()
	collision.name = "Collision"
	collision.tile_set = TileSet.new()
	collision.tile_set.tile_size = Vector2i(32, 32)
	tiles.add_child(collision)
	return {"map": map, "players": players, "tiles": tiles, "collision": collision}


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
