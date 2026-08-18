extends RefCounted

class_name TallGrassDepthSorting

const DEFAULT_TILE_SIZE := Vector2(32.0, 32.0)
const LEGACY_MARKER_LAYER_NAMES: Array[String] = ["TallGrass"]
const DEPTH_ROW_META := "pao_tall_grass_depth_row"
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


static func find_legacy_grass_visual_source(root: Node) -> Dictionary:
	# Route 22 predates dedicated visual grass layers: its grass sprite is mixed
	# into TreeBottom while TallGrass only supplies a hidden encounter mask.
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers(root, layers)
	var marker_layers: Array[TileMapLayer] = []
	for layer: TileMapLayer in layers:
		var tiled_name := str(layer.get_meta("tiled_name", layer.name))
		if LEGACY_MARKER_LAYER_NAMES.has(tiled_name):
			marker_layers.append(layer)

	for marker_layer: TileMapLayer in marker_layers:
		if marker_layer.tile_set == null or marker_layer.get_used_cells().is_empty():
			continue
		for candidate: TileMapLayer in layers:
			if candidate == marker_layer or not candidate.visible or candidate.tile_set == null:
				continue
			var match := _match_exact_visual_tile_mask(marker_layer, candidate)
			if not match.is_empty():
				return match
	return {}


static func build_depth_rows(
	grass_layer: TileMapLayer,
	used_cells: Array[Vector2i],
	z_min: int,
	z_max: int,
	erase_source_cells: bool,
	group_name: String
) -> Node2D:
	if grass_layer == null or used_cells.is_empty():
		return null
	var parent := grass_layer.get_parent()
	if parent == null:
		return null

	var rows: Dictionary = {}
	for cell: Vector2i in used_cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell)

	var row_group := Node2D.new()
	row_group.name = group_name
	row_group.set_meta(DEPTH_ROW_META, true)
	parent.add_child(row_group)

	for row: int in rows.keys():
		var row_layer := TileMapLayer.new()
		row_layer.name = "%sRow%d" % [grass_layer.name, row]
		row_layer.tile_set = grass_layer.tile_set
		row_layer.visible = grass_layer.visible
		row_layer.modulate = grass_layer.modulate
		row_layer.self_modulate = grass_layer.self_modulate
		row_layer.transform = grass_layer.transform
		row_layer.material = grass_layer.material
		row_layer.texture_filter = grass_layer.texture_filter
		row_layer.texture_repeat = grass_layer.texture_repeat
		row_layer.light_mask = grass_layer.light_mask
		row_layer.visibility_layer = grass_layer.visibility_layer
		row_layer.z_as_relative = false
		row_layer.z_index = get_row_z_index(grass_layer, row, z_min, z_max)
		row_layer.set_meta(DEPTH_ROW_META, true)
		row_group.add_child(row_layer)

		for cell: Vector2i in rows[row]:
			var source_id := grass_layer.get_cell_source_id(cell)
			if source_id < 0:
				continue
			row_layer.set_cell(
				cell,
				source_id,
				grass_layer.get_cell_atlas_coords(cell),
				grass_layer.get_cell_alternative_tile(cell)
			)
			if erase_source_cells:
				grass_layer.erase_cell(cell)
	return row_group


static func _match_exact_visual_tile_mask(
	marker_layer: TileMapLayer,
	candidate: TileMapLayer
) -> Dictionary:
	# Only extract a visual tile when its complete occurrence set equals the
	# marker mask. This strict match prevents trees or ordinary ground tiles
	# from being reclassified as grass on other legacy maps.
	var source_cells: Array[Vector2i] = []
	var source_cell_set: Dictionary = {}
	var matched_source_id := -1
	var matched_atlas_coords := Vector2i(-1, -1)
	var matched_alternative := -1

	for marker_cell: Vector2i in marker_layer.get_used_cells():
		var marker_center_global := marker_layer.to_global(marker_layer.map_to_local(marker_cell))
		var source_cell := candidate.local_to_map(candidate.to_local(marker_center_global))
		if source_cell_set.has(source_cell):
			return {}
		var source_id := candidate.get_cell_source_id(source_cell)
		if source_id < 0:
			return {}
		var atlas_coords := candidate.get_cell_atlas_coords(source_cell)
		var alternative := candidate.get_cell_alternative_tile(source_cell)
		if matched_source_id < 0:
			matched_source_id = source_id
			matched_atlas_coords = atlas_coords
			matched_alternative = alternative
		elif (
			source_id != matched_source_id
			or atlas_coords != matched_atlas_coords
			or alternative != matched_alternative
		):
			return {}
		source_cells.append(source_cell)
		source_cell_set[source_cell] = true

	var matching_tile_count := 0
	for candidate_cell: Vector2i in candidate.get_used_cells():
		if (
			candidate.get_cell_source_id(candidate_cell) != matched_source_id
			or candidate.get_cell_atlas_coords(candidate_cell) != matched_atlas_coords
			or candidate.get_cell_alternative_tile(candidate_cell) != matched_alternative
		):
			continue
		matching_tile_count += 1
		if not source_cell_set.has(candidate_cell):
			return {}

	if matching_tile_count != source_cells.size():
		return {}
	return {
		"marker_layer": marker_layer,
		"visual_layer": candidate,
		"cells": source_cells,
	}


static func _collect_tilemap_layers(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		layers.append(node as TileMapLayer)
	for child: Node in node.get_children():
		_collect_tilemap_layers(child, layers)
