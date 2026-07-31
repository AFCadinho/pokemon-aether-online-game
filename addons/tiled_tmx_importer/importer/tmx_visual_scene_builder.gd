@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")

const OVERLAY_Z_INDEX := 2048
const RAIN_SURFACE_PROPERTY := "pao_rain_surface"


func build_scene(map_data: Dictionary, tile_set: TileSet, tileset_builder: RefCounted) -> Node2D:
	var root := Node2D.new()
	root.name = PathUtils.sanitize_node_name(
		str(map_data.get("source_path", "TiledVisualMap")).get_file().get_basename().to_pascal_case(),
		"TiledVisualMap"
	)
	root.set_meta("pao_generated_visual", true)
	root.set_meta("tiled_source_path", str(map_data.get("source_path", "")))
	root.set_meta("tiled_visual_map", _build_map_metadata(map_data))

	_add_tile_layers(root, map_data, tile_set, tileset_builder)
	return root


func _add_tile_layers(root: Node2D, map_data: Dictionary, tile_set: TileSet, tileset_builder: RefCounted) -> void:
	var layer_index := 0
	var used_layer_names := {}
	for layer: Dictionary in map_data.get("layers", []):
		var layer_node := _create_tile_layer(layer, map_data, tile_set, layer_index, used_layer_names)
		root.add_child(layer_node)
		layer_node.owner = root
		_set_tile_layer_cells(layer_node, layer, map_data, tileset_builder)
		layer_index += 1


func _create_tile_layer(
	layer: Dictionary,
	map_data: Dictionary,
	tile_set: TileSet,
	layer_index: int,
	used_layer_names: Dictionary
) -> TileMapLayer:
	var layer_node := TileMapLayer.new()
	var layer_name := PathUtils.sanitize_node_name(str(layer.get("name", "")), "Layer%d" % layer_index)
	layer_node.name = _make_unique_node_name(layer_name, int(layer.get("id", layer_index)), used_layer_names)
	layer_node.tile_set = tile_set
	layer_node.visible = bool(layer.get("visible", true))
	layer_node.modulate.a = float(layer.get("opacity", 1.0))
	layer_node.position = Vector2(float(layer.get("offset_x", 0.0)), float(layer.get("offset_y", 0.0)))
	layer_node.z_index = _resolve_layer_z_index(layer, layer_index)
	layer_node.set_meta("tiled_name", str(layer.get("name", "")))
	layer_node.set_meta("tiled_layer_id", int(layer.get("id", 0)))
	layer_node.set_meta("tiled_visual_layer", true)
	var properties: Dictionary = layer.get("properties", {})
	if properties.has(RAIN_SURFACE_PROPERTY):
		layer_node.set_meta(RAIN_SURFACE_PROPERTY, str(properties[RAIN_SURFACE_PROPERTY]))
	return layer_node


func _resolve_layer_z_index(layer: Dictionary, layer_index: int) -> int:
	var properties: Dictionary = layer.get("properties", {})
	for property_name in ["pao_z_index", "godot_z_index", "z_index"]:
		if properties.has(property_name):
			return int(properties[property_name])

	var render_layer := str(properties.get("pao_render_layer", properties.get("render_layer", ""))).strip_edges().to_lower()
	if render_layer in ["overlay", "top", "foreground", "above_player"]:
		return OVERLAY_Z_INDEX + layer_index

	return layer_index


func _set_tile_layer_cells(layer_node: TileMapLayer, layer: Dictionary, map_data: Dictionary, tileset_builder: RefCounted) -> void:
	var width := int(layer.get("width", map_data.get("width", 0)))
	if width <= 0:
		return

	var raw_gids: Array = layer.get("raw_gids", [])
	for index in range(raw_gids.size()):
		var raw_gid := int(raw_gids[index])
		if raw_gid == 0:
			continue

		var cell: Dictionary = tileset_builder.get_cell_for_raw_gid(raw_gid)
		if cell.is_empty():
			continue

		var coords := Vector2i(index % width, index / width)
		layer_node.set_cell(
			coords,
			int(cell.get("source_id", -1)),
			cell.get("atlas_coords", Vector2i.ZERO),
			int(cell.get("alternative_tile", 0))
		)


func _build_map_metadata(map_data: Dictionary) -> Dictionary:
	return {
		"version": str(map_data.get("version", "")),
		"tiled_version": str(map_data.get("tiled_version", "")),
		"orientation": str(map_data.get("orientation", "")),
		"render_order": str(map_data.get("render_order", "")),
		"width": int(map_data.get("width", 0)),
		"height": int(map_data.get("height", 0)),
		"tile_width": int(map_data.get("tile_width", 0)),
		"tile_height": int(map_data.get("tile_height", 0)),
	}


func _make_unique_node_name(base_name: String, source_id: int, used_names: Dictionary) -> String:
	var candidate := base_name
	if not used_names.has(candidate):
		used_names[candidate] = true
		return candidate

	candidate = "%s_%d" % [base_name, source_id]
	var suffix := 2
	while used_names.has(candidate):
		candidate = "%s_%d_%d" % [base_name, source_id, suffix]
		suffix += 1

	used_names[candidate] = true
	return candidate
