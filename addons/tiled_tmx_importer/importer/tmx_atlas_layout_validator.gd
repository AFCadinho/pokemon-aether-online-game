@tool
extends RefCounted

const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")

func validate(root: Node, expected_path := "") -> Array[String]:
	var failures: Array[String] = []
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(root, layers)
	if layers.is_empty():
		failures.append("Missing visual tile layers.")
		return failures
	var tile_set := layers[0].tile_set
	if tile_set == null or int(tile_set.get_meta("tiled_compact_atlas_version", 0)) != Compactor.VERSION:
		failures.append("Missing compact atlas version; reimport this visual.")
		return failures
	if expected_path != "" and tile_set.resource_path != expected_path:
		failures.append("Scene does not reference its saved compact TileSet.")
	var used := {}
	for layer in layers:
		if layer.tile_set != tile_set:
			failures.append("Visual layers do not share a TileSet.")
			continue
		for cell in layer.get_used_cells():
			var id := layer.get_cell_source_id(cell)
			if not tile_set.has_source(id):
				failures.append("Cell refers to a missing atlas source.")
				continue
			var source := tile_set.get_source(id) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var alternative := layer.get_cell_alternative_tile(cell) & ~(4096 | 8192 | 16384)
			if source == null or not source.has_tile(coords) or not source.has_alternative_tile(coords, alternative):
				failures.append("Cell refers to a missing atlas tile/alternative.")
			if not used.has(id):
				used[id] = {}
			used[id][layer.get_cell_atlas_coords(cell)] = true
	if used.size() != tile_set.get_source_count():
		failures.append("Unused or missing atlas source.")
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var source := tile_set.get_source(id) as TileSetAtlasSource
		if source == null or source.texture == null:
			failures.append("Invalid atlas source.")
			continue
		if source.get_tiles_count() != used.get(id, {}).size():
			failures.append("Atlas contains unused tile definitions.")
		for coords in used.get(id, {}):
			if source.has_tile(coords) and source.get_tile_animation_frames_count(coords) != 1:
				failures.append("Animated tiles require an animation-aware compact layout.")
		var texture := source.texture as PortableCompressedTexture2D
		if texture == null or texture.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS:
			failures.append("Atlas must use portable lossless compression.")
		if expected_path != "" and (not source.texture.resource_path.begins_with(expected_path.get_base_dir() + "/assets/") or not source.texture.resource_path.ends_with(".texture.res")):
			failures.append("Atlas textures must be saved external resources.")
		var slot := source.texture_region_size + Vector2i.ONE * Compactor.BORDER * 2
		if slot.x > Compactor.LIMIT or slot.y > Compactor.LIMIT or source.get_tiles_count() == 0:
			failures.append("Invalid compact tile dimensions/count.")
			continue
		var columns := mini(Compactor.COLUMNS, Compactor.LIMIT / slot.x)
		var width := mini(columns, source.get_tiles_count()) * slot.x
		var power := 1
		while power < width:
			power *= 2
		width = mini(power, Compactor.LIMIT)
		var height := ceili(float(source.get_tiles_count()) / columns) * slot.y
		if source.texture.get_width() != width or source.texture.get_height() != height or height > Compactor.LIMIT:
			failures.append("Atlas canvas is oversized or violates compact layout.")
		if source.margins != Vector2i.ONE * Compactor.BORDER or source.separation != Vector2i.ONE * Compactor.BORDER * 2:
			failures.append("Compact atlas padding is invalid.")
	return failures
