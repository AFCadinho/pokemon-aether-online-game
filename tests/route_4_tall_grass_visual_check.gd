extends SceneTree

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const ROUTE_4_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
const ROUTE_4_VISUAL_SCENE_PATH := "res://generated/tiled_visuals/route_4/route_4.visual.tscn"
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_4_SCENE_PATH)
	_check(
		route_source.contains('[node name="TallGrass" type="TileMapLayer" parent="Tiles"'),
		"Route 4 exposes its TallGrass scene mask under Tiles"
	)
	var marker_layer := _build_route_4_grass_marker(route_source)
	_check(not marker_layer.visible, "Route 4 keeps its encounter mask invisible")
	_check(marker_layer.get_used_cells().size() == 142, "Route 4 exposes all 142 grass cells")

	var map := Node2D.new()
	var visual_scene := load(ROUTE_4_VISUAL_SCENE_PATH) as PackedScene
	map.add_child(visual_scene.instantiate())
	map.add_child(marker_layer)

	var legacy_match := TallGrassDepthSortingScript.find_legacy_grass_visual_source(map)
	_check(not legacy_match.is_empty(), "Route 4 grass visual source is detected")
	if legacy_match.is_empty():
		map.free()
		quit(1)
		return

	var visual_layer := legacy_match.get("visual_layer") as TileMapLayer
	var cells: Array[Vector2i] = []
	for cell: Vector2i in legacy_match.get("cells", []):
		cells.append(cell)
	_check(visual_layer != null, "Route 4 exposes matching visual grass tiles")
	if visual_layer != null:
		_check(
			str(visual_layer.get_meta("tiled_name", visual_layer.name)) == "GroundDetail",
			"Route 4 isolates grass from GroundDetail"
		)
	_check(cells.size() == 142, "Route 4 matches every grass visual to its encounter mask")

	var row_group := TallGrassDepthSortingScript.build_depth_rows(
		visual_layer,
		cells,
		SORT_Z_MIN,
		SORT_Z_MAX,
		true,
		"Route4TallGrassDepthRows"
	)
	_check(row_group != null, "Route 4 builds visible grass depth rows")
	if row_group != null and not marker_layer.get_used_cells().is_empty():
		var marker_cell := marker_layer.get_used_cells()[0]
		var grass_global_position := marker_layer.to_global(marker_layer.map_to_local(marker_cell))
		_check(
			not TallGrassDepthSortingScript.find_depth_row_at_global_position(
				map,
				grass_global_position
			).is_empty(),
			"Route 4 rustle resolves the visible grass row"
		)

	map.free()
	quit(1 if failed else 0)


func _build_route_4_grass_marker(route_source: String) -> TileMapLayer:
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
	_check(
		marker_node_start >= 0 and data_start >= 0 and data_end > data_start,
		"Route 4 TallGrass mask data is readable"
	)
	if marker_node_start < 0 or data_start < 0 or data_end <= data_start:
		return marker_layer

	var encoded := route_source.substr(
		data_start + data_prefix.length(),
		data_end - data_start - data_prefix.length()
	)
	var raw := Marshalls.base64_to_raw(encoded)
	_check((raw.size() - 2) % 12 == 0, "Route 4 TallGrass mask uses complete tile records")
	for offset: int in range(2, raw.size(), 12):
		var cell := Vector2i(raw.decode_u16(offset), raw.decode_u16(offset + 2))
		marker_layer.set_cell(cell, 0, Vector2i.ZERO)
	return marker_layer


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
