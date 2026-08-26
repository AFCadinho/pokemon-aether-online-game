extends RefCounted


static func directions_for_tile(
	check_position: Vector2,
	ledge_down_tilemap: TileMapLayer,
	ledge_up_tilemap: TileMapLayer,
	ledge_left_tilemap: TileMapLayer,
	ledge_right_tilemap: TileMapLayer
) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if _tilemap_has_tile_at(ledge_down_tilemap, check_position):
		directions.append(Vector2.DOWN)
	if _tilemap_has_tile_at(ledge_up_tilemap, check_position):
		directions.append(Vector2.UP)
	if _tilemap_has_tile_at(ledge_left_tilemap, check_position):
		directions.append(Vector2.LEFT)
	if _tilemap_has_tile_at(ledge_right_tilemap, check_position):
		directions.append(Vector2.RIGHT)
	return directions


static func _tilemap_has_tile_at(tilemap: TileMapLayer, check_position: Vector2) -> bool:
	if tilemap == null:
		return false

	var local_position := tilemap.to_local(check_position)
	var tile_position := tilemap.local_to_map(local_position)
	return tilemap.get_cell_source_id(tile_position) != -1
