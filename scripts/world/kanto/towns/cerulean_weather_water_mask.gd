extends RefCounted

const MASK_NAME := "WeatherWater"
const WATER_POLICY_META := "pao_rain_surface"
const GENERATED_MASK_META := "pao_generated_weather_water_mask"
const GROUND_LAYER_NAME := "Ground"
const CERULEAN_VISUAL_LAYER_NAMES := {
	1: "Ground",
	2: "GroundDetail",
	3: "Objects",
	4: "ObjectsTop",
}
const WATER_SOURCE_ID := 1
const ATLAS_COLUMNS := 8
const WATER_TILE_INDEX_MIN := 320
const WATER_TILE_INDEX_MAX := 338


static func build(visuals: Node) -> TileMapLayer:
	if visuals == null:
		return null
	_apply_visual_layer_semantics(visuals)
	var existing_mask := visuals.get_node_or_null(MASK_NAME) as TileMapLayer
	if existing_mask != null:
		return existing_mask
	var ground := _find_visual_layer(visuals, GROUND_LAYER_NAME, 1)
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


static func _apply_visual_layer_semantics(visuals: Node) -> void:
	for child: Node in visuals.get_children():
		var layer := child as TileMapLayer
		if layer == null:
			continue
		var layer_id := int(layer.get_meta("tiled_layer_id", -1))
		if CERULEAN_VISUAL_LAYER_NAMES.has(layer_id):
			layer.set_meta("tiled_name", CERULEAN_VISUAL_LAYER_NAMES[layer_id])


static func _find_visual_layer(visuals: Node, layer_name: String, layer_id: int) -> TileMapLayer:
	var named_layer := visuals.get_node_or_null(layer_name) as TileMapLayer
	if named_layer != null:
		return named_layer
	for child: Node in visuals.get_children():
		var layer := child as TileMapLayer
		if layer != null and int(layer.get_meta("tiled_layer_id", -1)) == layer_id:
			return layer
	return null


static func _is_water_tile(source_id: int, atlas_coords: Vector2i) -> bool:
	if source_id != WATER_SOURCE_ID or atlas_coords.x < 0 or atlas_coords.y < 0:
		return false
	var tile_index := atlas_coords.y * ATLAS_COLUMNS + atlas_coords.x
	return tile_index >= WATER_TILE_INDEX_MIN and tile_index <= WATER_TILE_INDEX_MAX
