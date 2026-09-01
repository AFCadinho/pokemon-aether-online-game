extends "res://scripts/world/map_metadata.gd"

const CeruleanWeatherWaterMaskScript := preload(
	"res://scripts/world/kanto/towns/cerulean_weather_water_mask.gd"
)

const MOUNTAIN_DEPTH_SORT_BASE_Z := 2054
const MOUNTAIN_DEPTH_ZONES_PATH := NodePath("MountainDepthZones")
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.1

func _ready() -> void:
	CeruleanWeatherWaterMaskScript.build(get_node_or_null("CeruleanCityVisual"))
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
