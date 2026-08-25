extends RefCounted

const VISUAL_NAME := "ClanWarsMapX1Jail"
const OBJECTS_TOP_NAME := "ObjectsTop"
const JAIL_TOP_LAYER_NAME := "JailTop"
const LEGACY_JAIL_BARS_LAYER_NAME := "JailBarsTop"
const JAIL_BARS_RECT := Rect2i(66, 71, 9, 3)
# The jail spawn sits one tile south of the bars. Put the draw boundary
# halfway between that spawn tile and the tile immediately north of it.
const JAIL_BARS_DEPTH_OFFSET := 32
const NO_OVERLAY_Z_FLOOR := -4096


static func get_depth_boundary_offset(tiled_name: String) -> int:
	return (
		JAIL_BARS_DEPTH_OFFSET
		if tiled_name in [JAIL_TOP_LAYER_NAME, LEGACY_JAIL_BARS_LAYER_NAME]
		else 0
	)


static func get_objects_top_overlay_z_floor(
	objects_top: TileMapLayer,
	group: Array[Vector2i]
) -> int:
	if objects_top == null:
		return NO_OVERLAY_Z_FLOOR
	var tiled_name := str(objects_top.get_meta("tiled_name", objects_top.name))
	if tiled_name != OBJECTS_TOP_NAME:
		return NO_OVERLAY_Z_FLOOR
	var parent := objects_top.get_parent()
	if parent == null:
		return NO_OVERLAY_Z_FLOOR
	var jail_top := parent.get_node_or_null(JAIL_TOP_LAYER_NAME) as TileMapLayer
	if jail_top == null:
		return NO_OVERLAY_Z_FLOOR

	var overlap_seed := Vector2i(-1, -1)
	for cell: Vector2i in group:
		if jail_top.get_cell_source_id(cell) != -1:
			overlap_seed = cell
			break
	if overlap_seed == Vector2i(-1, -1):
		return NO_OVERLAY_Z_FLOOR
	var connected_jail_cells: Array[Vector2i] = []
	var pending: Array[Vector2i] = [overlap_seed]
	var visited := {overlap_seed: true}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while not pending.is_empty():
		var jail_cell: Vector2i = pending.pop_back()
		connected_jail_cells.append(jail_cell)
		for direction: Vector2i in directions:
			var neighbor: Vector2i = jail_cell + direction
			if visited.has(neighbor) or jail_top.get_cell_source_id(neighbor) == -1:
				continue
			visited[neighbor] = true
			pending.append(neighbor)

	var tile_size := Vector2(32.0, 32.0)
	if jail_top.tile_set != null:
		tile_size = Vector2(jail_top.tile_set.tile_size)
	var jail_top_bottom_y := -INF
	for cell: Vector2i in connected_jail_cells:
		jail_top_bottom_y = maxf(
			jail_top_bottom_y,
			jail_top.to_global(jail_top.map_to_local(cell) + tile_size * 0.5).y
		)
	if is_inf(jail_top_bottom_y):
		return NO_OVERLAY_Z_FLOOR
	return floori(jail_top_bottom_y) + JAIL_BARS_DEPTH_OFFSET + 1


static func split_jail_bars_for_depth_sorting(map: Node) -> void:
	var visual := map.find_child(VISUAL_NAME, true, false)
	if visual == null:
		return
	var objects_top := visual.get_node_or_null(OBJECTS_TOP_NAME) as TileMapLayer
	if (
		objects_top == null
		or visual.get_node_or_null(JAIL_TOP_LAYER_NAME) != null
		or visual.get_node_or_null(LEGACY_JAIL_BARS_LAYER_NAME) != null
	):
		return

	var jail_bars := TileMapLayer.new()
	jail_bars.name = LEGACY_JAIL_BARS_LAYER_NAME
	jail_bars.tile_set = objects_top.tile_set
	jail_bars.position = objects_top.position
	jail_bars.z_index = objects_top.z_index
	jail_bars.z_as_relative = objects_top.z_as_relative
	jail_bars.visible = objects_top.visible
	jail_bars.modulate = objects_top.modulate
	jail_bars.self_modulate = objects_top.self_modulate
	jail_bars.set_meta("tiled_name", LEGACY_JAIL_BARS_LAYER_NAME)
	jail_bars.set_meta("tiled_visual_layer", true)
	visual.add_child(jail_bars)

	var moved_cell_count := 0
	for y in range(JAIL_BARS_RECT.position.y, JAIL_BARS_RECT.end.y):
		for x in range(JAIL_BARS_RECT.position.x, JAIL_BARS_RECT.end.x):
			var cell := Vector2i(x, y)
			var source_id := objects_top.get_cell_source_id(cell)
			if source_id == -1:
				continue
			jail_bars.set_cell(
				cell,
				source_id,
				objects_top.get_cell_atlas_coords(cell),
				objects_top.get_cell_alternative_tile(cell)
			)
			objects_top.erase_cell(cell)
			moved_cell_count += 1

	if moved_cell_count == 0:
		jail_bars.queue_free()
