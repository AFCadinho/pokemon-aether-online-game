extends "res://scripts/world/map_metadata.gd"

const CeruleanWeatherWaterMaskScript := preload(
	"res://scripts/world/kanto/towns/cerulean_weather_water_mask.gd"
)

const MAP_SIZE := Vector2i(75, 70)
const EXIT_OPENINGS := {
	"route_4": {
		"axis": "left",
		"from": 23,
		"to": 27,
	},
	"route_4_water": {
		"axis": "left",
		"from": 15,
		"to": 21,
	},
	"route_24_water_left": {
		"axis": "top",
		"from": 46,
		"to": 51,
	},
	"route_24_bridge": {
		"axis": "top",
		"from": 52,
		"to": 60,
	},
	"route_24_water_right": {
		"axis": "top",
		"from": 61,
		"to": 64,
	},
	"route_24_path": {
		"axis": "top",
		"from": 67,
		"to": 71,
	},
	"route_9": {
		"axis": "right",
		"from": 42,
		"to": 47,
	},
	"route_5_left": {
		"axis": "bottom",
		"from": 11,
		"to": 13,
	},
	"route_5_grass": {
		"axis": "bottom",
		"from": 15,
		"to": 18,
	},
	"route_5_right": {
		"axis": "bottom",
		"from": 20,
		"to": 22,
	},
}

const WATER_CONNECTION_DEPTH := 15
const MOUNTAIN_DEPTH_SORT_BASE_Z := 2054
const MOUNTAIN_DEPTH_ZONES_PATH := NodePath("MountainDepthZones")
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.1
const WATER_CONNECTIONS := [
	{
		"axis": "top",
		"from": 46,
		"to": 51,
	},
	{
		"axis": "top",
		"from": 61,
		"to": 64,
	},
	{
		"axis": "left",
		"from": 15,
		"to": 21,
	},
]

@onready var water: TileMapLayer = find_map_tilemap_layer("Water")

func _ready() -> void:
	CeruleanWeatherWaterMaskScript.build(get_node_or_null("CeruleanCityVisual"))
	_open_exterior_connections()
	_build_water_connections()
	super._ready()


func get_wild_encounter_chance(encounter_type: String = "grass") -> float:
	match encounter_type.strip_edges().to_lower():
		"grass":
			return grass_encounter_chance
		"cave":
			return cave_encounter_chance
		"surf":
			return surf_encounter_chance
		_:
			return 0.0


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	var encounter_chance := get_wild_encounter_chance(encounter_type)
	if encounter_chance <= 0.0:
		return false
	return randf() <= encounter_chance


func get_actor_sort_z_floor(world_position: Vector2) -> int:
	var mountain_sort_z := _get_mountain_depth_sort_z(world_position)
	if mountain_sort_z >= MOUNTAIN_DEPTH_SORT_BASE_Z:
		return mountain_sort_z
	return super.get_actor_sort_z_floor(world_position)


func get_structure_top_sort_z_floor(world_position: Vector2) -> int:
	return _get_mountain_depth_sort_z(world_position)


func _get_mountain_depth_sort_z(world_position: Vector2) -> int:
	var polygon := _find_mountain_depth_zone(world_position)
	if polygon == null:
		return -4096

	var zone_top_y := INF
	for point: Vector2 in polygon.polygon:
		zone_top_y = minf(zone_top_y, polygon.to_global(point).y)
	if is_inf(zone_top_y):
		return -4096

	# The plateau itself occupies z=2053. Shift the zone's regular world-Y
	# sorting into the band above it, while retaining front/back ordering.
	return MOUNTAIN_DEPTH_SORT_BASE_Z + floori(world_position.y - zone_top_y)


func _find_mountain_depth_zone(world_position: Vector2) -> CollisionPolygon2D:
	var depth_zones := get_node_or_null(MOUNTAIN_DEPTH_ZONES_PATH)
	if depth_zones == null:
		return null
	for area_node: Node in depth_zones.get_children():
		for child_node: Node in area_node.get_children():
			var polygon := child_node as CollisionPolygon2D
			if polygon != null and Geometry2D.is_point_in_polygon(
				polygon.to_local(world_position),
				polygon.polygon
			):
				return polygon
	return null


func _open_exterior_connections() -> void:
	if collision == null:
		push_error("Cerulean City could not resolve its Collision tile layer.")
		return
	for opening_value: Variant in EXIT_OPENINGS.values():
		var opening: Dictionary = opening_value as Dictionary
		var opening_axis := str(opening.get("axis", ""))
		var opening_from := int(opening.get("from", 0))
		var opening_to := int(opening.get("to", -1))
		for offset: int in range(opening_from, opening_to + 1):
			match opening_axis:
				"top":
					collision.erase_cell(Vector2i(offset, 0))
					collision.erase_cell(Vector2i(offset, -1))
				"bottom":
					collision.erase_cell(Vector2i(offset, MAP_SIZE.y - 1))
					collision.erase_cell(Vector2i(offset, MAP_SIZE.y))
				"left":
					collision.erase_cell(Vector2i(0, offset))
					collision.erase_cell(Vector2i(-1, offset))
				"right":
					collision.erase_cell(Vector2i(MAP_SIZE.x - 1, offset))
					collision.erase_cell(Vector2i(MAP_SIZE.x, offset))


func _build_water_connections() -> void:
	if water == null:
		push_error("Cerulean City could not resolve its Water tile layer.")
		return

	# Rewrite only the off-map transition strip. Water south of this strip is
	# hand-painted around the irregular shore and must survive map setup.
	for x: int in range(46, 65):
		for y: int in range(WATER_CONNECTION_DEPTH):
			water.erase_cell(Vector2i(x, y))

	for connection_value: Variant in WATER_CONNECTIONS:
		var connection := connection_value as Dictionary
		var axis := str(connection.get("axis", ""))
		var range_from := int(connection.get("from", 0))
		var range_to := int(connection.get("to", -1))
		for offset: int in range(range_from, range_to + 1):
			for depth: int in range(WATER_CONNECTION_DEPTH):
				var cell := Vector2i(depth, offset)
				if axis == "top":
					cell = Vector2i(offset, depth)
				water.set_cell(cell, 0, Vector2i.ZERO)
