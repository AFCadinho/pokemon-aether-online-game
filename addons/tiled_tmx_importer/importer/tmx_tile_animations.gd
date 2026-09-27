@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
# Same padded, lossless layout as the static atlas compactor. Each animation
# owns one logical tile; frames are never independent collision/gameplay tiles.
const LIMIT := 4096
const BORDER := 2
const COLUMNS := 7

func validate(map_data: Dictionary) -> Dictionary:
	var animations := {}
	for tileset: Dictionary in map_data.get("tilesets", []):
		var first := int(tileset.get("firstgid", 1))
		var image: Image
		for local_id in tileset.get("animated_tile_ids", []):
			var gid := first + int(local_id)
			if not map_data.get("used_gids", {}).has(gid):
				continue
			if image == null:
				image = Image.load_from_file(PathUtils.globalize(str(tileset.get("image", {}).get("path", ""))))
			if image == null or image.is_empty():
				return _error("Cannot read animation image.")
			var tw := int(tileset.get("tile_width", 0))
			var th := int(tileset.get("tile_height", 0))
			var spacing := int(tileset.get("spacing", 0))
			var margin := int(tileset.get("margin", 0))
			if tw <= 0 or th <= 0 or tw + BORDER * 2 > LIMIT or th + BORDER * 2 > LIMIT:
				return _error("Invalid animation tile dimensions.")
			var cols := (image.get_width() - margin * 2 + spacing) / (tw + spacing)
			var rows := (image.get_height() - margin * 2 + spacing) / (th + spacing)
			var frames: Array = tileset.get("tile_animations", {}).get(local_id, [])
			var capacity := mini(COLUMNS, LIMIT / (tw + BORDER * 2)) * (LIMIT / (th + BORDER * 2))
			if frames.is_empty() or frames.size() > capacity:
				return _error("Empty animation or frame strip exceeds 4096px.")
			if int(local_id) < 0 or int(local_id) >= cols * rows:
				return _error("Animation tile is outside its image.")
			var resolved: Array = []
			for frame: Dictionary in frames:
				var tile_id := int(frame.get("tile_id", -1))
				if tile_id < 0 or tile_id >= cols * rows or int(frame.get("duration", 0)) <= 0:
					return _error("Invalid animation frame ID or duration for tile %d." % local_id)
				resolved.append({"gid": first + tile_id, "duration": int(frame.duration)})
			animations[gid] = resolved
	return {"success": true, "animations": animations}

func resolve(animations: Dictionary, builder: RefCounted) -> Dictionary:
	var resolved := {}
	for gid in animations:
		var cell: Dictionary = builder.get_cell_for_raw_gid(gid)
		var frames: Array = []
		for frame: Dictionary in animations[gid]:
			var entry: Dictionary = builder.get_cell_for_raw_gid(frame.gid)
			entry["duration"] = frame.duration
			frames.append(entry)
		if not resolved.has(cell.source_id):
			resolved[cell.source_id] = {}
		resolved[cell.source_id][cell.atlas_coords] = frames
	return resolved

func append_compact(original: TileSet, compact_set: TileSet, animations: Dictionary, mappings: Dictionary, output: String, next_id: int) -> Dictionary:
	var paths: Array[String] = []
	var base_bytes := 0
	var decoded := {}
	for old_id in animations:
		var old := original.get_source(old_id) as TileSetAtlasSource
		for before: Vector2i in animations[old_id]:
			var frames: Array = animations[old_id][before]
			var slot := old.texture_region_size + Vector2i.ONE * BORDER * 2
			var columns := mini(COLUMNS, LIMIT / slot.x)
			var width := 1
			while width < mini(columns, frames.size()) * slot.x:
				width *= 2
			width = mini(width, LIMIT)
			var height := ceili(float(frames.size()) / columns) * slot.y
			var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
			for n in frames.size():
				var frame: Dictionary = frames[n]
				var from := original.get_source(frame.source_id) as TileSetAtlasSource
				if not decoded.has(frame.source_id):
					decoded[frame.source_id] = from.texture.get_image()
					decoded[frame.source_id].convert(Image.FORMAT_RGBA8)
				image.blit_rect(decoded[frame.source_id], from.get_tile_texture_region(frame.atlas_coords), Vector2i(n % columns, n / columns) * slot + Vector2i.ONE * BORDER)
			var texture := PortableCompressedTexture2D.new()
			texture.keep_compressed_buffer = true
			texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
			var path := output.get_base_dir().path_join("assets/%s.compact_source_%d_0.texture.res" % [output.get_file().get_basename(), next_id])
			var err := PathUtils.ensure_resource_directory(path)
			if err == OK:
				err = ResourceSaver.save(texture, path, ResourceSaver.FLAG_CHANGE_PATH)
			if err != OK:
				return _error("Could not save animation atlas: " + error_string(err))
			texture.take_over_path(path)
			var source := TileSetAtlasSource.new()
			source.texture = texture
			source.texture_region_size = old.texture_region_size
			source.margins = Vector2i.ONE * BORDER
			source.separation = Vector2i.ONE * BORDER * 2
			source.use_texture_padding = old.use_texture_padding
			source.set_meta("tiled_animation_strip", true)
			compact_set.add_source(source, next_id)
			source.create_tile(Vector2i.ZERO)
			source.set_tile_animation_columns(Vector2i.ZERO, columns)
			source.set_tile_animation_frames_count(Vector2i.ZERO, frames.size())
			source.set_tile_animation_speed(Vector2i.ZERO, 1.0)
			for n in frames.size():
				source.set_tile_animation_frame_duration(Vector2i.ZERO, n, float(frames[n].duration) / 1000.0)
			for a in old.get_alternative_tiles_count(before):
				var alternative := old.get_alternative_tile_id(before, a)
				if alternative != 0:
					source.create_alternative_tile(Vector2i.ZERO, alternative)
				var old_data := old.get_tile_data(before, alternative)
				var new_data := source.get_tile_data(Vector2i.ZERO, alternative)
				for property in old_data.get_property_list():
					if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
						new_data.set(property.name, old_data.get(property.name))
				for key in old_data.get_meta_list():
					new_data.set_meta(key, old_data.get_meta(key))
			mappings[old_id][before] = {"source": next_id, "coords": Vector2i.ZERO}
			paths.append(path)
			base_bytes += width * height * 4
			next_id += 1
	return {"success": true, "texture_paths": paths, "base_rgba_bytes": base_bytes}

func _error(message: String) -> Dictionary:
	return {"success": false, "error": "TMX animation: " + message}
