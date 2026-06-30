@tool
extends RefCounted

const Schema := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_schema.gd")


func validate(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	_validate_map_metadata(map_data, errors)
	_validate_tile_size(map_data, errors)
	_validate_object_layers(map_data, errors)
	_validate_runtime_tile_layers(map_data, warnings)

	return {
		"success": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"error": "\n".join(errors),
	}


func _validate_map_metadata(map_data: Dictionary, errors: Array[String]) -> void:
	var properties: Dictionary = map_data.get("properties", {})
	_require_property(errors, properties, Schema.MAP_PROPERTY_SCHEMA_VERSION, "Map")
	_require_property(errors, properties, Schema.MAP_PROPERTY_MAP_ID, "Map")
	_require_property(errors, properties, Schema.MAP_PROPERTY_MAP_DISPLAY_NAME, "Map")
	_require_property(errors, properties, Schema.MAP_PROPERTY_REGION_ID, "Map")
	_require_property(errors, properties, Schema.MAP_PROPERTY_REGION_NAME, "Map")

	if properties.has(Schema.MAP_PROPERTY_SCHEMA_VERSION):
		var schema_version := int(properties.get(Schema.MAP_PROPERTY_SCHEMA_VERSION, 0))
		if schema_version != Schema.CURRENT_SCHEMA_VERSION:
			errors.append("Map property '%s' must be %d, got %d." % [
				Schema.MAP_PROPERTY_SCHEMA_VERSION,
				Schema.CURRENT_SCHEMA_VERSION,
				schema_version,
			])

	var map_id := _property_text(properties, Schema.MAP_PROPERTY_MAP_ID)
	if map_id != "" and not Schema.is_safe_id(map_id):
		errors.append("Map property '%s' must contain only letters, numbers, '_' or '-': %s" % [
			Schema.MAP_PROPERTY_MAP_ID,
			map_id,
		])


func _validate_tile_size(map_data: Dictionary, errors: Array[String]) -> void:
	var tile_width := int(map_data.get("tile_width", 0))
	var tile_height := int(map_data.get("tile_height", 0))
	if tile_width != Schema.TILE_SIZE or tile_height != Schema.TILE_SIZE:
		errors.append("PokeAether TMX maps must use %dx%d tiles, got %dx%d." % [
			Schema.TILE_SIZE,
			Schema.TILE_SIZE,
			tile_width,
			tile_height,
		])


func _validate_runtime_tile_layers(map_data: Dictionary, warnings: Array[String]) -> void:
	var layer_names := {}
	for layer: Dictionary in map_data.get("layers", []):
		layer_names[str(layer.get("name", ""))] = true

	if not layer_names.has(Schema.TILE_LAYER_COLLISION):
		warnings.append("Tile layer '%s' is missing. The generated layer will be empty, so every tile is passable unless blocked by characters." % Schema.TILE_LAYER_COLLISION)


func _validate_object_layers(map_data: Dictionary, errors: Array[String]) -> void:
	var seen_spawns := {}
	var seen_warps := {}
	var seen_npcs := {}
	var seen_items := {}
	var seen_encounter_regions := {}
	var seen_triggers := {}

	for group: Dictionary in map_data.get("object_groups", []):
		var layer_name := str(group.get("name", ""))
		if layer_name.begins_with("PA_") and not Schema.is_pa_object_layer(layer_name):
			errors.append("Unsupported PokeAether object layer '%s'." % layer_name)
			continue

		for object_data: Dictionary in group.get("objects", []):
			match layer_name:
				Schema.OBJECT_LAYER_SPAWNS:
					_validate_spawn(errors, seen_spawns, layer_name, object_data)
				Schema.OBJECT_LAYER_WARPS:
					_validate_warp(errors, seen_warps, layer_name, object_data)
				Schema.OBJECT_LAYER_NPCS:
					_validate_npc(errors, seen_npcs, layer_name, object_data)
				Schema.OBJECT_LAYER_ITEMS:
					_validate_item(errors, seen_items, layer_name, object_data)
				Schema.OBJECT_LAYER_ENCOUNTER_REGIONS:
					_validate_encounter_region(errors, seen_encounter_regions, layer_name, object_data)
				Schema.OBJECT_LAYER_TRIGGERS:
					_validate_trigger(errors, seen_triggers, layer_name, object_data)


func _validate_spawn(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var spawn_id := _require_property(errors, properties, Schema.PROP_SPAWN_ID, context)
	_check_duplicate_id(errors, seen_ids, spawn_id, Schema.PROP_SPAWN_ID, context)
	_validate_point_object(errors, object_data, context)


func _validate_warp(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var warp_id := _require_property(errors, properties, Schema.PROP_WARP_ID, context)
	_check_duplicate_id(errors, seen_ids, warp_id, Schema.PROP_WARP_ID, context)
	_require_property_alias(errors, properties, Schema.PROP_TARGET_SPAWN_NAME, Schema.PROP_TARGET_SPAWN_ALIAS, context)
	if _property_text(properties, Schema.PROP_TARGET_MAP_ID) == "" and _property_text(properties, Schema.PROP_TARGET_SCENE_PATH) == "":
		errors.append("%s is missing required property '%s' or '%s'." % [
			context,
			Schema.PROP_TARGET_MAP_ID,
			Schema.PROP_TARGET_SCENE_PATH,
		])
	_validate_rectangle_object(errors, object_data, context)


func _validate_npc(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var npc_id := _require_property(errors, properties, Schema.PROP_NPC_ID, context)
	_require_property(errors, properties, Schema.PROP_NPC_KIND, context)
	_check_duplicate_id(errors, seen_ids, npc_id, Schema.PROP_NPC_ID, context)
	_validate_point_object(errors, object_data, context)


func _validate_item(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var item_spawn_id := _require_property(errors, properties, Schema.PROP_ITEM_SPAWN_ID, context)
	_require_property(errors, properties, Schema.PROP_ITEM_ID, context)
	_check_duplicate_id(errors, seen_ids, item_spawn_id, Schema.PROP_ITEM_SPAWN_ID, context)
	_validate_point_object(errors, object_data, context)


func _validate_encounter_region(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var region_id := _require_property(errors, properties, Schema.PROP_ENCOUNTER_REGION_ID, context)
	_require_property(errors, properties, Schema.PROP_ENCOUNTER_AREA_ID, context)
	_require_property(errors, properties, Schema.PROP_ENCOUNTER_TYPE, context)
	_check_duplicate_id(errors, seen_ids, region_id, Schema.PROP_ENCOUNTER_REGION_ID, context)
	_validate_area_object(errors, object_data, context)


func _validate_trigger(errors: Array[String], seen_ids: Dictionary, layer_name: String, object_data: Dictionary) -> void:
	var context := _object_context(layer_name, object_data)
	var properties: Dictionary = object_data.get("properties", {})
	var trigger_id := _require_property(errors, properties, Schema.PROP_TRIGGER_ID, context)
	_require_property(errors, properties, Schema.PROP_TRIGGER_KIND, context)
	_check_duplicate_id(errors, seen_ids, trigger_id, Schema.PROP_TRIGGER_ID, context)
	_validate_area_object(errors, object_data, context)


func _validate_point_object(errors: Array[String], object_data: Dictionary, context: String) -> void:
	var width := float(object_data.get("width", 0.0))
	var height := float(object_data.get("height", 0.0))
	if width != 0.0 or height != 0.0:
		errors.append("%s must be a point object or zero-size object." % context)

	_validate_grid_value(errors, float(object_data.get("x", 0.0)), "%s x" % context)
	_validate_grid_value(errors, float(object_data.get("y", 0.0)), "%s y" % context)


func _validate_rectangle_object(errors: Array[String], object_data: Dictionary, context: String) -> void:
	if str(object_data.get("shape", "rectangle")) != "rectangle":
		errors.append("%s must be a rectangle object." % context)
		return

	_validate_rectangle_grid(errors, object_data, context)


func _validate_area_object(errors: Array[String], object_data: Dictionary, context: String) -> void:
	var shape := str(object_data.get("shape", "rectangle"))
	if shape == "rectangle":
		_validate_rectangle_grid(errors, object_data, context)
		return
	if shape == "polygon":
		_validate_grid_value(errors, float(object_data.get("x", 0.0)), "%s x" % context)
		_validate_grid_value(errors, float(object_data.get("y", 0.0)), "%s y" % context)
		for point: Vector2 in _parse_points(str(object_data.get("points", ""))):
			_validate_grid_value(errors, point.x, "%s polygon point x" % context)
			_validate_grid_value(errors, point.y, "%s polygon point y" % context)
		return

	errors.append("%s must be a rectangle or polygon object." % context)


func _validate_rectangle_grid(errors: Array[String], object_data: Dictionary, context: String) -> void:
	var width := float(object_data.get("width", 0.0))
	var height := float(object_data.get("height", 0.0))
	if width <= 0.0 or height <= 0.0:
		errors.append("%s must have positive width and height." % context)

	_validate_grid_value(errors, float(object_data.get("x", 0.0)), "%s x" % context)
	_validate_grid_value(errors, float(object_data.get("y", 0.0)), "%s y" % context)
	_validate_grid_value(errors, width, "%s width" % context)
	_validate_grid_value(errors, height, "%s height" % context)


func _validate_grid_value(errors: Array[String], value: float, label: String) -> void:
	var remainder := fposmod(value, float(Schema.TILE_SIZE))
	if is_equal_approx(remainder, 0.0) or is_equal_approx(remainder, float(Schema.TILE_SIZE)):
		return
	errors.append("%s must be %dpx grid-aligned, got %s." % [label, Schema.TILE_SIZE, str(value)])


func _require_property(errors: Array[String], properties: Dictionary, property_name: String, context: String) -> String:
	var text := _property_text(properties, property_name)
	if text == "":
		errors.append("%s is missing required property '%s'." % [context, property_name])
	return text


func _require_property_alias(
	errors: Array[String],
	properties: Dictionary,
	property_name: String,
	alias_name: String,
	context: String
) -> String:
	var text := _property_text(properties, property_name)
	if text != "":
		return text

	text = _property_text(properties, alias_name)
	if text == "":
		errors.append("%s is missing required property '%s' or '%s'." % [context, property_name, alias_name])
	return text


func _check_duplicate_id(errors: Array[String], seen_ids: Dictionary, id_value: String, property_name: String, context: String) -> void:
	if id_value == "":
		return
	if seen_ids.has(id_value):
		errors.append("Duplicate %s '%s' at %s; first seen at %s." % [
			property_name,
			id_value,
			context,
			str(seen_ids[id_value]),
		])
		return
	seen_ids[id_value] = context


func _property_text(properties: Dictionary, property_name: String) -> String:
	return str(properties.get(property_name, "")).strip_edges()


func _object_context(layer_name: String, object_data: Dictionary) -> String:
	var object_name := str(object_data.get("name", "")).strip_edges()
	var object_id := int(object_data.get("id", 0))
	if object_name != "":
		return "%s object '%s' (#%d)" % [layer_name, object_name, object_id]
	return "%s object #%d" % [layer_name, object_id]


func _parse_points(points_text: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point_text in points_text.split(" ", false):
		var pair := str(point_text).split(",", false)
		if pair.size() != 2:
			continue
		points.append(Vector2(float(pair[0]), float(pair[1])))
	return points
