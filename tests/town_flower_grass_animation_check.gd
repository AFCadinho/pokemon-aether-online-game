extends SceneTree

const REPORT := "res://tools/town_flower_grass_reimport_report.json"
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures: Array[String] = []


func _init() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var expected_cells := {"pallet_town": 39, "viridian_city": 178, "cerulean_city": 34, "vermilion_city": 16}
	var checked_frames := 0
	var checked_cells := 0
	for id: String in expected_cells:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var visual := (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		var record: Dictionary = report.maps[id]
		var actual := Fingerprint.new().capture(visual)
		for key in ["fingerprint", "cells", "layers", "usedTiles"]:
			_check(actual[key] == record.after[key], id + " imported layout changed: " + key)
		failures.append_array(Validator.new().validate(visual, path.trim_suffix(".tscn") + ".tileset.tres"))
		var layers: Array[TileMapLayer] = []
		Compactor.new()._collect(visual, layers)
		var tiles := layers[0].tile_set
		var counts := {}
		var hashes := {}
		for index in tiles.get_source_count():
			var source_id := tiles.get_source_id(index)
			var source := tiles.get_source(source_id) as TileSetAtlasSource
			var image := source.texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			for tile in source.get_tiles_count():
				var coords := source.get_tile_id(tile)
				var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
				if not record.animation_overrides.has(hash):
					continue
				hashes[str(source_id) + str(coords)] = hash
				var expected: Dictionary = record.animation_overrides[hash]
				var frames := source.get_tile_animation_frames_count(coords)
				_check(frames == 48 and expected.frame_hashes.size() == 48, id + " requires 48 authored frames")
				_check(is_equal_approx(source.get_tile_animation_speed(coords), 1.0), id + " native animation speed changed")
				for frame in mini(frames, expected.frame_hashes.size()):
					var pixels := image.get_region(source.get_tile_texture_region(coords, frame)).get_data()
					_check(Fingerprint.new()._hash(pixels) == expected.frame_hashes[frame], id + " authored frame artwork changed")
					_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.07), id + " authored 70ms timing changed")
					checked_frames += 1
		for layer in layers:
			for cell in layer.get_used_cells():
				var key := str(layer.get_cell_source_id(cell)) + str(layer.get_cell_atlas_coords(cell))
				if hashes.has(key):
					var hash: String = hashes[key]
					counts[hash] = int(counts.get(hash, 0)) + 1
		var map_cells := 0
		for hash: String in record.new_animation_cells:
			_check(int(counts.get(hash, 0)) == int(record.new_animation_cells[hash]), id + " authored flower/grass placement changed")
			map_cells += int(counts.get(hash, 0))
		_check(map_cells == int(expected_cells[id]), id + " flower/grass count changed")
		checked_cells += map_cells
		visual.free()
	for failure in failures:
		push_error(failure)
	print("TOWN_FLOWER_GRASS_CHECK ", JSON.stringify({"maps": 4, "frames": checked_frames, "cells": checked_cells, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
