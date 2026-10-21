extends RefCounted

# Raising tree bases to actor depth must not raise pixels that were hidden by
# authored scenery. Split only those pixels back onto the original base layer.
# Both pieces keep the layer's native material/modulation; shared atlases are
# never edited. This runs once, after every crown/grass depth group exists.
const SOURCE_META := &"pao_lower_visual_source_layer"
const DONE_META := &"pao_tree_scenery_occlusion_built"
const TREE_META := &"pao_tree_lower_depth_layer"
const TILE_SIZE := 32


static func preserve_scenery(map: Node) -> int:
	var layers: Array[TileMapLayer] = []
	_collect_layers(map, layers)
	var images := {}
	var tiles := {}
	var plans := {}
	var adjusted := 0
	for raised: TileMapLayer in layers:
		if not raised.get_meta(TREE_META, false) or raised.get_meta(DONE_META, false):
			continue
		raised.set_meta(DONE_META, true)
		var base := raised.get_node_or_null(raised.get_meta(SOURCE_META, NodePath())) as TileMapLayer
		if base == null:
			continue
		var occluders: Array[TileMapLayer] = []
		for other: TileMapLayer in layers:
			if other == base or other.get_meta(TREE_META, false):
				continue
			# Gameplay/collision layers outside this imported visual are not scenery.
			if not base.get_parent().is_ancestor_of(other):
				continue
			# Only layers whose order the promotion crosses can change scenery.
			if _comes_after(other, base, layers) and _comes_after(raised, other, layers):
				if other.global_transform == base.global_transform:
					occluders.append(other)
		if occluders.is_empty():
			continue
		for cell: Vector2i in raised.get_used_cells():
			var foreground_frames: Array[Image] = []
			for other: TileMapLayer in occluders:
				foreground_frames.append_array(_tile_frames(other, cell, images, tiles))
			# Most trees never cross any scenery. Avoid reading/splitting their
			# pixel buffers altogether, including on maps with no regressions.
			if foreground_frames.is_empty():
				continue
			var tree := _tile_frames(raised, cell, images, tiles)
			if tree.size() != 1:
				continue
			var covered := PackedByteArray()
			covered.resize(TILE_SIZE * TILE_SIZE)
			# Union animated coverage: retain the original pixels beneath all
			# frames, without freezing or replacing the animated foreground.
			for frame: Image in foreground_frames:
				var rgba := frame.get_data()
				for pixel in range(covered.size()):
					if rgba[pixel * 4 + 3] > 0:
						covered[pixel] = 1
			var front := tree[0].get_data() as PackedByteArray
			var back := front.duplicate()
			var has_front := false
			var has_back := false
			for pixel in range(covered.size()):
				if covered[pixel] != 0:
					has_back = has_back or front[pixel * 4 + 3] > 0
					front[pixel * 4 + 3] = 0
				else:
					has_front = has_front or front[pixel * 4 + 3] > 0
					back[pixel * 4 + 3] = 0
			if not has_back:
				continue
			if not plans.has(base):
				plans[base] = []
			plans[base].append({
				"raised": raised, "cell": cell, "has_front": has_front,
				"front": Image.create_from_data(32, 32, false, Image.FORMAT_RGBA8, front),
				"back": Image.create_from_data(32, 32, false, Image.FORMAT_RGBA8, back),
				"source": raised.get_cell_source_id(cell),
				"coords": raised.get_cell_atlas_coords(cell),
				"alternative": raised.get_cell_alternative_tile(cell),
			})
			adjusted += 1
	# Collect coverage before mutating any layer; results cannot depend on which
	# tree family/layer happens to be visited first.
	for base: TileMapLayer in plans:
		_apply_splits(base, plans[base])
	return adjusted


static func _apply_splits(base: TileMapLayer, plans: Array) -> void:
	var partial: Array = plans.filter(func(plan: Dictionary) -> bool: return plan.has_front)
	var tileset: TileSet = base.tile_set
	var source_id := -1
	if not partial.is_empty():
		# One compact runtime atlas per affected base layer, not one texture per
		# tree. All unchanged atlas sources and their animation clocks are shared.
		tileset = base.tile_set.duplicate(false) as TileSet
		var columns := mini(16, partial.size() * 2)
		var rows := ceili(float(partial.size() * 2) / columns)
		var pixels := Image.create(columns * 32, rows * 32, false, Image.FORMAT_RGBA8)
		var atlas := TileSetAtlasSource.new()
		atlas.texture_region_size = Vector2i(32, 32)
		for index in range(partial.size()):
			var plan: Dictionary = partial[index]
			plan["back_coords"] = Vector2i((index * 2) % columns, (index * 2) / columns)
			plan["front_coords"] = Vector2i((index * 2 + 1) % columns, (index * 2 + 1) / columns)
			pixels.blit_rect(plan.back, Rect2i(0, 0, 32, 32), plan.back_coords * 32)
			pixels.blit_rect(plan.front, Rect2i(0, 0, 32, 32), plan.front_coords * 32)
		atlas.texture = ImageTexture.create_from_image(pixels)
		for plan: Dictionary in partial:
			atlas.create_tile(plan.back_coords)
			atlas.create_tile(plan.front_coords)
		source_id = tileset.add_source(atlas)
		base.tile_set = tileset
	for plan: Dictionary in plans:
		var raised: TileMapLayer = plan.raised
		if plan.has_front:
			raised.tile_set = tileset
			base.set_cell(plan.cell, source_id, plan.back_coords)
			raised.set_cell(plan.cell, source_id, plan.front_coords)
		else:
			base.set_cell(plan.cell, plan.source, plan.coords, plan.alternative)
			raised.erase_cell(plan.cell)


static func _collect_layers(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is CanvasItem and not node.visible:
		return
	if node is TileMapLayer:
		layers.append(node)
	for child: Node in node.get_children():
		_collect_layers(child, layers)


static func _comes_after(a: TileMapLayer, b: TileMapLayer, order: Array[TileMapLayer]) -> bool:
	var az := _effective_z(a)
	var bz := _effective_z(b)
	return az > bz if az != bz else order.find(a) > order.find(b)


static func _effective_z(item: CanvasItem) -> int:
	var z := item.z_index
	if item.z_as_relative and item.get_parent() is CanvasItem:
		z += _effective_z(item.get_parent())
	return clampi(z, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)


static func _tile_frames(layer: TileMapLayer, cell: Vector2i, images: Dictionary, tiles: Dictionary) -> Array[Image]:
	var source := layer.get_cell_source_id(cell)
	if source < 0 or layer.tile_set == null:
		return []
	var atlas := layer.tile_set.get_source(source) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return []
	var coords := layer.get_cell_atlas_coords(cell)
	var alternative := layer.get_cell_alternative_tile(cell)
	var key := "%d:%s:%d" % [atlas.get_instance_id(), coords, alternative]
	if tiles.has(key):
		return tiles[key]
	var frames: Array[Image] = []
	var texture_id := atlas.texture.get_instance_id()
	if not images.has(texture_id):
		var image := atlas.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		images[texture_id] = image
	for frame in range(atlas.get_tile_animation_frames_count(coords)):
		var region := atlas.get_tile_texture_region(coords, frame)
		if region.size != Vector2i(32, 32):
			return []
		var pixels: Image = images[texture_id].get_region(region)
		if alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
			pixels.rotate_90(CLOCKWISE)
			pixels.flip_x()
		if alternative & TileSetAtlasSource.TRANSFORM_FLIP_H:
			pixels.flip_x()
		if alternative & TileSetAtlasSource.TRANSFORM_FLIP_V:
			pixels.flip_y()
		frames.append(pixels)
	tiles[key] = frames
	return frames
