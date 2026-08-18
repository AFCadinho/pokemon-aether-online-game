extends SceneTree

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const ROUTE_22_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_22.tscn"
const ROUTE_22_VISUAL_SCENE_PATH := "res://generated/tiled_visuals/kanto_route_22/kanto_route_22.visual.tscn"
const MAP_SCENES: Array[String] = [
	"res://generated/tiled_visuals/route_1/route_1.visual.tscn",
	"res://generated/tiled_visuals/kanto_route_2/kanto_route_2.visual.tscn",
	"res://generated/tiled_visuals/route_3/route_3.visual.tscn",
	"res://generated/tiled_visuals/viridian_forest/viridian_forest.visual.tscn",
	"res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn",
]
const MAX_CHARACTER_RELATIVE_Z := 11
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096

var failed := false


func _init() -> void:
	_check(
		TallGrassDepthSortingScript.FOREGROUND_Z_OFFSET > MAX_CHARACTER_RELATIVE_Z,
		"same-row grass renders above every player and follower visual layer"
	)
	_check(
		TallGrassDepthSortingScript.FOREGROUND_Z_OFFSET < 32,
		"grass remains below a character standing one tile row farther south"
	)

	for scene_path: String in MAP_SCENES:
		var packed_scene := load(scene_path) as PackedScene
		var map := packed_scene.instantiate()
		var grass_layer := _find_grass_layer(map)
		if grass_layer == null:
			_check(false, "visual grass layer exists in %s" % scene_path)
			map.free()
			continue

		var used_cells := grass_layer.get_used_cells()
		var checked_rows: Dictionary = {}
		for cell: Vector2i in used_cells:
			if checked_rows.has(cell.y):
				continue
			checked_rows[cell.y] = true
			_check_grass_row_depth(grass_layer, cell.y, scene_path)
		map.free()

	_check_route_22_legacy_grass_source()

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("TallGrassDepthSortingScript.build_depth_rows("),
		"world map normalization uses the tested tall-grass row builder"
	)
	_check(
		world_source.contains("find_legacy_grass_visual_source(map)"),
		"world map normalization includes legacy mixed grass layers"
	)
	quit(1 if failed else 0)


func _check_route_22_legacy_grass_source() -> void:
	var map := Node2D.new()
	var visual_scene := load(ROUTE_22_VISUAL_SCENE_PATH) as PackedScene
	map.add_child(visual_scene.instantiate())
	var route_source := FileAccess.get_file_as_string(ROUTE_22_SCENE_PATH)
	var marker_layer := _build_route_22_grass_marker(route_source)
	map.add_child(marker_layer)
	var legacy_match := TallGrassDepthSortingScript.find_legacy_grass_visual_source(map)
	_check(not legacy_match.is_empty(), "Route 22 legacy grass visual source is detected")
	if legacy_match.is_empty():
		map.free()
		return

	marker_layer = legacy_match.get("marker_layer") as TileMapLayer
	var visual_layer := legacy_match.get("visual_layer") as TileMapLayer
	var cells: Array[Vector2i] = []
	for cell: Vector2i in legacy_match.get("cells", []):
		cells.append(cell)
	_check(marker_layer != null, "Route 22 exposes its TallGrass encounter mask")
	_check(visual_layer != null, "Route 22 exposes the matching visual grass tiles")
	if marker_layer != null and visual_layer != null:
		var tiled_name := str(visual_layer.get_meta("tiled_name", visual_layer.name))
		_check(tiled_name == "TreeBottom", "Route 22 grass is isolated from TreeBottom")
		_check(
			cells.size() == marker_layer.get_used_cells().size() and cells.size() == 253,
			"all 253 Route 22 grass visuals match the encounter mask"
		)
		var original_visual_cell_count := visual_layer.get_used_cells().size()
		var row_group := TallGrassDepthSortingScript.build_depth_rows(
			visual_layer,
			cells,
			SORT_Z_MIN,
			SORT_Z_MAX,
			true,
			"Route22TallGrassDepthRows"
		)
		_check(row_group != null, "Route 22 grass depth rows are built")
		if row_group != null:
			var moved_cell_count := 0
			for child: Node in row_group.get_children():
				var row_layer := child as TileMapLayer
				if row_layer == null:
					continue
				var row_cells := row_layer.get_used_cells()
				moved_cell_count += row_cells.size()
				if not row_cells.is_empty():
					_check_created_grass_row_depth(row_layer, row_cells[0].y)
			_check(moved_cell_count == 253, "all Route 22 grass visuals move into depth rows")
		_check(
			visual_layer.get_used_cells().size() == original_visual_cell_count - 253,
			"Route 22 trees remain while only grass leaves TreeBottom"
		)
	map.free()


func _check_created_grass_row_depth(grass_layer: TileMapLayer, row: int) -> void:
	var tile_size := Vector2(grass_layer.tile_set.tile_size)
	var row_center := grass_layer.map_to_local(Vector2i(0, row))
	var row_bottom_y := floori(grass_layer.to_global(
		row_center + Vector2(0.0, tile_size.y * 0.5)
	).y)
	_check(
		grass_layer.z_index > row_bottom_y + MAX_CHARACTER_RELATIVE_Z,
		"Route 22 grass row %d covers player and follower layers" % row
	)
	_check(
		grass_layer.z_index < row_bottom_y + int(tile_size.y),
		"Route 22 grass row %d remains behind the next character row" % row
	)


func _build_route_22_grass_marker(route_source: String) -> TileMapLayer:
	var marker_layer := TileMapLayer.new()
	marker_layer.name = "TallGrass"
	marker_layer.visible = false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(32, 32, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, 0)
	marker_layer.tile_set = tile_set

	var marker_node_start := route_source.find('[node name="TallGrass" type="TileMapLayer"')
	var data_prefix := 'tile_map_data = PackedByteArray("'
	var data_start := route_source.find(data_prefix, marker_node_start)
	var data_end := route_source.find('")', data_start + data_prefix.length())
	_check(marker_node_start >= 0 and data_start >= 0 and data_end > data_start, "Route 22 TallGrass mask data is readable")
	if marker_node_start < 0 or data_start < 0 or data_end <= data_start:
		return marker_layer

	var encoded := route_source.substr(
		data_start + data_prefix.length(),
		data_end - data_start - data_prefix.length()
	)
	var raw := Marshalls.base64_to_raw(encoded)
	_check((raw.size() - 2) % 12 == 0, "Route 22 TallGrass mask uses complete tile records")
	for offset: int in range(2, raw.size(), 12):
		var cell := Vector2i(raw.decode_u16(offset), raw.decode_u16(offset + 2))
		marker_layer.set_cell(cell, 0, Vector2i.ZERO)
	return marker_layer


func _check_grass_row_depth(grass_layer: TileMapLayer, row: int, scene_path: String) -> void:
	var tile_size := Vector2(grass_layer.tile_set.tile_size)
	var row_center := grass_layer.map_to_local(Vector2i(0, row))
	var row_bottom_y := floori(grass_layer.to_global(
		row_center + Vector2(0.0, tile_size.y * 0.5)
	).y)
	var row_z := TallGrassDepthSortingScript.get_row_z_index(
		grass_layer,
		row,
		SORT_Z_MIN,
		SORT_Z_MAX
	)
	_check(
		row_z > row_bottom_y + MAX_CHARACTER_RELATIVE_Z,
		"%s grass row %d covers a character standing in that row" % [scene_path, row]
	)
	_check(
		row_z < row_bottom_y + int(tile_size.y),
		"%s grass row %d stays behind the next character row" % [scene_path, row]
	)


func _find_grass_layer(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		var tiled_name := str(layer.get_meta("tiled_name", layer.name))
		if tiled_name in ["TallGrassVisual", "Grass"]:
			return layer
	for child: Node in node.get_children():
		var found := _find_grass_layer(child)
		if found != null:
			return found
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
