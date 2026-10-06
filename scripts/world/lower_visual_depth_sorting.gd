extends RefCounted

const STRUCTURE_GROUP_META := &"pao_structure_top_depth_group"
const DEPTH_LAYER_META := &"pao_lower_visual_depth_layer"


static func build_depth_layers(
	top: TileMapLayer, group_root: Node2D, family: Dictionary,
	bottom_layer_names: Array, family_depth_meta: StringName
) -> int:
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
		if layer == null or layer == top or _is_depth_layer(layer):
			continue
		if layer.top_level or layer.transform != top.transform or layer.tile_set == null:
			continue
		if layer.tile_set.tile_size != Vector2i(32, 32):
			continue
		var layer_name := str(layer.get_meta("tiled_name", layer.name))
		if bottom_layer_names.has(layer_name):
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

	# Never retain tile/image caches or actor state across map loads.
	var signatures := {}
	var images := {}
	var replacements := {}
	var moved := 0
	for cell: Vector2i in top.get_used_cells():
		if _get_signature(top, cell, signatures, images) != family.parts[Vector2i.ZERO]:
			continue
		if not _matches(top, cell, 0, family.upper_rows, family, signatures, images):
			continue
		var group := groups_by_cell.get(cell) as TileMapLayer
		if group == null or not _shares_group(groups_by_cell, cell, group, family):
			continue
		var ambiguous := false
		for other: TileMapLayer in other_tops:
			if _matches(other, cell, 0, family.upper_rows, family, signatures, images):
				ambiguous = true
				break
		if ambiguous:
			continue
		var matching_bottom: TileMapLayer
		for bottom: TileMapLayer in bottoms:
			if _matches(bottom, cell, family.upper_rows, family.size.y, family, signatures, images):
				if matching_bottom != null:
					ambiguous = true
					break
				matching_bottom = bottom
		if ambiguous or matching_bottom == null:
			continue
		if not matching_bottom.visible or matching_bottom.get_script() != null or matching_bottom.get_child_count() != 0:
			continue

		var key := "%d:%d" % [matching_bottom.get_instance_id(), group.z_index]
		var replacement := replacements.get(key) as TileMapLayer
		if replacement == null:
			# Duplicate native settings and shared animation/material resources,
			# not custom scripts or child nodes. Only membership and Z change.
			replacement = matching_bottom.duplicate(0) as TileMapLayer
			replacement.clear()
			replacement.name = "%s%sDepth%d" % [matching_bottom.name, family.name, group.z_index]
			replacement.z_as_relative = false
			replacement.z_index = group.z_index
			replacement.set_meta(DEPTH_LAYER_META, true)
			replacement.set_meta(family_depth_meta, true)
			matching_bottom.get_parent().add_child(replacement)
			# Preserve upper-over-lower drawing when objects overlap at equal Z.
			matching_bottom.get_parent().move_child(replacement, group_root.get_index())
			replacements[key] = replacement
		for row in range(family.upper_rows, family.size.y):
			for column in range(family.size.x):
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


static func _is_depth_layer(layer: TileMapLayer) -> bool:
	return bool(layer.get_meta(DEPTH_LAYER_META, false)) \
		or bool(layer.get_meta(&"pao_tree_lower_depth_layer", false)) \
		or bool(layer.get_meta(&"pao_object_lower_depth_layer", false))


static func _shares_group(lookup: Dictionary, cell: Vector2i, group: TileMapLayer, family: Dictionary) -> bool:
	for row in range(family.upper_rows):
		for column in range(family.size.x):
			if lookup.get(cell + Vector2i(column, row)) != group:
				return false
	return true


static func _matches(
	layer: TileMapLayer, cell: Vector2i, first_row: int, end_row: int,
	family: Dictionary, signatures: Dictionary, images: Dictionary
) -> bool:
	for row in range(first_row, end_row):
		for column in range(family.size.x):
			var part := Vector2i(column, row)
			if _get_signature(layer, cell + part, signatures, images) != family.parts[part]:
				return false
	return true


static func _get_signature(layer: TileMapLayer, cell: Vector2i, signatures: Dictionary, images: Dictionary) -> String:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0 or layer.get_cell_alternative_tile(cell) != 0:
		return ""
	var coords := layer.get_cell_atlas_coords(cell)
	var key := "%d:%d:%s" % [layer.tile_set.get_instance_id(), source_id, coords]
	if signatures.has(key):
		return signatures[key]
	signatures[key] = ""
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return ""
	var region := atlas.get_tile_texture_region(coords)
	if region.size != Vector2i(32, 32):
		return ""
	var texture_id := atlas.texture.get_instance_id()
	if not images.has(texture_id):
		var image := atlas.texture.get_image()
		if image == null or image.is_empty():
			return ""
		image.convert(Image.FORMAT_RGBA8)
		images[texture_id] = image
	var pixels: Image = images[texture_id]
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_region(region).get_data())
	signatures[key] = hash.finish().hex_encode()
	return signatures[key]
