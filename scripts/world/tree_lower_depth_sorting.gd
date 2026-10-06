extends RefCounted

# The approved 64x128 evergreen, expressed as eight 32px RGBA tile hashes.
# Exact artwork works with both dense and compact atlases, independent of GIDs.
# Unknown artwork, alternative/flipped tiles and incomplete trees stay put.
const EVERGREEN_PARTS := {
	Vector2i(0, 0): "08b923787bd75fa45694a08e208f4988a7b93cc02f37879592977a2286986844",
	Vector2i(1, 0): "9bf02e8d9e64329a0b157130d1029ae5aacc459913e0715eb7afb95b03cc14e5",
	Vector2i(0, 1): "8a9a379139f7b2e0501be57dd4d618d505020958926615f6646427802af88896",
	Vector2i(1, 1): "599ad73b7eb77b97548154beda67f6c6bae1f887665005c38be76efcd5ca01d2",
	Vector2i(0, 2): "4606c7b7912e5570e35f31929344bb1c1a41a44af8c004fcd99293634c3be7f5",
	Vector2i(1, 2): "6128c62400a011407104ff47e045c9230ab8ec6d8d0813378fca695d620b69ae",
	Vector2i(0, 3): "1377675954ed320a98a055274f43d205fb309d580e8afd2b547410780b2eb714",
	Vector2i(1, 3): "7e0aadf74f969e4d9ac03187b52c67897c2e9442512e2790566a1fb8c06abc5c",
}
const BOTTOM_LAYER_NAMES := ["TreeBottom", "Tree Bottom", "StructureBottom", "StructureBottomVisual"]
const DEPTH_LAYER_META := &"pao_tree_lower_depth_layer"
const STRUCTURE_GROUP_META := &"pao_structure_top_depth_group"
const NO_PART := Vector2i(-1, -1)


static func build_depth_layers(top: TileMapLayer, group_root: Node2D) -> int:
	if top == null or group_root == null or top.get_parent() != group_root.get_parent():
		return 0
	if top.top_level or top.tile_set == null or top.tile_set.tile_size != Vector2i(32, 32):
		return 0
	if top.get_script() != null or top.get_child_count() != 0:
		return 0
	var bottoms: Array[TileMapLayer] = []
	var other_tops: Array[TileMapLayer] = []
	for sibling: Node in top.get_parent().get_children():
		var layer := sibling as TileMapLayer
		if layer == null or layer == top or layer.get_meta(DEPTH_LAYER_META, false):
			continue
		if layer.top_level or layer.transform != top.transform or layer.tile_set == null:
			continue
		if layer.tile_set.tile_size != Vector2i(32, 32):
			continue
		var layer_name := str(layer.get_meta("tiled_name", layer.name))
		if BOTTOM_LAYER_NAMES.has(layer_name):
			bottoms.append(layer)
		elif not layer.get_meta(STRUCTURE_GROUP_META, false):
			other_tops.append(layer)
	if bottoms.is_empty():
		return 0

	var groups_by_cell := {}
	for child: Node in group_root.get_children():
		var group := child as TileMapLayer
		if group == null or not group.get_meta(STRUCTURE_GROUP_META, false) or group.z_as_relative:
			continue
		for cell: Vector2i in group.get_used_cells():
			groups_by_cell[cell] = group

	# These caches live for this construction pass only, never across map loads.
	var parts := {}
	var images := {}
	var replacements := {}
	var moved := 0
	for cell: Vector2i in top.get_used_cells():
		if _get_part(top, cell, parts, images) != Vector2i.ZERO:
			continue
		if not _matches(top, cell, 0, 2, parts, images):
			continue
		var group := groups_by_cell.get(cell) as TileMapLayer
		if group == null or not _shares_group(groups_by_cell, cell, group):
			continue
		var ambiguous := false
		for other: TileMapLayer in other_tops:
			if _matches(other, cell, 0, 2, parts, images):
				ambiguous = true
				break
		if ambiguous:
			continue
		var matching_bottom: TileMapLayer
		for bottom: TileMapLayer in bottoms:
			if _matches(bottom, cell, 2, 4, parts, images):
				if matching_bottom != null:
					ambiguous = true
					break
				matching_bottom = bottom
		if ambiguous or matching_bottom == null:
			continue
		# Keep custom/hidden layers intact, even when their artwork matches.
		if not matching_bottom.visible or matching_bottom.get_script() != null or matching_bottom.get_child_count() != 0:
			continue

		var key := "%d:%d" % [matching_bottom.get_instance_id(), group.z_index]
		var replacement := replacements.get(key) as TileMapLayer
		if replacement == null:
			# Keep material, modulation, transform, animation sources and layer
			# settings; only cell membership and world depth change.
			replacement = matching_bottom.duplicate(0) as TileMapLayer
			replacement.clear()
			replacement.name = "%sTreeDepth%d" % [matching_bottom.name, group.z_index]
			replacement.z_as_relative = false
			replacement.z_index = group.z_index
			replacement.set_meta(DEPTH_LAYER_META, true)
			matching_bottom.get_parent().add_child(replacement)
			# Overlapping crowns must still cover lower parts at equal depth.
			matching_bottom.get_parent().move_child(replacement, group_root.get_index())
			replacements[key] = replacement
		for row in range(2, 4):
			for column in range(2):
				var target := cell + Vector2i(column, row)
				replacement.set_cell(
					target,
					matching_bottom.get_cell_source_id(target),
					matching_bottom.get_cell_atlas_coords(target),
					matching_bottom.get_cell_alternative_tile(target)
				)
				matching_bottom.erase_cell(target)
				moved += 1
	return moved


static func _shares_group(lookup: Dictionary, cell: Vector2i, group: TileMapLayer) -> bool:
	for row in range(2):
		for column in range(2):
			if lookup.get(cell + Vector2i(column, row)) != group:
				return false
	return true


static func _matches(
	layer: TileMapLayer, cell: Vector2i, first_row: int, end_row: int,
	parts: Dictionary, images: Dictionary
) -> bool:
	for row in range(first_row, end_row):
		for column in range(2):
			var part := Vector2i(column, row)
			if _get_part(layer, cell + part, parts, images) != part:
				return false
	return true


static func _get_part(layer: TileMapLayer, cell: Vector2i, parts: Dictionary, images: Dictionary) -> Vector2i:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0 or layer.get_cell_alternative_tile(cell) != 0:
		return NO_PART
	var coords := layer.get_cell_atlas_coords(cell)
	var key := "%d:%d:%s" % [layer.tile_set.get_instance_id(), source_id, coords]
	if parts.has(key):
		return parts[key]
	parts[key] = NO_PART
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return NO_PART
	var region := atlas.get_tile_texture_region(coords)
	if region.size != Vector2i(32, 32):
		return NO_PART
	var texture_id := atlas.texture.get_instance_id()
	if not images.has(texture_id):
		var image := atlas.texture.get_image()
		if image == null or image.is_empty():
			return NO_PART
		image.convert(Image.FORMAT_RGBA8)
		images[texture_id] = image
	var pixels: Image = images[texture_id]
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_region(region).get_data())
	var signature := hash.finish().hex_encode()
	for part: Vector2i in EVERGREEN_PARTS:
		if EVERGREEN_PARTS[part] == signature:
			parts[key] = part
			break
	return parts[key]
