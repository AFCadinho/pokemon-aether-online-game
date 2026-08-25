extends SceneTree

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const TallGrassRustleEffectScript := preload("res://scripts/world/tall_grass_rustle_effect.gd")
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096

var failed := false


func _init() -> void:
	_check_depth_row_rustle("TallGrassVisual", false)
	_check_depth_row_rustle("TreeBottom", true)
	_check_ordinary_tree_layer_is_ignored()
	quit(1 if failed else 0)


func _check_depth_row_rustle(layer_name: String, erase_source_cells: bool) -> void:
	var map := Node2D.new()
	var visual_layer := _build_test_layer(layer_name)
	map.add_child(visual_layer)
	var grass_cell := Vector2i(2, 3)
	visual_layer.set_cell(grass_cell, 0, Vector2i.ZERO)

	var row_group := TallGrassDepthSortingScript.build_depth_rows(
		visual_layer,
		visual_layer.get_used_cells(),
		SORT_Z_MIN,
		SORT_Z_MAX,
		erase_source_cells,
		"%sDepthRows" % layer_name
	)
	_check(row_group != null, "%s grass depth row is built" % layer_name)
	if row_group == null:
		map.free()
		return

	var grass_global_position := visual_layer.to_global(visual_layer.map_to_local(grass_cell))
	var source := TallGrassDepthSortingScript.find_depth_row_at_global_position(
		map,
		grass_global_position
	)
	var row_layer := source.get("layer") as TileMapLayer
	var resolved_cell: Vector2i = source.get("tile_position", Vector2i(-1, -1))
	_check(row_layer != null, "%s rustle resolves the visible grass row" % layer_name)
	_check(resolved_cell == grass_cell, "%s rustle resolves the expected grass cell" % layer_name)
	if erase_source_cells:
		_check(
			visual_layer.get_cell_source_id(grass_cell) < 0,
			"legacy visual source can be empty after depth-row extraction"
		)

	if row_layer != null:
		var effect_z_index := TallGrassRustleEffectScript.get_render_z_index(
			row_layer,
			resolved_cell,
			Vector2(row_layer.tile_set.tile_size)
		)
		_check(effect_z_index > row_layer.z_index, "%s rustle renders above static grass" % layer_name)
		_check(
			effect_z_index < row_layer.z_index - TallGrassDepthSortingScript.FOREGROUND_Z_OFFSET + 32,
			"%s rustle remains below the next character row" % layer_name
		)
	map.free()


func _check_ordinary_tree_layer_is_ignored() -> void:
	var map := Node2D.new()
	var tree_layer := _build_test_layer("TreeBottom")
	map.add_child(tree_layer)
	var tree_cell := Vector2i(1, 1)
	tree_layer.set_cell(tree_cell, 0, Vector2i.ZERO)
	var tree_global_position := tree_layer.to_global(tree_layer.map_to_local(tree_cell))
	_check(
		TallGrassDepthSortingScript.find_depth_row_at_global_position(
			map,
			tree_global_position
		).is_empty(),
		"ordinary TreeBottom tiles are not used as rustle sources"
	)
	map.free()


func _build_test_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(32, 32, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, 0)
	layer.tile_set = tile_set
	return layer


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
