@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")

var gid_lookup: Dictionary = {}


func build_tileset(map_data: Dictionary, output_tileset_path: String) -> Dictionary:
	gid_lookup.clear()
	var normalized_output := PathUtils.normalize_path(output_tileset_path)
	var signature := _build_signature(map_data)

	var existing: TileSet = null
	if ResourceLoader.exists(normalized_output):
		existing = ResourceLoader.load(normalized_output, "TileSet", ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	if existing != null and str(existing.get_meta("tiled_source_signature", "")) == signature:
		_build_gid_lookup(map_data)
		return {
			"success": true,
			"tileset": existing,
			"tileset_path": normalized_output,
			"reused": true,
		}

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(int(map_data.get("tile_width", 32)), int(map_data.get("tile_height", 32)))
	tile_set.set_meta("tiled_source_signature", signature)
	tile_set.set_meta("tiled_source_path", str(map_data.get("source_path", "")))

	for tileset: Dictionary in map_data.get("tilesets", []):
		var result := _add_tileset_source(tile_set, tileset, map_data)
		if not bool(result.get("success", false)):
			return result

	var dir_error := PathUtils.ensure_resource_directory(normalized_output)
	if dir_error != OK:
		return {
			"success": false,
			"error": "Could not create TileSet output directory: %s" % error_string(dir_error),
		}

	var save_error := ResourceSaver.save(tile_set, normalized_output)
	if save_error != OK:
		return {
			"success": false,
			"error": "Could not save TileSet %s: %s" % [normalized_output, error_string(save_error)],
		}

	var saved_tileset := ResourceLoader.load(normalized_output, "TileSet", ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	if saved_tileset == null:
		saved_tileset = tile_set

	return {
		"success": true,
		"tileset": saved_tileset,
		"tileset_path": normalized_output,
		"reused": false,
	}


func get_cell_for_raw_gid(raw_gid: int) -> Dictionary:
	const FLIP_H := 0x80000000
	const FLIP_V := 0x40000000
	const FLIP_D := 0x20000000
	const ROTATED_HEX_120 := 0x10000000
	const GID_CLEAR_MASK := ~(FLIP_H | FLIP_V | FLIP_D | ROTATED_HEX_120)
	const ALT_FLIP_H := 4096
	const ALT_FLIP_V := 8192
	const ALT_TRANSPOSE := 16384

	var gid := raw_gid & GID_CLEAR_MASK
	if gid <= 0 or not gid_lookup.has(gid):
		return {}

	var cell: Dictionary = gid_lookup[gid].duplicate()
	var alternative_tile := 0
	if (raw_gid & FLIP_H) != 0:
		alternative_tile |= ALT_FLIP_H
	if (raw_gid & FLIP_V) != 0:
		alternative_tile |= ALT_FLIP_V
	if (raw_gid & FLIP_D) != 0:
		alternative_tile |= ALT_TRANSPOSE
	cell["alternative_tile"] = alternative_tile
	return cell


func _add_tileset_source(tile_set: TileSet, tileset: Dictionary, map_data: Dictionary) -> Dictionary:
	var image: Dictionary = tileset.get("image", {})
	var image_path := str(image.get("path", ""))
	if image_path == "":
		return {
			"success": false,
			"error": "Tileset '%s' has no image source." % str(tileset.get("name", "")),
		}

	var texture := _load_texture(image_path)
	if texture == null:
		return {
			"success": false,
			"error": "Could not load tileset image %s." % image_path,
		}

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(
		int(tileset.get("tile_width", map_data.get("tile_width", 32))),
		int(tileset.get("tile_height", map_data.get("tile_height", 32)))
	)
	if int(tileset.get("spacing", 0)) != 0:
		source.separation = Vector2i(int(tileset.get("spacing", 0)), int(tileset.get("spacing", 0)))
	if int(tileset.get("margin", 0)) != 0:
		source.margins = Vector2i(int(tileset.get("margin", 0)), int(tileset.get("margin", 0)))

	var firstgid := int(tileset.get("firstgid", 1))
	var source_id := tile_set.add_source(source, firstgid)
	var columns := _get_columns(tileset, image, source.texture_region_size)
	var tile_count := _get_tile_count(tileset, image, source.texture_region_size, columns)

	for local_id in range(tile_count):
		var atlas_coords := Vector2i(local_id % columns, local_id / columns)
		if not source.has_tile(atlas_coords):
			source.create_tile(atlas_coords)
		gid_lookup[firstgid + local_id] = {
			"source_id": source_id,
			"atlas_coords": atlas_coords,
		}

	return {"success": true}


func _build_gid_lookup(map_data: Dictionary) -> void:
	for tileset: Dictionary in map_data.get("tilesets", []):
		var image: Dictionary = tileset.get("image", {})
		var region_size := Vector2i(
			int(tileset.get("tile_width", map_data.get("tile_width", 32))),
			int(tileset.get("tile_height", map_data.get("tile_height", 32)))
		)
		var firstgid := int(tileset.get("firstgid", 1))
		var columns := _get_columns(tileset, image, region_size)
		var tile_count := _get_tile_count(tileset, image, region_size, columns)
		for local_id in range(tile_count):
			gid_lookup[firstgid + local_id] = {
				"source_id": firstgid,
				"atlas_coords": Vector2i(local_id % columns, local_id / columns),
			}


func _load_texture(path: String) -> Texture2D:
	var localized := PathUtils.localize(path)
	if localized.begins_with("res://"):
		return load(localized) as Texture2D

	var image := Image.new()
	var error := image.load(PathUtils.globalize(localized))
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _get_columns(tileset: Dictionary, image: Dictionary, tile_size: Vector2i) -> int:
	var columns := int(tileset.get("columns", 0))
	if columns > 0:
		return columns

	var image_width := int(image.get("width", 0))
	var margin := int(tileset.get("margin", 0))
	var spacing := int(tileset.get("spacing", 0))
	if image_width <= 0:
		return 1
	return maxi(1, int(floor(float(image_width - (margin * 2) + spacing) / float(tile_size.x + spacing))))


func _get_tile_count(tileset: Dictionary, image: Dictionary, tile_size: Vector2i, columns: int) -> int:
	var tile_count := int(tileset.get("tile_count", 0))
	if tile_count > 0:
		return tile_count

	var image_width := int(image.get("width", 0))
	var image_height := int(image.get("height", 0))
	var margin := int(tileset.get("margin", 0))
	var spacing := int(tileset.get("spacing", 0))
	if image_width <= 0 or image_height <= 0:
		return 0

	var rows := int(floor(float(image_height - (margin * 2) + spacing) / float(tile_size.y + spacing)))
	return maxi(0, columns * rows)


func _build_signature(map_data: Dictionary) -> String:
	var parts: Array[String] = [
		str(map_data.get("tile_width", 0)),
		str(map_data.get("tile_height", 0)),
	]
	for tileset: Dictionary in map_data.get("tilesets", []):
		var image: Dictionary = tileset.get("image", {})
		parts.append("|")
		parts.append(str(tileset.get("firstgid", 0)))
		parts.append(str(tileset.get("source_path", "")))
		parts.append(str(tileset.get("name", "")))
		parts.append(str(tileset.get("tile_width", 0)))
		parts.append(str(tileset.get("tile_height", 0)))
		parts.append(str(tileset.get("spacing", 0)))
		parts.append(str(tileset.get("margin", 0)))
		parts.append(str(tileset.get("tile_count", 0)))
		parts.append(str(tileset.get("columns", 0)))
		parts.append(str(image.get("path", "")))
	return "\n".join(parts)
