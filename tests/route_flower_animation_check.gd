extends SceneTree

const REPORT := "res://tools/route_flower_rollout_report.json"
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const Recovery := preload("res://tools/vermilion_water_animation.gd")
var failures: Array[String] = []


func _init() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var total_cells := 0
	var total_frames := 0
	var flower_maps := 0
	_check(report.maps.size() == 22, "Expected 20 active route/forest sources and two Saffron connections")
	for id: String in report.maps:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var visual := (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		var record: Dictionary = report.maps[id]
		var actual := Fingerprint.new().capture(visual)
		for key in ["fingerprint", "cells", "layers", "usedTiles"]:
			_check(actual[key] == record.before[key], id + " original artwork/layout/TileData changed: " + key)
		_check(actual.baseRGBABytes == record.after.baseRGBABytes, id + " measured atlas memory budget changed")
		failures.append_array(Validator.new().validate(visual, path.trim_suffix(".tscn") + ".tileset.tres"))
		var signatures := Recovery._animation_signatures(visual)
		for hash: String in record.preserved_animations:
			_check(_same_timeline(signatures.get(hash, []), record.preserved_animations[hash]), id + " existing non-flower animation changed")
		var layers: Array[TileMapLayer] = []
		Compactor.new()._collect(visual, layers)
		var tiles := layers[0].tile_set
		var hashes := {}
		var counts := {}
		for index in tiles.get_source_count():
			var source_id := tiles.get_source_id(index)
			var source := tiles.get_source(source_id) as TileSetAtlasSource
			var image := source.texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			for tile in source.get_tiles_count():
				var coords := source.get_tile_id(tile)
				var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
				if not report.catalog.has(hash):
					continue
				hashes[str(source_id) + str(coords)] = hash
				var expected: Dictionary = report.catalog[hash]
				var frames := source.get_tile_animation_frames_count(coords)
				_check(frames == 48 and expected.frame_hashes.size() == 48, id + " flower frame count differs from Lavender")
				_check(is_equal_approx(source.get_tile_animation_speed(coords), 1.0), id + " native flower speed changed")
				for frame in mini(frames, 48):
					var pixels := image.get_region(source.get_tile_texture_region(coords, frame)).get_data()
					_check(Fingerprint.new()._hash(pixels) == expected.frame_hashes[frame], id + " flower artwork differs from the towns")
					_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.07), id + " flower timing differs from the towns")
					total_frames += 1
		for layer in layers:
			for cell in layer.get_used_cells():
				var key := str(layer.get_cell_source_id(cell)) + str(layer.get_cell_atlas_coords(cell))
				if hashes.has(key):
					var hash: String = hashes[key]
					counts[hash] = int(counts.get(hash, 0)) + 1
		_check(counts.size() == record.flower_cells.size(), id + " flower variants changed")
		for hash: String in record.flower_cells:
			_check(int(counts.get(hash, -1)) == int(record.flower_cells[hash]), id + " original flower placement changed")
			total_cells += int(counts.get(hash, 0))
		if not counts.is_empty():
			flower_maps += 1
		visual.free()
	_check(total_cells == 828 and flower_maps == 20, "Expected all 828 flowers in 20 active route/forest visuals")
	for failure in failures:
		push_error(failure)
	print("ROUTE_FLOWER_CHECK ", JSON.stringify({"reviewed": report.maps.size(), "flower_maps": flower_maps,
		"cells": total_cells, "frames": total_frames, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _same_timeline(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for frame in actual.size():
		if actual[frame].hash != expected[frame].hash or not is_equal_approx(actual[frame].duration, expected[frame].duration) or not is_equal_approx(actual[frame].speed, expected[frame].speed):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
