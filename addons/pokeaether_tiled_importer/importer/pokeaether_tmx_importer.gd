@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const TmxXmlParser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd")
const TmxTilesetBuilder := preload("res://addons/tiled_tmx_importer/importer/tmx_tileset_builder.gd")
const Schema := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_schema.gd")
const Validator := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_validator.gd")
const MapDataBuilder := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_map_data_builder.gd")
const RuntimeSceneBuilder := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_runtime_scene_builder.gd")


func import_tmx(tmx_path: String) -> Dictionary:
	var parser := TmxXmlParser.new()
	var parse_result: Dictionary = parser.parse_tmx(tmx_path)
	if not bool(parse_result.get("success", false)):
		return parse_result

	var map_data: Dictionary = parse_result["map"]
	if bool(map_data.get("infinite", false)):
		return {
			"success": false,
			"error": "Infinite/chunked TMX maps are not supported for PokeAether imports.",
		}

	var validator := Validator.new()
	var validation_result: Dictionary = validator.validate(map_data)
	if not bool(validation_result.get("success", false)):
		return validation_result

	var map_properties: Dictionary = map_data.get("properties", {})
	var map_id := str(map_properties.get(Schema.MAP_PROPERTY_MAP_ID, "")).strip_edges()
	var generated_dir := Schema.get_generated_dir(map_id)
	if not generated_dir.begins_with(Schema.GENERATED_MAP_ROOT + "/"):
		return {
			"success": false,
			"error": "Generated map directory escaped %s: %s" % [Schema.GENERATED_MAP_ROOT, generated_dir],
		}

	var dir_error := PathUtils.ensure_resource_directory(generated_dir.path_join("placeholder.txt"))
	if dir_error != OK:
		return {
			"success": false,
			"error": "Could not create generated map directory %s: %s" % [generated_dir, error_string(dir_error)],
		}

	var tileset_path := generated_dir.path_join("%s.tileset.tres" % map_id)
	var tileset_builder := TmxTilesetBuilder.new()
	var tileset_result: Dictionary = tileset_builder.build_tileset(map_data, tileset_path)
	if not bool(tileset_result.get("success", false)):
		return tileset_result

	var map_data_builder := MapDataBuilder.new()
	var imported_map_data: Resource = map_data_builder.build_map_data(map_data)
	var map_data_path := generated_dir.path_join("%s.map_data.tres" % map_id)
	var map_data_save_error := ResourceSaver.save(imported_map_data, map_data_path)
	if map_data_save_error != OK:
		return {
			"success": false,
			"error": "Could not save map data %s: %s" % [map_data_path, error_string(map_data_save_error)],
		}

	var saved_map_data := ResourceLoader.load(map_data_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if saved_map_data == null:
		saved_map_data = imported_map_data

	var runtime_scene_path := generated_dir.path_join("%s.runtime.tscn" % map_id)
	var runtime_scene_builder := RuntimeSceneBuilder.new()
	var root := runtime_scene_builder.build_scene(
		map_data,
		tileset_result["tileset"],
		tileset_builder,
		saved_map_data
	)

	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		root.free()
		return {
			"success": false,
			"error": "Could not pack runtime scene: %s" % error_string(pack_error),
		}

	var scene_save_error := ResourceSaver.save(scene, runtime_scene_path)
	root.free()
	if scene_save_error != OK:
		return {
			"success": false,
			"error": "Could not save runtime scene %s: %s" % [runtime_scene_path, error_string(scene_save_error)],
		}

	return {
		"success": true,
		"map_id": map_id,
		"generated_dir": generated_dir,
		"runtime_scene_path": runtime_scene_path,
		"map_data_path": map_data_path,
		"tileset_path": tileset_path,
		"tileset_reused": bool(tileset_result.get("reused", false)),
		"warnings": validation_result.get("warnings", []),
		"spawn_count": (saved_map_data.get("spawns") as Array).size(),
		"warp_count": (saved_map_data.get("warps") as Array).size(),
		"npc_count": (saved_map_data.get("npcs") as Array).size(),
		"interactable_count": (saved_map_data.get("interactables") as Array).size(),
		"item_count": (saved_map_data.get("items") as Array).size(),
		"encounter_region_count": (saved_map_data.get("encounter_regions") as Array).size(),
		"trigger_count": (saved_map_data.get("triggers") as Array).size(),
	}
