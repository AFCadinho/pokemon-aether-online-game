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
	var splits := {}
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
			if tree.is_empty():
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
			var atlas := raised.tile_set.get_source(raised.get_cell_source_id(cell)) as TileSetAtlasSource
			var coords := raised.get_cell_atlas_coords(cell)
			var key := "%d:%s:%d:%s" % [atlas.get_instance_id(), coords, raised.get_cell_alternative_tile(cell), covered.hex_encode()]
			if not splits.has(key):
				splits[key] = _split_frames(tree, covered, atlas, coords)
			var split: Dictionary = splits[key]
			if not split.has_back:
				continue
			if not plans.has(base):
				plans[base] = []
			plans[base].append({
				"raised": raised, "cell": cell, "split": split, "key": key,
				"source": raised.get_cell_source_id(cell), "coords": coords,
				"alternative": raised.get_cell_alternative_tile(cell),
			})
			adjusted += 1
	# Collect coverage before mutating any layer; results cannot depend on which
	# tree family/layer happens to be visited first.
	for base: TileMapLayer in plans:
		_apply_splits(base, plans[base])
	return adjusted


static func _split_frames(frames: Array[Image], covered: PackedByteArray, atlas: TileSetAtlasSource, coords: Vector2i) -> Dictionary:
	var result := {"front": [], "back": [], "has_front": false, "has_back": false,
		"speed": atlas.get_tile_animation_speed(coords),
		"mode": atlas.get_tile_animation_mode(coords), "durations": []}
	for index in range(frames.size()):
		var front := frames[index].get_data()
		var back := front.duplicate()
		for pixel in range(covered.size()):
			if covered[pixel] != 0:
				result.has_back = result.has_back or front[pixel * 4 + 3] > 0
				front[pixel * 4 + 3] = 0
			else:
				result.has_front = result.has_front or front[pixel * 4 + 3] > 0
				back[pixel * 4 + 3] = 0
		result.front.append(Image.create_from_data(32, 32, false, Image.FORMAT_RGBA8, front))
		result.back.append(Image.create_from_data(32, 32, false, Image.FORMAT_RGBA8, back))
		result.durations.append(atlas.get_tile_animation_frame_duration(coords, index))
	return result


static func _apply_splits(base: TileMapLayer, plans: Array) -> void:
	var unique := {}
	for plan: Dictionary in plans:
		if plan.split.has_front:
			unique[plan.key] = plan.split
	var tileset: TileSet = base.tile_set
	var locations := {}
	if not unique.is_empty():
		# Repeated trees with the same coverage share their entire animation.
		# Chunk the atlas so native 48-frame foliage never exceeds 4096px.
		tileset = base.tile_set.duplicate(false) as TileSet
		var batch := {}
		var rows := 0
		for key: String in unique:
			var split: Dictionary = unique[key]
			var height := ceili(float(split.front.size()) / 16) * 2
			if rows + height > 128 and not batch.is_empty():
				locations.merge(_build_atlas(tileset, batch))
				batch.clear()
				rows = 0
			batch[key] = split
			rows += height
		if not batch.is_empty():
			locations.merge(_build_atlas(tileset, batch))
		base.tile_set = tileset
	for plan: Dictionary in plans:
		var raised: TileMapLayer = plan.raised
		if plan.split.has_front:
			var location: Dictionary = locations[plan.key]
			raised.tile_set = tileset
			base.set_cell(plan.cell, location.source, location.back)
			raised.set_cell(plan.cell, location.source, location.front)
		else:
			base.set_cell(plan.cell, plan.source, plan.coords, plan.alternative)
			raised.erase_cell(plan.cell)


static func _build_atlas(tileset: TileSet, batch: Dictionary) -> Dictionary:
	var columns := 1
	for split: Dictionary in batch.values():
		columns = maxi(columns, mini(16, split.front.size()))
	var rows := 0
	for split: Dictionary in batch.values():
		rows += ceili(float(split.front.size()) / columns) * 2
	var pixels := Image.create(columns * 32, rows * 32, false, Image.FORMAT_RGBA8)
	var locations := {}
	var row := 0
	for key: String in batch:
		var split: Dictionary = batch[key]
		locations[key] = {}
		for side: String in ["back", "front"]:
			locations[key][side] = Vector2i(0, row)
			for frame in range(split[side].size()):
				var cell := Vector2i(frame % columns, row + frame / columns)
				pixels.blit_rect(split[side][frame], Rect2i(0, 0, 32, 32), cell * 32)
			row += ceili(float(split[side].size()) / columns)
	var atlas := TileSetAtlasSource.new()
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.texture = ImageTexture.create_from_image(pixels)
	for key: String in batch:
		var split: Dictionary = batch[key]
		for side: String in ["back", "front"]:
			var coords: Vector2i = locations[key][side]
			atlas.create_tile(coords)
			atlas.set_tile_animation_columns(coords, columns)
			atlas.set_tile_animation_frames_count(coords, split[side].size())
			atlas.set_tile_animation_speed(coords, split.speed)
			atlas.set_tile_animation_mode(coords, split.mode)
			for frame in range(split.durations.size()):
				atlas.set_tile_animation_frame_duration(coords, frame, split.durations[frame])
	var source := tileset.add_source(atlas)
	for location: Dictionary in locations.values():
		location.source = source
	return locations


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
