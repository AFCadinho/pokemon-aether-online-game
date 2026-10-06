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
const WATER_SOURCE_ID := 1025
const ATLAS_COLUMNS := 8
const WATER_TILE_INDEX_MIN := 58
const WATER_TILE_INDEX_MAX := 59
# Approved Cerulean water artwork from the animation catalog. Compaction
# remaps source IDs and coordinates, while these lossless first-frame pixels
# remain unchanged. Include shoreline tiles as well as the open water.
const WATER_PIXEL_SHA256 := [
	"32004a5fbf26b33eeb35e3c385590f35395216ae63661f0d51165191e8979a48",
	"48f89fb7f3ea2f4620aea576a811f2296db485c36823743164a87de8dd26c822",
	"51a954bc80c136869c550df02f70719f847cfc5066b13ab8cf41b7c83d097d44",
	"6610a7e25048ceae85ee65e50559c1f7da8a41e8ac06c321d27c2e600e7ceb17",
	"6cc6c66f6d6e39ce2beb5547f618fa0dd3b28b5ab6d6000fd0a3546dc6ac98d6",
	"70d388a941f4bcfbe654c94c2c7720402ad87f2fa3d08df8f431d08003802f61",
	"7b77b4aea80a3272fe7f0f0058e407bb01e78f42e73e9e6c718cfca64f899180",
	"a7bc7224e9582f37c637b45beac68f8c18f1da29d9dd7bcde4a1054c75211ea3",
	"aa4342e0fedcbd81d9e08316429621d9d74add01d68ef1fca5005f168ef49cec",
	"ab7d8167a7fe983d925f92db8554c9ec785993830c695983f63cd0c277fae12f",
	"dc04fadc6f05976ccfeaca74ad0eb70ca5a2b69ba6c5d1c4181c8f9141896285",
	"dc4eee54b1e62618309d94991d289d88a0f36dc5811f1367dfd72db28065e88e",
	"ee127c0a941fb66b16832775a7341754d793d1eead248226ec09b8cf7c12529d",
]


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

	var water_tiles := _classify_water_tiles(ground)
	for cell: Vector2i in ground.get_used_cells():
		var source_id := ground.get_cell_source_id(cell)
		var atlas_coords := ground.get_cell_atlas_coords(cell)
		if not water_tiles.has(_tile_key(source_id, atlas_coords)):
			continue
		water_mask.set_cell(
			cell,
			source_id,
			atlas_coords,
			ground.get_cell_alternative_tile(cell)
		)
	return water_mask


static func _tile_key(source_id: int, coords: Vector2i) -> String:
	return "%d/%d/%d" % [source_id, coords.x, coords.y]


static func _classify_water_tiles(ground: TileMapLayer) -> Dictionary:
	var water := {}
	var visited := {}
	var images := {}
	var compact := int(ground.tile_set.get_meta("tiled_compact_atlas_version", 0)) > 0
	for cell: Vector2i in ground.get_used_cells():
		var id := ground.get_cell_source_id(cell)
		var coords := ground.get_cell_atlas_coords(cell)
		var key := _tile_key(id, coords)
		if visited.has(key):
			continue
		visited[key] = true
		if not compact:
			if _is_water_tile(id, coords):
				water[key] = true
			continue
		var source := ground.tile_set.get_source(id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		if not images.has(id):
			var image := source.texture.get_image()
			if image == null:
				continue
			image.convert(Image.FORMAT_RGBA8)
			images[id] = image
		var image: Image = images[id]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
		if WATER_PIXEL_SHA256.has(hash.finish().hex_encode()):
			water[key] = true
	return water


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
