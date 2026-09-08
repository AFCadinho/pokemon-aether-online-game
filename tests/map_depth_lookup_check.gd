extends SceneTree

const Grass := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const Depth := preload("res://scripts/world/map_depth_sorting.gd")
var failed := false

func _init() -> void:
	var map := Node2D.new()
	map.position = Vector2(192, -64)
	map.scale = Vector2(1.5, 1.5)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	var decoration := _layer(map, tile_set, 900, false)
	var first := _layer(map, tile_set, 100, true)
	var second := _layer(map, tile_set, 200, true)
	first.visible = false
	var rows := Grass.collect_depth_rows(map)
	_check(rows == [first, second], "lookup preserves traversal order and hidden grass semantics")
	var position := first.to_global(first.map_to_local(Vector2i.ZERO))
	_check(Grass.find_depth_row_in_layers(rows, position).get("layer") == first, "overlapping rows preserve first-match precedence under map transforms")
	_check(Depth.get_tall_grass_overlap_z_floor(rows, decoration, [Vector2i.ZERO], -4096, 4096) == 101, "structure floor uses first matching row")
	_check(Depth.get_tall_grass_overlap_z_floor(rows, decoration, [Vector2i.ZERO], -4096, 50) == 50, "maximum depth remains clamped")
	_check(Depth.get_tall_grass_overlap_z_floor(rows, decoration, [Vector2i(100, 100)], -4096, 4096) == -4096, "non-overlapping cells preserve minimum depth")
	_check(Depth.get_tall_grass_overlap_z_floor([], decoration, [Vector2i.ZERO], -4096, 4096) == -4096, "maps without grass need no per-tile lookup")
	map.remove_child(first)
	first.free()
	rows = Grass.collect_depth_rows(map)
	_check(rows == [second], "next construction pass sees changed map layers")
	_check(Grass.find_depth_row_at_global_position(map, position).get("layer") == second, "live lookup does not retain a removed row")
	map.free()
	var fresh_map := Node2D.new()
	_check(Grass.collect_depth_rows(fresh_map).is_empty(), "next map cannot inherit previous map rows")
	fresh_map.free()
	print("map_depth_lookup_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _layer(parent: Node, tile_set: TileSet, z: int, grass: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = Vector2(32, 64)
	layer.z_index = z
	if grass:
		layer.set_meta(Grass.DEPTH_ROW_META, true)
	layer.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	parent.add_child(layer)
	return layer

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
