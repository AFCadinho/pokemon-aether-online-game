@tool
extends RefCounted

const Schema := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_schema.gd")
const MapData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_map_data.gd")
const SpawnData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_spawn_data.gd")
const WarpData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_warp_data.gd")
const NpcData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_npc_data.gd")
const InteractableData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_interactable_data.gd")
const ItemData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_item_data.gd")
const EncounterRegionData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_encounter_region_data.gd")
const TriggerData := preload("res://addons/pokeaether_tiled_importer/resources/pokeaether_tiled_trigger_data.gd")


func build_map_data(map_data: Dictionary) -> Resource:
	var properties: Dictionary = map_data.get("properties", {})
	var resource := MapData.new()
	resource.schema_version = int(properties.get(Schema.MAP_PROPERTY_SCHEMA_VERSION, Schema.CURRENT_SCHEMA_VERSION))
	resource.source_tmx_path = str(map_data.get("source_path", ""))
	resource.map_id = _property_text(properties, Schema.MAP_PROPERTY_MAP_ID)
	resource.map_display_name = _property_text(properties, Schema.MAP_PROPERTY_MAP_DISPLAY_NAME)
	resource.region_id = _property_text(properties, Schema.MAP_PROPERTY_REGION_ID)
	resource.region_name = _property_text(properties, Schema.MAP_PROPERTY_REGION_NAME)
	resource.location_id = _property_text(properties, Schema.MAP_PROPERTY_LOCATION_ID)
	resource.location_name = _property_text(properties, Schema.MAP_PROPERTY_LOCATION_NAME)
	resource.music_track_path = _property_text(properties, Schema.MAP_PROPERTY_MUSIC_TRACK_PATH)
	resource.default_spawn = _property_text(properties, Schema.MAP_PROPERTY_DEFAULT_SPAWN)
	resource.encounter_area_id = _property_text(properties, Schema.MAP_PROPERTY_ENCOUNTER_AREA_ID)
	resource.map_size_tiles = Vector2i(int(map_data.get("width", 0)), int(map_data.get("height", 0)))
	resource.tile_size = Vector2i(int(map_data.get("tile_width", 0)), int(map_data.get("tile_height", 0)))
	resource.properties = properties.duplicate(true)

	for group: Dictionary in map_data.get("object_groups", []):
		var layer_name := str(group.get("name", ""))
		for object_data: Dictionary in group.get("objects", []):
			match layer_name:
				Schema.OBJECT_LAYER_SPAWNS:
					resource.spawns.append(_build_spawn(layer_name, object_data))
				Schema.OBJECT_LAYER_WARPS:
					resource.warps.append(_build_warp(layer_name, object_data))
				Schema.OBJECT_LAYER_NPCS:
					resource.npcs.append(_build_npc(layer_name, object_data))
				Schema.OBJECT_LAYER_INTERACTABLES:
					resource.interactables.append(_build_interactable(layer_name, object_data))
				Schema.OBJECT_LAYER_ITEMS:
					resource.items.append(_build_item(layer_name, object_data))
				Schema.OBJECT_LAYER_ENCOUNTER_REGIONS:
					resource.encounter_regions.append(_build_encounter_region(layer_name, object_data))
				Schema.OBJECT_LAYER_TRIGGERS:
					resource.triggers.append(_build_trigger(layer_name, object_data))

	return resource


func _build_spawn(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := SpawnData.new()
	resource.spawn_id = _property_text(properties, Schema.PROP_SPAWN_ID)
	resource.position = _point_to_tile_center(object_data)
	resource.facing = _property_text(properties, Schema.PROP_FACING, "down")
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_warp(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := WarpData.new()
	resource.warp_id = _property_text(properties, Schema.PROP_WARP_ID)
	resource.rect = _object_rect(object_data)
	resource.target_map_id = _property_text(properties, Schema.PROP_TARGET_MAP_ID)
	resource.target_scene_path = _property_text(properties, Schema.PROP_TARGET_SCENE_PATH)
	resource.target_spawn_name = _property_text(properties, Schema.PROP_TARGET_SPAWN_NAME)
	if resource.target_spawn_name == "":
		resource.target_spawn_name = _property_text(properties, Schema.PROP_TARGET_SPAWN_ALIAS)
	resource.enabled = bool(properties.get(Schema.PROP_ENABLED, true))
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_npc(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := NpcData.new()
	resource.npc_id = _property_text(properties, Schema.PROP_NPC_ID)
	resource.npc_definition_id = _property_text(properties, Schema.PROP_NPC_DEFINITION_ID)
	resource.npc_kind = _property_text(properties, Schema.PROP_NPC_KIND)
	resource.position = _point_to_tile_center(object_data)
	resource.facing = _property_text(properties, Schema.PROP_FACING, "down")
	resource.scene_path = _property_text(properties, Schema.PROP_SCENE_PATH)
	resource.display_name = _property_text(properties, Schema.PROP_DISPLAY_NAME)
	resource.trainer_id = _property_text(properties, Schema.PROP_TRAINER_ID)
	resource.dialogue_id = _property_text(properties, Schema.PROP_DIALOGUE_ID)
	resource.sight_range_tiles = int(properties.get(Schema.PROP_SIGHT_RANGE_TILES, 0))
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_interactable(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := InteractableData.new()
	resource.interactable_id = _property_text(properties, Schema.PROP_INTERACTABLE_ID)
	resource.interactable_kind = _property_text(properties, Schema.PROP_INTERACTABLE_KIND, "generic")
	resource.position = _point_to_tile_center(object_data)
	resource.display_name = _property_text(properties, Schema.PROP_DISPLAY_NAME)
	resource.dialogue_id = _property_text(properties, Schema.PROP_DIALOGUE_ID)
	resource.dialogue_lines = _property_text_lines(properties, Schema.PROP_DIALOGUE)
	resource.scene_path = _property_text(properties, Schema.PROP_SCENE_PATH)
	resource.blocks_movement = bool(properties.get(Schema.PROP_BLOCKS_MOVEMENT, true))
	resource.requires_facing = bool(properties.get(Schema.PROP_REQUIRES_FACING, true))
	resource.blocked_tile_offset = Vector2i(
		int(properties.get(Schema.PROP_BLOCKED_TILE_OFFSET_X, 0)),
		int(properties.get(Schema.PROP_BLOCKED_TILE_OFFSET_Y, 0))
	)
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_item(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := ItemData.new()
	resource.item_spawn_id = _property_text(properties, Schema.PROP_ITEM_SPAWN_ID)
	resource.item_id = _property_text(properties, Schema.PROP_ITEM_ID)
	resource.quantity = int(properties.get(Schema.PROP_QUANTITY, 1))
	resource.flag_id = _property_text(properties, Schema.PROP_FLAG_ID)
	resource.position = _point_to_tile_center(object_data)
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_encounter_region(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := EncounterRegionData.new()
	resource.encounter_region_id = _property_text(properties, Schema.PROP_ENCOUNTER_REGION_ID)
	resource.encounter_area_id = _property_text(properties, Schema.PROP_ENCOUNTER_AREA_ID)
	resource.encounter_type = _property_text(properties, Schema.PROP_ENCOUNTER_TYPE, "grass")
	resource.encounter_chance = float(properties.get(Schema.PROP_ENCOUNTER_CHANCE, -1.0))
	resource.shape = str(object_data.get("shape", "rectangle"))
	resource.rect = _object_rect(object_data)
	resource.points = _parse_points(str(object_data.get("points", "")))
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _build_trigger(layer_name: String, object_data: Dictionary) -> Resource:
	var properties: Dictionary = object_data.get("properties", {})
	var resource := TriggerData.new()
	resource.trigger_id = _property_text(properties, Schema.PROP_TRIGGER_ID)
	resource.trigger_kind = _property_text(properties, Schema.PROP_TRIGGER_KIND)
	resource.event_id = _property_text(properties, Schema.PROP_EVENT_ID)
	resource.once = bool(properties.get(Schema.PROP_ONCE, false))
	resource.shape = str(object_data.get("shape", "rectangle"))
	resource.rect = _object_rect(object_data)
	resource.points = _parse_points(str(object_data.get("points", "")))
	_apply_source_metadata(resource, layer_name, object_data, properties)
	return resource


func _apply_source_metadata(resource: Resource, layer_name: String, object_data: Dictionary, properties: Dictionary) -> void:
	resource.set("source_layer_name", layer_name)
	resource.set("source_object_id", int(object_data.get("id", 0)))
	resource.set("properties", properties.duplicate(true))


func _point_to_tile_center(object_data: Dictionary) -> Vector2:
	return Vector2(
		float(object_data.get("x", 0.0)) + float(Schema.TILE_SIZE) * 0.5,
		float(object_data.get("y", 0.0)) + float(Schema.TILE_SIZE) * 0.5
	)


func _object_rect(object_data: Dictionary) -> Rect2:
	return Rect2(
		float(object_data.get("x", 0.0)),
		float(object_data.get("y", 0.0)),
		float(object_data.get("width", 0.0)),
		float(object_data.get("height", 0.0))
	)


func _parse_points(points_text: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_text in points_text.split(" ", false):
		var pair := str(point_text).split(",", false)
		if pair.size() != 2:
			continue
		points.append(Vector2(float(pair[0]), float(pair[1])))
	return points


func _property_text(properties: Dictionary, property_name: String, fallback := "") -> String:
	return str(properties.get(property_name, fallback)).strip_edges()


func _property_text_lines(properties: Dictionary, property_name: String) -> Array[String]:
	var lines: Array[String] = []
	var text := _property_text(properties, property_name)
	if text == "":
		return lines

	text = text.replace("\\n", "\n")
	for line: String in text.split("\n", false):
		var clean_line := line.strip_edges()
		if clean_line != "":
			lines.append(clean_line)

	return lines
