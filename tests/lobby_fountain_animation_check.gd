extends SceneTree

const PATH := "res://generated/tiled_visuals/lobby/lobby.visual.tscn"
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const Recovery := preload("res://tools/vermilion_water_animation.gd")
var failures: Array[String] = []
var frame_images := {}


func _init() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/lobby_fountain_rollout_report.json"))
	var visual := (ResourceLoader.load(PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	var actual := Fingerprint.new().capture(visual)
	for key in report.after:
		_check(actual[key] == report.after[key], "Measured fountain visual/budget differs: " + key)
	failures.append_array(Validator.new().validate(visual, PATH.trim_suffix(".tscn") + ".tileset.tres"))
	var water := visual.get_node("FountainWater") as TileMapLayer
	_check(water.z_index == 2052 and water.get_used_cells().size() == 32, "Expected both mouth jets above the statue overlay")
	var timelines := Recovery._animation_signatures(visual)
	for hash: String in report.preserved_animations:
		var expected: Array = report.preserved_animations[hash]
		var frames: Array = timelines.get(hash, [])
		_check(frames.size() == expected.size(), "Existing animation frame count changed")
		for f in mini(frames.size(), expected.size()):
			_check(frames[f].hash == expected[f].hash and is_equal_approx(frames[f].duration, expected[f].duration) and is_equal_approx(frames[f].speed, expected[f].speed), "Existing water/flower/canopy animation changed")
	var checked := 0
	for cell: Dictionary in report.cells:
		var pos := Vector2i(int(cell.x), int(cell.y))
		_check(water.get_cell_source_id(pos) >= 0 and water.get_cell_alternative_tile(pos) == 0, "Authored water placement/transform changed")
		var source := water.tile_set.get_source(water.get_cell_source_id(pos)) as TileSetAtlasSource
		var coords := water.get_cell_atlas_coords(pos)
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var entry: Dictionary = report.catalog[cell.hash]
		_check(source.get_tile_animation_frames_count(coords) == 24 and is_equal_approx(source.get_tile_animation_speed(coords), 1.0), "Native fountain timeline changed")
		for f in mini(24, source.get_tile_animation_frames_count(coords)):
			_check(Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, f)).get_data()) == entry.frame_hashes[f], "Native TMX fountain frame differs")
			_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, f), 0.08), "Native TMX fountain timing differs")
			checked += 1
	# Follow one droplet downward on both fountains, instead of merely checking
	# that the frame hashes change. The streams must move toward the basin.
	for origin: Vector2i in [Vector2i(14, 29), Vector2i(42, 29)]:
		var start := origin * 32 + Vector2i(80, 61)
		var down := start + Vector2i(0, 2)
		var highlight := Color8(208, 248, 248, 255)
		_check(_pixel(water, origin * 32 + Vector2i(80, 49), 0).is_equal_approx(highlight), "Water does not originate in the statue mouth")
		_check(_pixel(water, start, 0).is_equal_approx(highlight), "Missing falling-water highlight")
		_check(_pixel(water, down, 1).is_equal_approx(highlight) and not _pixel(water, start, 1).is_equal_approx(highlight), "Water does not move downward")
		# Sample a three-pixel core along the analytic curves in every native
		# frame. This catches skipped raster rows and gaps at tile boundaries.
		for frame in 24:
			for y in range(49, 144):
				for side in [-1, 1]:
					var x := roundi(80 + side * 37 * sqrt((y - 49) / 94.0))
					for dx in [-1, 0, 1]:
						_check(_pixel(water, origin * 32 + Vector2i(x + dx, y), frame).a > 0.99, "Side jet interrupted at row %d / frame %d" % [y, frame])
			for y in range(49, 156):
				for dx in [-1, 0, 1]:
					_check(_pixel(water, origin * 32 + Vector2i(80 + dx, y), frame).a > 0.99, "Central waterfall interrupted at row %d / frame %d" % [y, frame])
	water.owner = null
	visual.remove_child(water)
	var original := Fingerprint.new().capture(visual)
	for key in ["fingerprint", "cells", "layers", "usedTiles"]:
		_check(original[key] == report.before[key], "Original lobby sprites/geometry/TileData changed: " + key)
	water.free()
	visual.free()
	for failure in failures:
		push_error(failure)
	print("LOBBY_FOUNTAIN_CHECK ", JSON.stringify({"fountains": 2, "cells": 32, "frame_samples": checked, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _pixel(layer: TileMapLayer, pixel: Vector2i, frame: int) -> Color:
	var cell := Vector2i(floori(pixel.x / 32.0), floori(pixel.y / 32.0))
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var coords := layer.get_cell_atlas_coords(cell)
	var key := "%d/%s/%d" % [source.get_instance_id(), coords, frame]
	if not frame_images.has(key):
		frame_images[key] = source.texture.get_image().get_region(source.get_tile_texture_region(coords, frame))
	return (frame_images[key] as Image).get_pixel(pixel.x % 32, pixel.y % 32)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
