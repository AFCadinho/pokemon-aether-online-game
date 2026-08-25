@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const TmxXmlParser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd")
const TmxTilesetBuilder := preload("res://addons/tiled_tmx_importer/importer/tmx_tileset_builder.gd")
const TmxVisualSceneBuilder := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_scene_builder.gd")

const MAX_GENERATED_TEXTURE_SIZE := 8192


func import_tmx(tmx_path: String, output_scene_path: String) -> Dictionary:
	var normalized_output := PathUtils.normalize_path(output_scene_path)
	if not (normalized_output.begins_with("res://") or normalized_output.begins_with("user://")):
		return {
			"success": false,
			"error": "Output scene path must be res:// or user://, got %s." % output_scene_path,
		}

	var parser := TmxXmlParser.new()
	var parse_result: Dictionary = parser.parse_tmx(tmx_path)
	if not bool(parse_result.get("success", false)):
		return parse_result

	var map_data: Dictionary = parse_result["map"]
	if bool(map_data.get("infinite", false)):
		return {
			"success": false,
			"error": "Infinite/chunked TMX maps are not supported for visual imports.",
		}

	var materialize_result := _materialize_tileset_images(map_data, normalized_output)
	if not bool(materialize_result.get("success", false)):
		return materialize_result

	var tileset_path := PathUtils.scene_to_tileset_path(normalized_output)
	var tileset_builder := TmxTilesetBuilder.new()
	var tileset_result: Dictionary = tileset_builder.build_tileset(map_data, tileset_path)
	if not bool(tileset_result.get("success", false)):
		return tileset_result

	var scene_builder := TmxVisualSceneBuilder.new()
	var root := scene_builder.build_scene(map_data, tileset_result["tileset"], tileset_builder)
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		root.free()
		return {
			"success": false,
			"error": "Could not pack visual scene: %s" % error_string(pack_error),
		}

	var dir_error := PathUtils.ensure_resource_directory(normalized_output)
	if dir_error != OK:
		root.free()
		return {
			"success": false,
			"error": "Could not create visual scene output directory: %s" % error_string(dir_error),
		}

	var save_error := ResourceSaver.save(scene, normalized_output)
	root.free()
	if save_error != OK:
		return {
			"success": false,
			"error": "Could not save visual scene %s: %s" % [normalized_output, error_string(save_error)],
		}

	return {
		"success": true,
		"scene_path": normalized_output,
		"tileset_path": tileset_path,
		"tileset_reused": bool(tileset_result.get("reused", false)),
		"tile_layer_count": map_data.get("layers", []).size(),
		"ignored_object_group_count": map_data.get("object_groups", []).size(),
	}


func _materialize_tileset_images(map_data: Dictionary, output_scene_path: String) -> Dictionary:
	var output_dir := output_scene_path.get_base_dir()
	var assets_dir := output_dir.path_join("assets")
	var materialized_tilesets: Array = []

	for tileset: Dictionary in map_data.get("tilesets", []):
		var image: Dictionary = tileset.get("image", {})
		var image_path := PathUtils.normalize_path(str(image.get("path", "")))
		if image_path == "" or image_path.begins_with("res://") or image_path.begins_with("user://"):
			materialized_tilesets.append(tileset)
			continue

		var source_path := PathUtils.globalize(image_path)
		if not FileAccess.file_exists(source_path):
			return {
				"success": false,
				"error": "Could not find tileset image %s." % image_path,
			}

		var source_image := Image.new()
		var image_error := source_image.load(source_path)
		if image_error != OK:
			return {
				"success": false,
				"error": "Could not load tileset image %s: %s" % [
					image_path,
					error_string(image_error),
				],
			}

		var chunk_result := _materialize_tileset_image_chunks(tileset, image, image_path, source_image, assets_dir)
		if not bool(chunk_result.get("success", false)):
			return chunk_result

		for chunk_tileset: Dictionary in chunk_result.get("tilesets", []):
			materialized_tilesets.append(chunk_tileset)

	map_data["tilesets"] = materialized_tilesets
	return {"success": true}


func _materialize_tileset_image_chunks(
	tileset: Dictionary,
	image: Dictionary,
	image_path: String,
	source_image: Image,
	assets_dir: String
) -> Dictionary:
	var tile_width := int(tileset.get("tile_width", 0))
	var tile_height := int(tileset.get("tile_height", 0))
	var spacing := int(tileset.get("spacing", 0))
	var margin := int(tileset.get("margin", 0))
	if tile_width <= 0 or tile_height <= 0:
		return {
			"success": false,
			"error": "Tileset '%s' has invalid tile size %dx%d." % [
				str(tileset.get("name", "")),
				tile_width,
				tile_height,
			],
		}

	if spacing != 0 or margin != 0:
		return {
			"success": false,
			"error": "Visual import cannot split external tileset '%s' because spacing/margin is not zero." % str(tileset.get("name", "")),
		}

	var image_width := source_image.get_width()
	var image_height := source_image.get_height()
	if image_width > MAX_GENERATED_TEXTURE_SIZE:
		return {
			"success": false,
			"error": "Tileset image %s is too wide for generated visual textures: %dpx." % [image_path, image_width],
		}

	var columns := int(tileset.get("columns", 0))
	if columns <= 0:
		columns = maxi(1, image_width / tile_width)

	var image_tile_count := columns * int(floor(float(image_height) / float(tile_height)))
	var tile_count := int(tileset.get("tile_count", 0))
	# Some Tiled tilesets keep a stale tilecount after the source image grows.
	# Use the image dimensions as a lower bound so valid cells in the newly
	# appended rows are not silently dropped during import.
	if tile_count <= 0:
		tile_count = image_tile_count
	else:
		tile_count = maxi(tile_count, image_tile_count)

	var max_rows_per_chunk := maxi(1, MAX_GENERATED_TEXTURE_SIZE / tile_height)
	var total_rows := int(ceil(float(tile_count) / float(columns)))
	var chunk_tilesets: Array[Dictionary] = []
	var start_row := 0
	var chunk_index := 0

	while start_row < total_rows:
		var chunk_rows := mini(max_rows_per_chunk, total_rows - start_row)
		var start_local_id := start_row * columns
		var chunk_tile_count := mini(tile_count - start_local_id, chunk_rows * columns)
		var chunk_height := chunk_rows * tile_height
		var source_y := start_row * tile_height
		if source_y + chunk_height > image_height:
			chunk_height = image_height - source_y
		if chunk_height <= 0 or chunk_tile_count <= 0:
			break

		var chunk_image := Image.create_empty(image_width, chunk_height, false, source_image.get_format())
		chunk_image.blit_rect(
			source_image,
			Rect2i(0, source_y, image_width, chunk_height),
			Vector2i.ZERO
		)

		var texture_path := _unique_materialized_texture_path(assets_dir, image_path, chunk_index)
		var dir_error := PathUtils.ensure_resource_directory(texture_path)
		if dir_error != OK:
			return {
				"success": false,
				"error": "Could not create visual tileset asset directory: %s" % error_string(dir_error),
			}

		var texture := ImageTexture.create_from_image(chunk_image)
		var save_error := ResourceSaver.save(texture, texture_path)
		if save_error != OK:
			return {
				"success": false,
				"error": "Could not save generated tileset texture %s: %s" % [
					texture_path,
					error_string(save_error),
				],
			}

		var chunk_image_data := image.duplicate(true)
		chunk_image_data["path"] = texture_path
		chunk_image_data["width"] = image_width
		chunk_image_data["height"] = chunk_height

		var chunk_tileset := tileset.duplicate(true)
		chunk_tileset["firstgid"] = int(tileset.get("firstgid", 1)) + start_local_id
		chunk_tileset["name"] = "%s_%d" % [str(tileset.get("name", "tileset")), chunk_index]
		chunk_tileset["tile_count"] = chunk_tile_count
		chunk_tileset["columns"] = columns
		chunk_tileset["image"] = chunk_image_data
		chunk_tilesets.append(chunk_tileset)

		start_row += chunk_rows
		chunk_index += 1

	return {
		"success": true,
		"tilesets": chunk_tilesets,
	}


func _unique_materialized_texture_path(assets_dir: String, source_path: String, chunk_index: int) -> String:
	var file_name := source_path.get_file()
	if file_name == "":
		file_name = "tileset_image"

	var source_hash := str(hash(source_path))
	var base_name := file_name.get_basename()
	return assets_dir.path_join("%s_%s_%03d.texture.res" % [base_name, source_hash, chunk_index])
