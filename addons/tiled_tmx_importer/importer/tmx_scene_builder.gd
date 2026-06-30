@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")


func build_scene(map_data: Dictionary, tile_set: TileSet, tileset_builder: RefCounted) -> Node2D:
	var root := Node2D.new()
	root.name = PathUtils.sanitize_node_name(
		str(map_data.get("properties", {}).get("name", "")),
		str(map_data.get("source_path", "TiledMap")).get_file().get_basename().to_pascal_case()
	)
	root.set_meta("tiled_source_path", str(map_data.get("source_path", "")))
	root.set_meta("tiled_properties", map_data.get("properties", {}).duplicate(true))
	root.set_meta("tiled_map", _build_map_metadata(map_data))

	_add_tile_layers(root, map_data, tile_set, tileset_builder)
	_add_object_groups(root, map_data)
	return root


func _add_tile_layers(root: Node2D, map_data: Dictionary, tile_set: TileSet, tileset_builder: RefCounted) -> void:
	var layer_index := 0
	var used_layer_names := {}
	for layer: Dictionary in map_data.get("layers", []):
		if not bool(layer.get("visible", true)):
			continue

		var layer_node := TileMapLayer.new()
		var layer_name := PathUtils.sanitize_node_name(str(layer.get("name", "")), "Layer%d" % layer_index)
		layer_node.name = _make_unique_node_name(layer_name, int(layer.get("id", layer_index)), used_layer_names)
		layer_node.tile_set = tile_set
		layer_node.visible = true
		layer_node.modulate.a = float(layer.get("opacity", 1.0))
		layer_node.position = Vector2(float(layer.get("offset_x", 0.0)), float(layer.get("offset_y", 0.0)))
		layer_node.z_index = layer_index
		layer_node.set_meta("tiled_name", str(layer.get("name", "")))
		layer_node.set_meta("tiled_layer_id", int(layer.get("id", 0)))
		layer_node.set_meta("tiled_properties", layer.get("properties", {}).duplicate(true))
		root.add_child(layer_node)
		layer_node.owner = root

		var width := int(layer.get("width", map_data.get("width", 0)))
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

		layer_index += 1


func _add_object_groups(root: Node2D, map_data: Dictionary) -> void:
	var object_groups_root := Node2D.new()
	object_groups_root.name = "ObjectLayers"
	root.add_child(object_groups_root)
	object_groups_root.owner = root

	var used_group_names := {}
	for group: Dictionary in map_data.get("object_groups", []):
		var group_node := Node2D.new()
		var group_name := PathUtils.sanitize_node_name(str(group.get("name", "")), "ObjectGroup%d" % int(group.get("id", 0)))
		group_node.name = _make_unique_node_name(group_name, int(group.get("id", 0)), used_group_names)
		group_node.visible = bool(group.get("visible", true))
		group_node.modulate.a = float(group.get("opacity", 1.0))
		group_node.position = Vector2(float(group.get("offset_x", 0.0)), float(group.get("offset_y", 0.0)))
		group_node.set_meta("tiled_name", str(group.get("name", "")))
		group_node.set_meta("tiled_object_group_id", int(group.get("id", 0)))
		group_node.set_meta("tiled_properties", group.get("properties", {}).duplicate(true))
		object_groups_root.add_child(group_node)
		group_node.owner = root

		var used_object_names := {}
		for object_data: Dictionary in group.get("objects", []):
			var object_node := Node2D.new()
			var object_name := PathUtils.sanitize_node_name(
				str(object_data.get("name", "")),
				"Object%d" % int(object_data.get("id", 0))
			)
			object_node.name = _make_unique_node_name(object_name, int(object_data.get("id", 0)), used_object_names)
			object_node.position = Vector2(float(object_data.get("x", 0.0)), float(object_data.get("y", 0.0)))
			object_node.rotation_degrees = float(object_data.get("rotation", 0.0))
			object_node.visible = bool(object_data.get("visible", true))
			object_node.set_meta("tiled_name", str(object_data.get("name", "")))
			object_node.set_meta("tiled_object", object_data.duplicate(true))
			object_node.set_meta("tiled_properties", object_data.get("properties", {}).duplicate(true))
			group_node.add_child(object_node)
			object_node.owner = root


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
