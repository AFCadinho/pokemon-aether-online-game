# Pallet-only prototype; deliberately NOT part of the TMX importer.
extends SceneTree

const INPUT := "res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn"
const OUTPUT := "res://generated/tiled_visuals/pallet_town_compact"
const COLUMNS := 7
const SLOT := 36

func _init() -> void:
	if "--build" not in OS.get_cmdline_user_args():
		push_error("Pallet-only prototype generation requires explicit --build")
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load(INPUT)
	var root := packed.instantiate()
	var layers: Array = []
	_collect(root, layers)
	var original: TileSet = layers[0].tile_set
	assert(original.get_physics_layers_count() == 0 and original.get_navigation_layers_count() == 0)
	assert(original.get_terrain_sets_count() == 0 and original.get_custom_data_layers_count() == 0)
	var used := {}
	for layer: TileMapLayer in layers:
		assert(layer.tile_set == original)
		for cell: Vector2i in layer.get_used_cells():
			var id := layer.get_cell_source_id(cell)
			if not used.has(id):
				used[id] = {}
			used[id][layer.get_cell_atlas_coords(cell)] = true
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "/assets")) == OK)
	var compact := TileSet.new()
	compact.tile_size = original.tile_size
	for key in original.get_meta_list():
		# The old importer reuse signature must not describe a new atlas layout.
		if key != &"tiled_source_signature":
			compact.set_meta(key, original.get_meta(key))
	compact.set_meta("pallet_compact_prototype", true)
	var mappings := {}
	var bytes := 0
	for index in original.get_source_count():
		var id := original.get_source_id(index)
		if not used.has(id):
			continue
		var old := original.get_source(id) as TileSetAtlasSource
		assert(old != null and old.texture_region_size == Vector2i(32, 32))
		var coords: Array = used[id].keys()
		coords.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
		var image := Image.create(256, ceili(float(coords.size()) / COLUMNS) * SLOT, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var pixels := old.texture.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var source := TileSetAtlasSource.new()
		source.texture_region_size = Vector2i(32, 32)
		source.margins = Vector2i(2, 2)
		source.separation = Vector2i(4, 4)
		# Tile creation validates coordinates against the texture dimensions.
		source.texture = ImageTexture.create_from_image(image)
		mappings[id] = {}
		for tile_index in coords.size():
			var old_coords: Vector2i = coords[tile_index]
			assert(old.get_tile_animation_frames_count(old_coords) == 1)
			assert(old.get_alternative_tiles_count(old_coords) == 1)
			var region := old.get_tile_texture_region(old_coords)
			assert(region.size == Vector2i(32, 32))
			var new_coords := Vector2i(tile_index % COLUMNS, tile_index / COLUMNS)
			image.blit_rect(pixels, region, new_coords * SLOT + Vector2i(2, 2))
			source.create_tile(new_coords)
			# Preserve TileData properties, including texture/depth origins.
			var old_data := old.get_tile_data(old_coords, 0)
			var new_data := source.get_tile_data(new_coords, 0)
			assert(new_data != null)
			for property in old_data.get_property_list():
				var name: String = property.name
				if int(property.usage) & PROPERTY_USAGE_STORAGE and name != "script":
					new_data.set(name, old_data.get(name))
			mappings[id][old_coords] = new_coords
		var texture := PortableCompressedTexture2D.new()
		texture.keep_compressed_buffer = true
		texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		assert(ResourceSaver.save(texture, OUTPUT + "/assets/source_%d.texture.res" % id) == OK)
		source.texture = texture
		compact.add_source(source, id)
		bytes += image.get_width() * image.get_height() * 4
	assert(ResourceSaver.save(compact, OUTPUT + "/pallet_town_compact.visual.tileset.tres") == OK)
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			var id := layer.get_cell_source_id(cell)
			var new_coords: Vector2i = mappings[id][layer.get_cell_atlas_coords(cell)]
			layer.set_cell(cell, id, new_coords, layer.get_cell_alternative_tile(cell))
		layer.tile_set = compact
	var result := PackedScene.new()
	assert(result.pack(root) == OK)
	assert(ResourceSaver.save(result, OUTPUT + "/pallet_town_compact.visual.tscn") == OK)
	root.free()
	print("PALLET_COMPACT_BUILD ", JSON.stringify({"sources": compact.get_source_count(), "baseRGBABytes": bytes,
		"lossless": true, "importerChanged": false}))
	quit(0)

func _collect(node: Node, layers: Array) -> void:
	if node is TileMapLayer:
		layers.append(node)
	for child: Node in node.get_children():
		_collect(child, layers)
