@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const Animations := preload("res://addons/tiled_tmx_importer/importer/tmx_tile_animations.gd")
const VERSION := 1
const LIMIT := Animations.LIMIT
const BORDER := Animations.BORDER
const COLUMNS := Animations.COLUMNS

# Import-time only. No resizing, scene-tree entry or gameplay side effects.
func compact(root: Node, output_tileset_path: String, animations: Dictionary = {}) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	_collect(root, layers)
	if layers.is_empty():
		return {"success": false, "error": "Atlas compaction requires tile layers."}
	var original := layers[0].tile_set
	if original == null:
		return {"success": false, "error": "Atlas compaction requires a TileSet."}
	var used := {}
	for layer in layers:
		if layer.tile_set != original:
			return {"success": false, "error": "Visual layers must share one TileSet."}
		for cell in layer.get_used_cells():
			var id := layer.get_cell_source_id(cell)
			if not used.has(id):
				used[id] = {}
			used[id][layer.get_cell_atlas_coords(cell)] = true
	# Preserve existing native timelines when recompacting an animated map.
	# New/overridden timelines may still reference the original dense sources.
	animations = animations.duplicate(true)
	for id in animations.keys():
		for coords in animations[id].keys():
			if not used.get(id, {}).has(coords):
				animations[id].erase(coords)
		if animations[id].is_empty():
			animations.erase(id)
	# Validate everything before writing or mutating any cells.
	for id in used:
		if not original.has_source(id):
			return {"success": false, "error": "Visual cell references a missing atlas source."}
		var source := original.get_source(id) as TileSetAtlasSource
		if source == null or source.texture == null:
			return {"success": false, "error": "Only textured atlas sources support compaction."}
		var slot := source.texture_region_size + Vector2i.ONE * BORDER * 2
		if slot.x > LIMIT or slot.y > LIMIT:
			return {"success": false, "error": "Tile plus lossless atlas padding exceeds 4096px."}
		for coords in used[id]:
			if not source.has_tile(coords):
				return {"success": false, "error": "Visual cell references a missing atlas tile."}
			if source.get_tile_size_in_atlas(coords) != Vector2i.ONE:
				return {"success": false, "error": "Multi-cell atlas tiles are not supported."}
			var frame_count := source.get_tile_animation_frames_count(coords)
			if frame_count > 1 and not animations.get(id, {}).has(coords):
				if source.get_tile_animation_speed(coords) <= 0 or frame_count > mini(COLUMNS, LIMIT / slot.x) * (LIMIT / slot.y):
					return {"success": false, "error": "Invalid native animation speed/size."}
				var frames: Array = []
				for f in frame_count:
					var duration := source.get_tile_animation_frame_duration(coords,f) / source.get_tile_animation_speed(coords)
					if duration <= 0:
						return {"success": false, "error": "Invalid native animation duration."}
					frames.append({"source_id":id,"atlas_coords":coords,"frame_index":f,"duration":duration*1000.0})
				if not animations.has(id):
					animations[id] = {}
				animations[id][coords] = frames
	var compact_set := original.duplicate(false) as TileSet
	# The dense builder signature must never authorize reusing a remapped layout.
	if compact_set.has_meta("tiled_source_signature"):
		compact_set.remove_meta("tiled_source_signature")
	for i in range(compact_set.get_source_count() - 1, -1, -1):
		compact_set.remove_source(compact_set.get_source_id(i))
	compact_set.set_meta("tiled_compact_atlas_version", VERSION)
	var mappings := {}
	var paths: Array[String] = []
	var base_bytes := 0
	# Tiled firstgid values can produce source IDs above Godot's serialized
	# TileMapLayer range. Reassign compact IDs before writing cell data.
	var next_id := 0
	for i in original.get_source_count():
		var id := original.get_source_id(i)
		if not used.has(id):
			continue
		var old := original.get_source(id) as TileSetAtlasSource
		var pixels := old.texture.get_image()
		if pixels == null or pixels.is_empty():
			return {"success": false, "error": "Could not read atlas pixels for source %d." % id}
		pixels.convert(Image.FORMAT_RGBA8)
		var size := old.texture_region_size
		var slot := size + Vector2i.ONE * BORDER * 2
		var columns := mini(COLUMNS, LIMIT / slot.x)
		var capacity := columns * (LIMIT / slot.y)
		var coords: Array = used[id].keys().filter(func(c): return not animations.get(id, {}).has(c))
		coords.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
		mappings[id] = {}
		var chunk := 0
		for start in range(0, coords.size(), capacity):
			var count := mini(capacity, coords.size() - start)
			var width := mini(columns, count) * slot.x
			# Keep the Pallet prototype's power-of-two width, never exceeding LIMIT.
			var power := 1
			while power < width:
				power *= 2
			width = mini(power, LIMIT)
			var height := ceili(float(count) / columns) * slot.y
			var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			var source := TileSetAtlasSource.new()
			source.texture_region_size = size
			source.margins = Vector2i.ONE * BORDER
			source.separation = Vector2i.ONE * BORDER * 2
			source.use_texture_padding = old.use_texture_padding
			source.texture = ImageTexture.create_from_image(image)
			var new_id := next_id
			next_id += 1
			compact_set.add_source(source, new_id)
			for n in count:
				var before: Vector2i = coords[start + n]
				var after := Vector2i(n % columns, n / columns)
				image.blit_rect(pixels, old.get_tile_texture_region(before), after * slot + Vector2i.ONE * BORDER)
				source.create_tile(after)
				for a in old.get_alternative_tiles_count(before):
					var alternative := old.get_alternative_tile_id(before, a)
					if alternative != 0:
						source.create_alternative_tile(after, alternative)
					_copy_data(old.get_tile_data(before, alternative), source.get_tile_data(after, alternative))
				mappings[id][before] = {"source": new_id, "coords": after}
			var texture := PortableCompressedTexture2D.new()
			texture.keep_compressed_buffer = true
			texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
			var texture_path := output_tileset_path.get_base_dir().path_join("assets/%s.compact_source_%d_%d.texture.res" % [output_tileset_path.get_file().get_basename(), id, chunk])
			var error := PathUtils.ensure_resource_directory(texture_path)
			if error == OK:
				error = ResourceSaver.save(texture, texture_path, ResourceSaver.FLAG_CHANGE_PATH)
			if error != OK:
				return {"success": false, "error": "Could not save compact atlas: %s" % error_string(error)}
			# FLAG_CHANGE_PATH does not set user:// paths. Explicit ownership keeps
			# saved scenes external and cached references current in both namespaces.
			texture.take_over_path(texture_path)
			source.texture = texture
			paths.append(texture_path)
			base_bytes += width * height * 4
			chunk += 1
	var animation_result := Animations.new().append_compact(original, compact_set, animations, mappings, output_tileset_path, next_id)
	if not animation_result.get("success", false):
		return animation_result
	paths.append_array(animation_result.texture_paths)
	base_bytes += int(animation_result.base_rgba_bytes)
	var save_error := ResourceSaver.save(compact_set, output_tileset_path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_error != OK:
		return {"success": false, "error": "Could not save compact TileSet: %s" % error_string(save_error)}
	compact_set.take_over_path(output_tileset_path)
	for layer in layers:
		for cell in layer.get_used_cells():
			var mapped: Dictionary = mappings[layer.get_cell_source_id(cell)][layer.get_cell_atlas_coords(cell)]
			layer.set_cell(cell, mapped.source, mapped.coords, layer.get_cell_alternative_tile(cell))
		layer.tile_set = compact_set
	return {"success": true, "tileset": compact_set, "texture_paths": paths,
		"version": VERSION, "base_rgba_bytes": base_bytes}

func _copy_data(before: TileData, after: TileData) -> void:
	for property in before.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
			after.set(property.name, before.get(property.name))
	for key in before.get_meta_list():
		after.set_meta(key, before.get_meta(key))

func _collect(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		layers.append(node)
	for child in node.get_children():
		_collect(child, layers)
