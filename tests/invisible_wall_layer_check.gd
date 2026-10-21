extends SceneTree

const WallLayer := preload("res://scripts/world/invisible_wall_layer.gd")
const CharacterBlocking := preload("res://scripts/world/map_character_blocking.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Independent fixture: no authored map layout is prescribed by this test.
	var map := Node2D.new()
	map.position = Vector2(4096, 2048)
	var entities := Node2D.new()
	entities.name = "Entities"
	map.add_child(entities)
	var interactables := Node2D.new()
	interactables.name = "Interactables"
	entities.add_child(interactables)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	map.add_child(tiles)
	var collision := TileMapLayer.new()
	collision.name = "Collision"
	collision.tile_set = TileSet.new()
	tiles.add_child(collision)
	var walls := WallLayer.new()
	walls.visible = false
	walls.position = Vector2(96, -32)
	walls.tile_set = TileSet.new()
	walls.tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	walls.tile_set.add_source(atlas, 0)
	walls.set_cell(Vector2i(2, 3), 0, Vector2i.ZERO)
	interactables.add_child(walls)
	root.add_child(map)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	entities.add_child(player)
	player.refresh_map_layers()
	var blocked := walls.to_global(walls.map_to_local(Vector2i(2, 3)))
	var open := walls.to_global(walls.map_to_local(Vector2i(3, 3)))
	_check(walls.blocks_world_position(blocked), "Hidden cells block in transformed world coordinates")
	_check(not walls.blocks_world_position(open), "Empty puzzle cells stay open")
	_check(CharacterBlocking.is_position_blocked_by_character(map, blocked), "Map blocker discovery includes the puzzle layer")
	_check(not player.can_move_to(blocked) and player.can_move_to(open), "Real player movement respects the separate layer")
	walls.blocking_enabled = false
	_check(player.can_move_to(blocked), "Disabling the puzzle releases its cells")
	walls.blocking_enabled = true
	walls.erase_cell(Vector2i(2, 3))
	_check(player.can_move_to(blocked), "Editing a cell takes effect without rebuilding the blocker index")
	_check(collision.get_used_cells().is_empty(), "Puzzle queries never modify ordinary collision")
	map.free()
	print("INVISIBLE_WALL_LAYER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
