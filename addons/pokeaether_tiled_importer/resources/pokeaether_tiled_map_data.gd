@tool
extends Resource
class_name PokeAetherTiledMapData

@export var schema_version := 1
@export var source_tmx_path := ""
@export var map_id := ""
@export var map_display_name := ""
@export var region_id := ""
@export var region_name := ""
@export var location_id := ""
@export var location_name := ""
@export var music_track_path := ""
@export var default_spawn := ""
@export var encounter_area_id := ""
@export var map_size_tiles := Vector2i.ZERO
@export var tile_size := Vector2i(32, 32)
@export var properties: Dictionary = {}
@export var spawns: Array[Resource] = []
@export var warps: Array[Resource] = []
@export var npcs: Array[Resource] = []
@export var interactables: Array[Resource] = []
@export var items: Array[Resource] = []
@export var encounter_regions: Array[Resource] = []
@export var triggers: Array[Resource] = []
