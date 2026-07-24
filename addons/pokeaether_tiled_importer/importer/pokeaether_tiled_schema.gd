@tool
extends RefCounted
class_name PokeAetherTiledSchema

const CURRENT_SCHEMA_VERSION := 1
const TILE_SIZE := 32
const GENERATED_MAP_ROOT := "res://generated/maps"

const MAP_PROPERTY_SCHEMA_VERSION := "pa_schema_version"
const MAP_PROPERTY_MAP_ID := "map_id"
const MAP_PROPERTY_MAP_DISPLAY_NAME := "map_display_name"
const MAP_PROPERTY_REGION_ID := "region_id"
const MAP_PROPERTY_REGION_NAME := "region_name"
const MAP_PROPERTY_LOCATION_ID := "location_id"
const MAP_PROPERTY_LOCATION_NAME := "location_name"
const MAP_PROPERTY_MUSIC_TRACK_PATH := "music_track_path"
const MAP_PROPERTY_DEFAULT_SPAWN := "default_spawn"
const MAP_PROPERTY_ENCOUNTER_AREA_ID := "encounter_area_id"

const TILE_LAYER_COLLISION := "Collision"
const TILE_LAYER_TALL_GRASS := "TallGrass"
const TILE_LAYER_LEDGE_DOWN := "LedgeDown"
const TILE_LAYER_LEDGE_UP := "LedgeUp"
const TILE_LAYER_LEDGE_LEFT := "LedgeLeft"
const TILE_LAYER_LEDGE_RIGHT := "LedgeRight"
const TILE_LAYER_ROUTE_GATES := "RouteGates"

const REQUIRED_DIRECT_TILE_LAYERS: Array[String] = [
	TILE_LAYER_COLLISION,
	TILE_LAYER_TALL_GRASS,
	TILE_LAYER_LEDGE_DOWN,
	TILE_LAYER_LEDGE_UP,
	TILE_LAYER_LEDGE_LEFT,
	TILE_LAYER_LEDGE_RIGHT,
	TILE_LAYER_ROUTE_GATES,
]

const HIDDEN_RUNTIME_TILE_LAYERS: Array[String] = [
	TILE_LAYER_COLLISION,
	TILE_LAYER_ROUTE_GATES,
]

const OBJECT_LAYER_SPAWNS := "PA_Spawns"
const OBJECT_LAYER_WARPS := "PA_Warps"
const OBJECT_LAYER_NPCS := "PA_NPCs"
const OBJECT_LAYER_INTERACTABLES := "PA_Interactables"
const OBJECT_LAYER_ITEMS := "PA_Items"
const OBJECT_LAYER_ENCOUNTER_REGIONS := "PA_EncounterRegions"
const OBJECT_LAYER_TRIGGERS := "PA_Triggers"

const PA_OBJECT_LAYERS: Array[String] = [
	OBJECT_LAYER_SPAWNS,
	OBJECT_LAYER_WARPS,
	OBJECT_LAYER_NPCS,
	OBJECT_LAYER_INTERACTABLES,
	OBJECT_LAYER_ITEMS,
	OBJECT_LAYER_ENCOUNTER_REGIONS,
	OBJECT_LAYER_TRIGGERS,
]

const PROP_SPAWN_ID := "spawn_id"
const PROP_FACING := "facing"

const PROP_WARP_ID := "warp_id"
const PROP_TARGET_MAP_ID := "target_map_id"
const PROP_TARGET_SCENE_PATH := "target_scene_path"
const PROP_TARGET_SPAWN_NAME := "target_spawn_name"
const PROP_TARGET_SPAWN_ALIAS := "target_spawn"
const PROP_ENABLED := "enabled"

const PROP_NPC_ID := "npc_id"
const PROP_NPC_DEFINITION_ID := "npc_definition_id"
const PROP_NPC_KIND := "npc_kind"
const PROP_SCENE_PATH := "scene_path"
const PROP_DISPLAY_NAME := "display_name"
const PROP_TRAINER_ID := "trainer_id"
const PROP_DIALOGUE_ID := "dialogue_id"
const PROP_SIGHT_RANGE_TILES := "sight_range_tiles"

const PROP_INTERACTABLE_ID := "interactable_id"
const PROP_INTERACTABLE_KIND := "interactable_kind"
const PROP_DIALOGUE := "dialogue"
const PROP_BLOCKS_MOVEMENT := "blocks_movement"
const PROP_REQUIRES_FACING := "requires_facing"
const PROP_BLOCKED_TILE_OFFSET_X := "blocked_tile_offset_x"
const PROP_BLOCKED_TILE_OFFSET_Y := "blocked_tile_offset_y"

const PROP_ITEM_SPAWN_ID := "item_spawn_id"
const PROP_ITEM_ID := "item_id"
const PROP_QUANTITY := "quantity"
const PROP_FLAG_ID := "flag_id"

const PROP_ENCOUNTER_REGION_ID := "encounter_region_id"
const PROP_ENCOUNTER_AREA_ID := "encounter_area_id"
const PROP_ENCOUNTER_TYPE := "encounter_type"
const PROP_ENCOUNTER_CHANCE := "encounter_chance"

const PROP_TRIGGER_ID := "trigger_id"
const PROP_TRIGGER_KIND := "trigger_kind"
const PROP_EVENT_ID := "event_id"
const PROP_ONCE := "once"


static func is_special_tile_layer(layer_name: String) -> bool:
	return REQUIRED_DIRECT_TILE_LAYERS.has(layer_name)


static func is_hidden_runtime_tile_layer(layer_name: String) -> bool:
	return HIDDEN_RUNTIME_TILE_LAYERS.has(layer_name)


static func is_pa_object_layer(layer_name: String) -> bool:
	return PA_OBJECT_LAYERS.has(layer_name)


static func get_generated_dir(map_id: String) -> String:
	return GENERATED_MAP_ROOT.path_join(map_id)


static func is_safe_id(value: String) -> bool:
	var text := value.strip_edges()
	if text == "":
		return false

	for index in range(text.length()):
		var code := text.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_separator := code == 45 or code == 95
		if not (is_digit or is_upper or is_lower or is_separator):
			return false

	return true
