extends RefCounted

class_name HorizontalStairElevation

const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")

# Marker names describe which horizontal direction climbs the staircase.
# The opposite direction automatically uses the descending presentation.
const UP_LEFT_LAYER_NAMES: Array[String] = ["StairUpLeft", "StairsUpLeft"]
const UP_RIGHT_LAYER_NAMES: Array[String] = ["StairUpRight", "StairsUpRight"]
const ELEVATION_NONE := 0
const ELEVATION_UP := -1
const ELEVATION_DOWN := 1
const DEFAULT_VISUAL_HEIGHT := 8.0


static func elevation_for_stair_exit(
	map_root: Node,
	stair_world_position: Vector2,
	landing_world_position: Vector2,
	movement_direction: Vector2
) -> int:
	if map_root == null or not is_instance_valid(map_root):
		return ELEVATION_NONE
	if movement_direction != Vector2.LEFT and movement_direction != Vector2.RIGHT:
		return ELEVATION_NONE

	var up_left_layer := MapLayerResolverScript.find_tilemap_layer(
		map_root,
		UP_LEFT_LAYER_NAMES
	)
	var up_right_layer := MapLayerResolverScript.find_tilemap_layer(
		map_root,
		UP_RIGHT_LAYER_NAMES
	)
	var starts_on_up_left := _tilemap_has_tile_at(up_left_layer, stair_world_position)
	var starts_on_up_right := _tilemap_has_tile_at(up_right_layer, stair_world_position)
	if not starts_on_up_left and not starts_on_up_right:
		return ELEVATION_NONE
	if (
		_tilemap_has_tile_at(up_left_layer, landing_world_position)
		or _tilemap_has_tile_at(up_right_layer, landing_world_position)
	):
		return ELEVATION_NONE

	if starts_on_up_left:
		return ELEVATION_UP if movement_direction == Vector2.LEFT else ELEVATION_DOWN
	if starts_on_up_right:
		return ELEVATION_UP if movement_direction == Vector2.RIGHT else ELEVATION_DOWN

	return ELEVATION_NONE


static func visual_offset(
	progress: float,
	elevation: int,
	visual_height: float = DEFAULT_VISUAL_HEIGHT
) -> Vector2:
	if elevation == ELEVATION_NONE or visual_height <= 0.0:
		return Vector2.ZERO
	var eased_height := sin(clampf(progress, 0.0, 1.0) * PI) * visual_height
	return Vector2(0.0, roundf(eased_height * signi(elevation)))


static func _tilemap_has_tile_at(tilemap: TileMapLayer, world_position: Vector2) -> bool:
	if tilemap == null:
		return false
	var tile_position := tilemap.local_to_map(tilemap.to_local(world_position))
	return tilemap.get_cell_source_id(tile_position) != -1 \
		or tilemap.get_cell_tile_data(tile_position) != null
