extends SceneTree

const Occlusion := preload("res://scripts/world/tree_scenery_occlusion.gd")
const Trees := preload("res://scripts/world/tree_lower_depth_sorting.gd")
var failed := false
var images := {}
var tiles := {}
var compared := 0
var animation_frames_compared := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_split_and_animation()
	var world: Node = load("res://scripts/world/world.gd").new()
	var count := 0
	for id: String in DirAccess.get_directories_at("res://generated/tiled_visuals"):
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var map: Node = load(path).instantiate()
		# These maps opt into individual crown sorting in their gameplay scenes.
		if id in ["route_16", "route_16_east", "route_17", "route_18"]:
			var metadata := GDScript.new()
			metadata.source_code = "extends Node2D\nvar individual_tree_depth_sorting = true\n"
			metadata.reload()
			map.set_script(metadata)
		root.add_child(map)
		_check_map(world, map, id)
		map.free()
		count += 1
	# Confirm the reported locations with their actual gameplay scene overrides.
	var viridian_city := load("res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn").instantiate() as Node
	root.add_child(viridian_city)
	_check_map(world, viridian_city, "viridian_city gameplay")
	viridian_city.free()
	var kanto_route_2 := load("res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn").instantiate() as Node
	root.add_child(kanto_route_2)
	_check_map(world, kanto_route_2, "kanto_route_2 gameplay")
	kanto_route_2.free()
	world.free()
	print("Tree scenery occlusion: %s; %d visual maps, %d tree cells compared" % ["FAIL" if failed else "PASS", count, compared])
	print("Animated split frame comparisons: ", animation_frames_compared)
	quit(1 if failed else 0)


func _check_map(world: Node, map: Node, id: String) -> void:
	images.clear()
	tiles.clear()
	var before_layers: Array[TileMapLayer] = []
	Occlusion._collect_layers(map, before_layers)
	var originals := {}
	var cells := {}
	for layer: TileMapLayer in before_layers:
		if not Trees.BOTTOM_LAYER_NAMES.has(str(layer.name)):
			continue
		originals[layer] = layer.duplicate(0)
		for cell: Vector2i in layer.get_used_cells():
			var frames := Occlusion._tile_frames(layer, cell, images, tiles)
			if frames.is_empty():
				continue
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(frames[0].get_data())
			if Trees.EVERGREEN_PARTS.values().has(hash.finish().hex_encode()):
				cells[cell] = maxi(cells.get(cell, 1), frames.size())
	world.call("_normalize_map_depth_layer_z_indices", map)
	var after: Array[TileMapLayer] = []
	Occlusion._collect_layers(map, after)
	var baseline: Array[TileMapLayer] = []
	for layer: TileMapLayer in after:
		if not layer.get_meta(Occlusion.TREE_META, false):
			baseline.append(originals.get(layer, layer))
	_sort_layers(baseline)
	_sort_layers(after)
	var animated_splits := {}
	for base: TileMapLayer in originals:
		var original: TileMapLayer = originals[base]
		for cell: Vector2i in cells:
			if cells[cell] <= 1 or base.get_cell_source_id(cell) < 0 or original.get_cell_source_id(cell) < 0:
				continue
			var source := base.tile_set.get_source(base.get_cell_source_id(cell)) as TileSetAtlasSource
			var old_source := original.tile_set.get_source(original.get_cell_source_id(cell)) as TileSetAtlasSource
			if old_source.get_tile_animation_frames_count(original.get_cell_atlas_coords(cell)) > 1 and (base.get_cell_source_id(cell) != original.get_cell_source_id(cell) or base.get_cell_atlas_coords(cell) != original.get_cell_atlas_coords(cell)):
				animated_splits[cell] = true
				_check_timeline(source, base.get_cell_atlas_coords(cell), old_source, original.get_cell_atlas_coords(cell), id)
				for raised: TileMapLayer in after:
					if raised.get_meta(Occlusion.TREE_META, false) and raised.get_cell_source_id(cell) >= 0 and raised.get_node_or_null(raised.get_meta(Occlusion.SOURCE_META, NodePath())) == base:
						_check_timeline(raised.tile_set.get_source(raised.get_cell_source_id(cell)), raised.get_cell_atlas_coords(cell), old_source, original.get_cell_atlas_coords(cell), id)
	var changes := 0
	for cell: Vector2i in cells:
		var expected := _compose(baseline, cell)
		var actual := _compose(after, cell)
		if expected.get_data() != actual.get_data():
			changes += 1
			if changes <= 3:
				push_error("%s changed scenery at %s" % [id, cell])
		if animated_splits.has(cell):
			for frame in range(1, cells[cell]):
				_check(_compose(baseline, cell, frame).get_data() == _compose(after, cell, frame).get_data(), "%s animated foliage at %s frame %d" % [id, cell, frame])
				animation_frames_compared += 1
		compared += 1
	_check(changes == 0, "%s preserves scenery at every evergreen cell (%d differences)" % [id, changes])
	var snapshot := _snapshot(map)
	world.call("_normalize_map_depth_layer_z_indices", map)
	_check(_snapshot(map) == snapshot, id + " repeat normalization is idempotent")
	for copy: TileMapLayer in originals.values():
		copy.free()


func _check_split_and_animation() -> void:
	var map := Node2D.new()
	map.position = Vector2(71, 93)
	map.scale = Vector2(1.5, 1.5)
	root.add_child(map)
	var pixels := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	pixels.fill_rect(Rect2i(0, 0, 32, 32), Color(0, 0.7, 0, 0.8))
	pixels.fill_rect(Rect2i(32, 0, 12, 32), Color(0.8, 0, 0, 0.5))
	pixels.fill_rect(Rect2i(48, 0, 8, 32), Color(0, 0, 0.9, 1))
	pixels.fill_rect(Rect2i(64, 0, 16, 32), Color(0.9, 0.9, 0, 1))
	var atlas := TileSetAtlasSource.new()
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.texture = ImageTexture.create_from_image(pixels)
	atlas.create_tile(Vector2i.ZERO)
	atlas.create_tile(Vector2i(1, 0))
	atlas.set_tile_animation_columns(Vector2i(1, 0), 2)
	atlas.set_tile_animation_frames_count(Vector2i(1, 0), 2)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	var tree_pixels := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	tree_pixels.blit_rect(pixels, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	tree_pixels.fill_rect(Rect2i(32, 0, 32, 16), Color(0.1, 0.3, 0.9, 0.4))
	var tree_atlas := TileSetAtlasSource.new()
	tree_atlas.texture_region_size = Vector2i(32, 32)
	tree_atlas.texture = ImageTexture.create_from_image(tree_pixels)
	tree_atlas.create_tile(Vector2i.ZERO)
	tree_atlas.set_tile_animation_columns(Vector2i.ZERO, 2)
	tree_atlas.set_tile_animation_frames_count(Vector2i.ZERO, 2)
	tree_atlas.set_tile_animation_speed(Vector2i.ZERO, 1.7)
	tree_atlas.set_tile_animation_frame_duration(Vector2i.ZERO, 0, 0.11)
	tree_atlas.set_tile_animation_frame_duration(Vector2i.ZERO, 1, 0.23)
	tileset.add_source(tree_atlas, 1)
	var base := TileMapLayer.new()
	base.name = "TreeBottom"
	base.z_index = 2
	base.tile_set = tileset
	map.add_child(base)
	var foreground := TileMapLayer.new()
	foreground.z_index = 3
	foreground.tile_set = tileset
	foreground.set_cell(Vector2i.ZERO, 0, Vector2i(1, 0), TileSetAtlasSource.TRANSFORM_FLIP_H)
	map.add_child(foreground)
	var raised := TileMapLayer.new()
	raised.z_as_relative = false
	raised.z_index = 100
	raised.tile_set = tileset
	raised.set_cell(Vector2i.ZERO, 1, Vector2i.ZERO)
	raised.set_cell(Vector2i(2, 0), 1, Vector2i.ZERO)
	raised.set_cell(Vector2i(4, 0), 1, Vector2i.ZERO)
	foreground.set_cell(Vector2i(4, 0), 0, Vector2i(1, 0), TileSetAtlasSource.TRANSFORM_FLIP_H)
	raised.set_meta(Occlusion.TREE_META, true)
	map.add_child(raised)
	raised.set_meta(Occlusion.SOURCE_META, raised.get_path_to(base))
	_check(Occlusion.preserve_scenery(map) == 2, "only the two overlapped animated cells are split")
	_check(tileset.get_source_count() == 2 and foreground.tile_set == tileset, "shared/animated scenery resources remain unchanged")
	_check(base.tile_set == raised.tile_set and base.tile_set != tileset, "split pieces share one local atlas")
	_check(raised.get_cell_source_id(Vector2i(2, 0)) == 1, "unobstructed tree art keeps its original source and depth")
	_check(base.get_cell_atlas_coords(Vector2i.ZERO) == base.get_cell_atlas_coords(Vector2i(4, 0)) and raised.get_cell_atlas_coords(Vector2i.ZERO) == raised.get_cell_atlas_coords(Vector2i(4, 0)), "identical animated masks share their runtime atlas cells")
	var low_frames := Occlusion._tile_frames(base, Vector2i.ZERO, images, tiles)
	var high_frames := Occlusion._tile_frames(raised, Vector2i.ZERO, images, tiles)
	_check_timeline(base.tile_set.get_source(base.get_cell_source_id(Vector2i.ZERO)), base.get_cell_atlas_coords(Vector2i.ZERO), tree_atlas, Vector2i.ZERO, "synthetic base")
	_check_timeline(raised.tile_set.get_source(raised.get_cell_source_id(Vector2i.ZERO)), raised.get_cell_atlas_coords(Vector2i.ZERO), tree_atlas, Vector2i.ZERO, "synthetic front")
	for tree_frame in range(2):
		var tree := tree_pixels.get_region(Rect2i(tree_frame * 32, 0, 32, 32))
		for frame_index in range(2):
			var frame := pixels.get_region(Rect2i(32 + frame_index * 32, 0, 32, 32))
			frame.flip_x()
			var expected := tree.duplicate() as Image
			expected.blend_rect(frame, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
			var actual := low_frames[tree_frame].duplicate() as Image
			actual.blend_rect(frame, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
			actual.blend_rect(high_frames[tree_frame], Rect2i(0, 0, 32, 32), Vector2i.ZERO)
			_check(expected.get_data() == actual.get_data(), "animated tree and transparent/flipped foreground preserve every frame combination")
	var low: Image = low_frames[0]
	var high: Image = high_frames[0]
	# Uncovered pixels still occlude an actor between the original base and
	# crown depth; covered pixels remain behind the scenery at the old depth.
	_check(high.get_pixel(0, 0).a > 0 and low.get_pixel(0, 0).a == 0, "visible tree pixels retain mount occlusion without double blending")
	_check(high.get_pixel(31, 0).a == 0 and low.get_pixel(31, 0).a > 0, "foreground-covered pixels retain authored depth")
	_check(Occlusion.preserve_scenery(map) == 0, "reapplying the split is a no-op")
	map.free()
	images.clear()
	tiles.clear()


func _sort_layers(layers: Array[TileMapLayer]) -> void:
	var original_order := layers.duplicate()
	layers.sort_custom(func(a: TileMapLayer, b: TileMapLayer) -> bool:
		return a.z_index < b.z_index if a.z_index != b.z_index else original_order.find(a) < original_order.find(b))


func _compose(layers: Array[TileMapLayer], cell: Vector2i, frame: int = 0) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for layer: TileMapLayer in layers:
		var frames := Occlusion._tile_frames(layer, cell, images, tiles)
		if not frames.is_empty():
			image.blend_rect(frames[frame % frames.size()], Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	return image


func _snapshot(map: Node) -> Array:
	var layers: Array[TileMapLayer] = []
	Occlusion._collect_layers(map, layers)
	var snapshot := []
	for layer: TileMapLayer in layers:
		var cells := []
		for cell: Vector2i in layer.get_used_cells():
			cells.append([cell, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)])
		snapshot.append([layer.get_instance_id(), layer.tile_set.get_instance_id(), layer.z_index, cells])
	return snapshot


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _check_timeline(actual: TileSetAtlasSource, coords: Vector2i, original: TileSetAtlasSource, original_coords: Vector2i, context: String) -> void:
	var count := original.get_tile_animation_frames_count(original_coords)
	_check(actual.get_tile_animation_frames_count(coords) == count, context + " preserves foliage frame count")
	_check(actual.get_tile_animation_speed(coords) == original.get_tile_animation_speed(original_coords), context + " preserves foliage speed")
	_check(actual.get_tile_animation_mode(coords) == original.get_tile_animation_mode(original_coords), context + " preserves native animation mode")
	for frame in range(count):
		_check(actual.get_tile_animation_frame_duration(coords, frame) == original.get_tile_animation_frame_duration(original_coords, frame), context + " preserves foliage frame duration")
