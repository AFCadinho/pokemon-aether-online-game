# Compare the final jail repartition with a checkout containing the old visual.
# Reads the reference checkout; temporary resource wrappers live only in user://.
extends SceneTree
const Frames := preload("res://scripts/world/tree_scenery_occlusion.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const REL := "generated/tiled_visuals/viridian_city/viridian_city.visual"
var cells := 0
var frame_count := 0
var signatures := {}
var images := {}
var tiles := {}

func _init() -> void:
	if OS.get_cmdline_user_args().size() != 1:
		push_error("Usage: -- <previous frontend checkout>")
		quit(2)
		return
	var previous := OS.get_cmdline_user_args()[0]
	var old_tileset := FileAccess.get_file_as_string(previous + "/" + REL + ".tileset.tres").replace("res://", previous + "/")
	var ts_file := FileAccess.open("user://jail-baseline.tileset.tres", FileAccess.WRITE)
	ts_file.store_string(old_tileset)
	ts_file.close()
	var old_scene := FileAccess.get_file_as_string(previous + "/" + REL + ".tscn").replace("res://" + REL + ".tileset.tres", "user://jail-baseline.tileset.tres")
	var scene_file := FileAccess.open("user://jail-baseline.tscn", FileAccess.WRITE)
	scene_file.store_string(old_scene)
	scene_file.close()
	var old: Node = load("user://jail-baseline.tscn").instantiate()
	var current: Node = load("res://" + REL + ".tscn").instantiate()
	var before := _fingerprints(old)
	var after := _fingerprints(current)
	var errors: Array = Validator.new().validate(current, "res://" + REL + ".tileset.tres")
	for error in errors: push_error(error)
	var matches := before == after
	if not matches:
		var changed := 0
		for cell in before:
			if before[cell] != after.get(cell):
				changed += 1
				if changed <= 3: print("PIXEL_DIFF ", cell)
		print("DIFFERENT_CELLS ", changed)
		push_error("Imported visual tile pixels or animation timelines changed")
	for layer: TileMapLayer in current.get_children():
		for id in layer.tile_set.get_source_count():
			var atlas := layer.tile_set.get_source(layer.tile_set.get_source_id(id)) as TileSetAtlasSource
			if not atlas.texture is PortableCompressedTexture2D or atlas.texture.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS:
				errors.append("Texture storage contract failed")
	print("JAIL_IMPORT_AUDIT visual_cells_per_version=%d unique_frame_comparisons=%d pixels_and_timelines_equal=%s compact_and_lossless=%s" % [cells / 2, frame_count / 2, matches, errors.is_empty()])
	old.free()
	current.free()
	quit(0 if matches and errors.is_empty() else 1)

func _fingerprints(visual: Node) -> Dictionary:
	var result := {}
	for layer: TileMapLayer in visual.get_children():
		for cell: Vector2i in layer.get_used_cells():
			cells += 1
			var atlas := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var key := "%d:%s:%d" % [atlas.get_instance_id(), coords, layer.get_cell_alternative_tile(cell)]
			if not signatures.has(key):
				var frames := Frames._tile_frames(layer, cell, images, tiles)
				var hashes := []
				for index in frames.size():
					frame_count += 1
					var hash := HashingContext.new()
					hash.start(HashingContext.HASH_SHA256)
					hash.update(frames[index].get_data())
					hashes.append([hash.finish().hex_encode(), atlas.get_tile_animation_frame_duration(coords, index)])
				signatures[key] = JSON.stringify([atlas.get_tile_animation_speed(coords), atlas.get_tile_animation_mode(coords), hashes])
			if not result.has(cell): result[cell] = []
			result[cell].append(signatures[key])
	for cell in result: result[cell].sort()
	return result
