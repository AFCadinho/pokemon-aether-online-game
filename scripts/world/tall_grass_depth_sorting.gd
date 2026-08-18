extends RefCounted

class_name TallGrassDepthSorting

const DEFAULT_TILE_SIZE := Vector2(32.0, 32.0)
# Player appearance layers reach relative Z 10 and the follower can use 11
# while resolving an overlap. Keep same-row grass above the complete character,
# but below a character standing one 32 px row farther south.
const FOREGROUND_Z_OFFSET := 16


static func get_row_z_index(
	grass_layer: TileMapLayer,
	row: int,
	z_min: int,
	z_max: int
) -> int:
	var tile_size := DEFAULT_TILE_SIZE
	if grass_layer.tile_set != null:
		tile_size = Vector2(grass_layer.tile_set.tile_size)

	var row_center_local := grass_layer.map_to_local(Vector2i(0, row))
	var row_bottom_global := grass_layer.to_global(
		row_center_local + Vector2(0.0, tile_size.y * 0.5)
	).y
	return clampi(
		floori(row_bottom_global) + FOREGROUND_Z_OFFSET,
		z_min,
		z_max
	)
