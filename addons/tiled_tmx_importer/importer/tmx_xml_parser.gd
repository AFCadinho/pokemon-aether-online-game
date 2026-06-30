@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")

const FLIP_H := 0x80000000
const FLIP_V := 0x40000000
const FLIP_D := 0x20000000
const ROTATED_HEX_120 := 0x10000000
const GID_CLEAR_MASK := ~(FLIP_H | FLIP_V | FLIP_D | ROTATED_HEX_120)


func parse_tmx(tmx_path: String) -> Dictionary:
	var normalized_path := PathUtils.normalize_path(tmx_path)
	var parser := XMLParser.new()
	var open_error := parser.open(PathUtils.globalize(normalized_path))
	if open_error != OK:
		return {
			"success": false,
			"error": "Could not open TMX file %s: %s" % [normalized_path, error_string(open_error)],
		}

	var map_data := {
		"source_path": normalized_path,
		"properties": {},
		"tilesets": [],
		"layers": [],
		"object_groups": [],
		"used_gids": {},
	}
	var current_layer: Dictionary = {}
	var current_object_group: Dictionary = {}
	var current_object: Dictionary = {}
	var current_tileset: Dictionary = {}
	var properties_target: Dictionary = {}
	var property_pending_target: Dictionary = {}
	var pending_property_name := ""
	var pending_property_type := "string"
	var pending_property_text := ""
	var in_properties := false
	var in_data := false
	var data_text := ""

	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			var attrs := _read_attributes(parser)
			match node_name:
				"map":
					_apply_map_attributes(map_data, attrs)
				"tileset":
					current_tileset = _parse_tileset_reference(attrs, normalized_path)
					if parser.is_empty():
						_finish_tileset(map_data, current_tileset)
						current_tileset = {}
				"image":
					if not current_tileset.is_empty():
						current_tileset["image"] = _parse_image(attrs, str(current_tileset.get("source_path", normalized_path)))
				"layer":
					current_layer = _parse_layer(attrs)
					if parser.is_empty():
						map_data["layers"].append(current_layer)
						current_layer = {}
				"data":
					if not current_layer.is_empty():
						in_data = true
						data_text = ""
						current_layer["data_encoding"] = str(attrs.get("encoding", "xml"))
						current_layer["data_compression"] = str(attrs.get("compression", ""))
				"tile":
					if in_data and not current_layer.is_empty():
						current_layer["raw_gids"].append(int(attrs.get("gid", 0)))
					elif not current_tileset.is_empty() and attrs.has("id"):
						current_tileset["tile_properties"][int(attrs.get("id", 0))] = {}
				"objectgroup":
					current_object_group = _parse_object_group(attrs)
					if parser.is_empty():
						map_data["object_groups"].append(current_object_group)
						current_object_group = {}
				"object":
					current_object = _parse_object(attrs)
					if parser.is_empty():
						current_object_group["objects"].append(current_object)
						current_object = {}
				"ellipse":
					if not current_object.is_empty():
						current_object["shape"] = "ellipse"
				"point":
					if not current_object.is_empty():
						current_object["shape"] = "point"
				"polygon":
					if not current_object.is_empty():
						current_object["shape"] = "polygon"
						current_object["points"] = str(attrs.get("points", ""))
				"polyline":
					if not current_object.is_empty():
						current_object["shape"] = "polyline"
						current_object["points"] = str(attrs.get("points", ""))
				"properties":
					in_properties = true
					properties_target = _resolve_properties_target(map_data, current_tileset, current_layer, current_object_group, current_object)
				"property":
					if in_properties:
						var property_name := str(attrs.get("name", ""))
						var property_type := str(attrs.get("type", "string"))
						if attrs.has("value") or parser.is_empty():
							properties_target[property_name] = _parse_property_value(str(attrs.get("value", "")), property_type)
						else:
							property_pending_target = properties_target
							pending_property_name = property_name
							pending_property_type = property_type
							pending_property_text = ""
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if in_data:
				data_text += parser.get_node_data()
			elif pending_property_name != "":
				pending_property_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name := parser.get_node_name()
			match end_name:
				"tileset":
					_finish_tileset(map_data, current_tileset)
					current_tileset = {}
				"data":
					if not current_layer.is_empty():
						_apply_layer_data(current_layer, data_text)
						_register_used_gids(map_data, current_layer)
					in_data = false
					data_text = ""
				"layer":
					map_data["layers"].append(current_layer)
					current_layer = {}
				"object":
					current_object_group["objects"].append(current_object)
					current_object = {}
				"objectgroup":
					map_data["object_groups"].append(current_object_group)
					current_object_group = {}
				"properties":
					in_properties = false
					properties_target = {}
				"property":
					if pending_property_name != "":
						property_pending_target[pending_property_name] = _parse_property_value(pending_property_text, pending_property_type)
						property_pending_target = {}
						pending_property_name = ""
						pending_property_type = "string"
						pending_property_text = ""

	if str(map_data.get("orientation", "")) != "orthogonal":
		return {
			"success": false,
			"error": "Only orthogonal TMX maps are supported in this proof of concept.",
		}

	return {
		"success": true,
		"map": map_data,
	}


func _read_attributes(parser: XMLParser) -> Dictionary:
	var attrs := {}
	for index in range(parser.get_attribute_count()):
		attrs[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attrs


func _apply_map_attributes(map_data: Dictionary, attrs: Dictionary) -> void:
	map_data["version"] = str(attrs.get("version", ""))
	map_data["tiled_version"] = str(attrs.get("tiledversion", ""))
	map_data["orientation"] = str(attrs.get("orientation", ""))
	map_data["render_order"] = str(attrs.get("renderorder", "right-down"))
	map_data["width"] = int(attrs.get("width", 0))
	map_data["height"] = int(attrs.get("height", 0))
	map_data["tile_width"] = int(attrs.get("tilewidth", 0))
	map_data["tile_height"] = int(attrs.get("tileheight", 0))
	map_data["infinite"] = int(attrs.get("infinite", 0)) == 1


func _parse_tileset_reference(attrs: Dictionary, tmx_path: String) -> Dictionary:
	var tileset := {
		"firstgid": int(attrs.get("firstgid", 1)),
		"source": str(attrs.get("source", "")),
		"source_path": tmx_path,
		"name": str(attrs.get("name", "")),
		"tile_width": int(attrs.get("tilewidth", 0)),
		"tile_height": int(attrs.get("tileheight", 0)),
		"spacing": int(attrs.get("spacing", 0)),
		"margin": int(attrs.get("margin", 0)),
		"tile_count": int(attrs.get("tilecount", 0)),
		"columns": int(attrs.get("columns", 0)),
		"image": {},
		"properties": {},
		"tile_properties": {},
	}
	var source := str(tileset["source"])
	if source != "":
		var tsx_path := PathUtils.resolve_relative(tmx_path, source)
		var external_tileset := parse_tsx(tsx_path)
		if bool(external_tileset.get("success", false)):
			var external_data: Dictionary = external_tileset["tileset"]
			external_data["firstgid"] = tileset["firstgid"]
			external_data["source"] = source
			external_data["source_path"] = tsx_path
			return external_data
		tileset["external_error"] = str(external_tileset.get("error", "Unknown TSX parse error"))
	return tileset


func parse_tsx(tsx_path: String) -> Dictionary:
	var normalized_path := PathUtils.normalize_path(tsx_path)
	var parser := XMLParser.new()
	var open_error := parser.open(PathUtils.globalize(normalized_path))
	if open_error != OK:
		return {
			"success": false,
			"error": "Could not open TSX file %s: %s" % [normalized_path, error_string(open_error)],
		}

	var tileset := {
		"firstgid": 1,
		"source": "",
		"source_path": normalized_path,
		"name": "",
		"tile_width": 0,
		"tile_height": 0,
		"spacing": 0,
		"margin": 0,
		"tile_count": 0,
		"columns": 0,
		"image": {},
		"properties": {},
		"tile_properties": {},
	}
	var in_properties := false
	var properties_target: Dictionary = {}
	var current_tile_id := -1

	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			var attrs := _read_attributes(parser)
			match node_name:
				"tileset":
					tileset["name"] = str(attrs.get("name", ""))
					tileset["tile_width"] = int(attrs.get("tilewidth", 0))
					tileset["tile_height"] = int(attrs.get("tileheight", 0))
					tileset["spacing"] = int(attrs.get("spacing", 0))
					tileset["margin"] = int(attrs.get("margin", 0))
					tileset["tile_count"] = int(attrs.get("tilecount", 0))
					tileset["columns"] = int(attrs.get("columns", 0))
				"image":
					tileset["image"] = _parse_image(attrs, normalized_path)
				"tile":
					current_tile_id = int(attrs.get("id", -1))
					if current_tile_id >= 0 and not tileset["tile_properties"].has(current_tile_id):
						tileset["tile_properties"][current_tile_id] = {}
				"properties":
					in_properties = true
					properties_target = tileset["properties"]
					if current_tile_id >= 0:
						properties_target = tileset["tile_properties"][current_tile_id]
				"property":
					if in_properties:
						var property_name := str(attrs.get("name", ""))
						properties_target[property_name] = _parse_property_value(
							str(attrs.get("value", "")),
							str(attrs.get("type", "string"))
						)
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name := parser.get_node_name()
			match end_name:
				"tile":
					current_tile_id = -1
				"properties":
					in_properties = false
					properties_target = {}

	return {
		"success": true,
		"tileset": tileset,
	}


func _parse_image(attrs: Dictionary, base_file_path: String) -> Dictionary:
	var source := str(attrs.get("source", ""))
	return {
		"source": source,
		"path": PathUtils.resolve_relative(base_file_path, source),
		"width": int(attrs.get("width", 0)),
		"height": int(attrs.get("height", 0)),
		"transparent_color": str(attrs.get("trans", "")),
	}


func _finish_tileset(map_data: Dictionary, tileset: Dictionary) -> void:
	if tileset.is_empty():
		return
	if str(tileset.get("external_error", "")) != "":
		push_warning(str(tileset["external_error"]))
	map_data["tilesets"].append(tileset)


func _parse_layer(attrs: Dictionary) -> Dictionary:
	return {
		"id": int(attrs.get("id", 0)),
		"name": str(attrs.get("name", "")),
		"width": int(attrs.get("width", 0)),
		"height": int(attrs.get("height", 0)),
		"visible": int(attrs.get("visible", 1)) != 0,
		"opacity": float(attrs.get("opacity", 1.0)),
		"offset_x": float(attrs.get("offsetx", 0.0)),
		"offset_y": float(attrs.get("offsety", 0.0)),
		"properties": {},
		"raw_gids": [],
		"data_encoding": "xml",
		"data_compression": "",
	}


func _apply_layer_data(layer: Dictionary, data_text: String) -> void:
	var encoding := str(layer.get("data_encoding", "xml"))
	if encoding == "csv":
		if str(layer.get("data_compression", "")) != "":
			push_warning("Skipping compressed CSV Tiled layer data on '%s'." % str(layer.get("name", "")))
			return
		var gids: Array[int] = []
		for value in data_text.replace("\n", "").replace("\r", "").split(",", false):
			gids.append(int(str(value).strip_edges()))
		layer["raw_gids"] = gids
	elif encoding == "base64":
		_decode_base64_layer_data(layer, data_text)


func _decode_base64_layer_data(layer: Dictionary, data_text: String) -> void:
	var bytes := Marshalls.base64_to_raw(data_text.strip_edges())
	var compression := str(layer.get("data_compression", ""))
	if compression != "":
		var compression_mode := -1
		match compression:
			"zlib":
				compression_mode = FileAccess.COMPRESSION_DEFLATE
			"gzip":
				compression_mode = FileAccess.COMPRESSION_GZIP
			_:
				push_warning("Skipping unsupported compressed Tiled layer data '%s' on '%s'." % [
					compression,
					str(layer.get("name", "")),
				])
				return

		bytes = bytes.decompress_dynamic(-1, compression_mode)
		if bytes.is_empty():
			push_warning("Could not decompress Tiled layer data on '%s'." % str(layer.get("name", "")))
			return

	var gids: Array[int] = []
	var index := 0
	while index + 3 < bytes.size():
		var gid := int(bytes[index]) \
			| (int(bytes[index + 1]) << 8) \
			| (int(bytes[index + 2]) << 16) \
			| (int(bytes[index + 3]) << 24)
		gids.append(gid)
		index += 4
	layer["raw_gids"] = gids


func _register_used_gids(map_data: Dictionary, layer: Dictionary) -> void:
	var used_gids: Dictionary = map_data["used_gids"]
	for raw_gid: int in layer.get("raw_gids", []):
		var gid := raw_gid & GID_CLEAR_MASK
		if gid > 0:
			used_gids[gid] = true


func _parse_object_group(attrs: Dictionary) -> Dictionary:
	return {
		"id": int(attrs.get("id", 0)),
		"name": str(attrs.get("name", "")),
		"visible": int(attrs.get("visible", 1)) != 0,
		"opacity": float(attrs.get("opacity", 1.0)),
		"offset_x": float(attrs.get("offsetx", 0.0)),
		"offset_y": float(attrs.get("offsety", 0.0)),
		"properties": {},
		"objects": [],
	}


func _parse_object(attrs: Dictionary) -> Dictionary:
	return {
		"id": int(attrs.get("id", 0)),
		"name": str(attrs.get("name", "")),
		"type": str(attrs.get("type", "")),
		"x": float(attrs.get("x", 0.0)),
		"y": float(attrs.get("y", 0.0)),
		"width": float(attrs.get("width", 0.0)),
		"height": float(attrs.get("height", 0.0)),
		"rotation": float(attrs.get("rotation", 0.0)),
		"gid": int(attrs.get("gid", 0)),
		"visible": int(attrs.get("visible", 1)) != 0,
		"shape": "rectangle",
		"points": "",
		"properties": {},
	}


func _resolve_properties_target(
	map_data: Dictionary,
	current_tileset: Dictionary,
	current_layer: Dictionary,
	current_object_group: Dictionary,
	current_object: Dictionary
) -> Dictionary:
	if not current_object.is_empty():
		return current_object["properties"]
	if not current_object_group.is_empty():
		return current_object_group["properties"]
	if not current_layer.is_empty():
		return current_layer["properties"]
	if not current_tileset.is_empty():
		return current_tileset["properties"]
	return map_data["properties"]


func _parse_property_value(value: String, property_type: String) -> Variant:
	match property_type:
		"bool":
			var normalized := value.strip_edges().to_lower()
			return normalized == "true" or normalized == "1"
		"int", "object":
			return int(value)
		"float":
			return float(value)
		_:
			return value
