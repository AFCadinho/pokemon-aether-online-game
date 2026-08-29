extends RefCounted

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")


static func get_tall_grass_overlap_z_floor(
	map: Node,
	layer: TileMapLayer,
	group: Array[Vector2i],
	minimum_z: int,
	maximum_z: int
) -> int:
	if map == null or layer == null:
		return minimum_z

	var sort_z_floor := minimum_z
	for cell: Vector2i in group:
		var cell_center_position := layer.to_global(layer.map_to_local(cell))
		var grass_match := TallGrassDepthSortingScript.find_depth_row_at_global_position(
			map,
			cell_center_position
		)
		var grass_row := grass_match.get("layer") as TileMapLayer
		if grass_row == null:
			continue
		sort_z_floor = maxi(sort_z_floor, grass_row.z_index + 1)
	return clampi(sort_z_floor, minimum_z, maximum_z)


static func get_structure_top_group_z_floor(
	map: Node,
	layer: TileMapLayer,
	group: Array[Vector2i],
	minimum_z: int,
	maximum_z: int
) -> int:
	if map == null or not map.has_method("get_structure_top_sort_z_floor"):
		return minimum_z

	var tile_size := Vector2(32.0, 32.0)
	if layer.tile_set != null:
		tile_size = Vector2(layer.tile_set.tile_size)

	var sort_z_floor := minimum_z
	for cell: Vector2i in group:
		var cell_bottom_position := layer.to_global(
			layer.map_to_local(cell) + Vector2(0.0, tile_size.y * 0.5)
		)
		sort_z_floor = maxi(
			sort_z_floor,
			int(map.call("get_structure_top_sort_z_floor", cell_bottom_position))
		)
	return clampi(sort_z_floor, minimum_z, maximum_z)
