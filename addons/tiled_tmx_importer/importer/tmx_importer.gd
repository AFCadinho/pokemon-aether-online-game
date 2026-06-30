@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const TmxXmlParser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd")
const TmxTilesetBuilder := preload("res://addons/tiled_tmx_importer/importer/tmx_tileset_builder.gd")
const TmxSceneBuilder := preload("res://addons/tiled_tmx_importer/importer/tmx_scene_builder.gd")


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
			"error": "Infinite/chunked TMX maps are not supported in this proof of concept.",
		}

	var tileset_path := PathUtils.scene_to_tileset_path(normalized_output)
	var tileset_builder := TmxTilesetBuilder.new()
	var tileset_result: Dictionary = tileset_builder.build_tileset(map_data, tileset_path)
	if not bool(tileset_result.get("success", false)):
		return tileset_result

	var scene_builder := TmxSceneBuilder.new()
	var root := scene_builder.build_scene(map_data, tileset_result["tileset"], tileset_builder)
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		root.free()
		return {
			"success": false,
			"error": "Could not pack imported scene: %s" % error_string(pack_error),
		}

	var dir_error := PathUtils.ensure_resource_directory(normalized_output)
	if dir_error != OK:
		root.free()
		return {
			"success": false,
			"error": "Could not create scene output directory: %s" % error_string(dir_error),
		}

	var save_error := ResourceSaver.save(scene, normalized_output)
	root.free()
	if save_error != OK:
		return {
			"success": false,
			"error": "Could not save scene %s: %s" % [normalized_output, error_string(save_error)],
		}

	return {
		"success": true,
		"scene_path": normalized_output,
		"tileset_path": tileset_path,
		"tileset_reused": bool(tileset_result.get("reused", false)),
		"tile_layer_count": map_data.get("layers", []).size(),
		"object_group_count": map_data.get("object_groups", []).size(),
	}
