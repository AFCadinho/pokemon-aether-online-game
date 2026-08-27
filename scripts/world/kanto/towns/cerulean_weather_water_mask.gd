extends RefCounted

const MASK_NAME := "WeatherWater"
const WATER_POLICY_META := "pao_rain_surface"
const GENERATED_MASK_META := "pao_generated_weather_water_mask"
const GROUND_LAYER_NAME := "Ground"
const WATER_SOURCE_ID := 1
const ATLAS_COLUMNS := 8
const WATER_TILE_INDEX_MIN := 320
const WATER_TILE_INDEX_MAX := 338


static func build(visuals: Node) -> TileMapLayer:
	if visuals == null:
		return null
	var existing_mask := visuals.get_node_or_null(MASK_NAME) as TileMapLayer
	if existing_mask != null:
		return existing_mask
	var ground := visuals.get_node_or_null(GROUND_LAYER_NAME) as TileMapLayer
	if ground == null or ground.tile_set == null:
		return null

	var water_mask := TileMapLayer.new()
	water_mask.name = MASK_NAME
	water_mask.tile_set = ground.tile_set
	water_mask.position = ground.position
	water_mask.visible = false
	water_mask.z_index = ground.z_index
	water_mask.set_meta(WATER_POLICY_META, "water")
	water_mask.set_meta("tiled_name", "Water")
	water_mask.set_meta(GENERATED_MASK_META, true)
	visuals.add_child(water_mask)

	for cell: Vector2i in ground.get_used_cells():
		var source_id := ground.get_cell_source_id(cell)
		var atlas_coords := ground.get_cell_atlas_coords(cell)
		if not _is_water_tile(source_id, atlas_coords):
			continue
		water_mask.set_cell(
			cell,
			source_id,
			atlas_coords,
			ground.get_cell_alternative_tile(cell)
		)
	return water_mask


static func _is_water_tile(source_id: int, atlas_coords: Vector2i) -> bool:
	if source_id != WATER_SOURCE_ID or atlas_coords.x < 0 or atlas_coords.y < 0:
		return false
	var tile_index := atlas_coords.y * ATLAS_COLUMNS + atlas_coords.x
	return tile_index >= WATER_TILE_INDEX_MIN and tile_index <= WATER_TILE_INDEX_MAX
