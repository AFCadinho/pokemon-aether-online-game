extends SceneTree

const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures: Array[String] = []

func _init() -> void:
	var catalog := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_animation_assets/catalog.json"))
	for entry: Dictionary in data.tiles:
		catalog[entry.source_pixel_sha256] = entry
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_animation_rollout_report.json"))
	var frame_count := 0
	var cell_count := 0
	for id in report.maps:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id,id]
		var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null:
			failures.append("Missing scene: " + id)
			continue
		var root := scene.instantiate()
		var actual := Fingerprint.new().capture(root)
		var previous: Dictionary = report.maps[id].get("current_static_reference", report.maps[id].before)
		for key in ["fingerprint", "cells", "layers", "usedTiles"]:
			if actual[key] != previous[key]:
				failures.append("Static frame/geometry/TileData differs: " + id + " " + key)
		failures.append_array(Validator.new().validate(root,path.trim_suffix(".tscn")+".tileset.tres"))
		var layers: Array[TileMapLayer] = []
		Compactor.new()._collect(root,layers)
		var tiles := layers[0].tile_set
		var groups := {}
		for i in tiles.get_source_count():
			var sid := tiles.get_source_id(i)
			var source := tiles.get_source(sid) as TileSetAtlasSource
			var pixels := source.texture.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			for j in source.get_tiles_count():
				var coords := source.get_tile_id(j)
				var hash := Fingerprint.new()._hash(pixels.get_region(source.get_tile_texture_region(coords,0)).get_data())
				var frames := source.get_tile_animation_frames_count(coords)
				if not catalog.has(hash):
					if frames > 1:
						failures.append("Unknown animated artwork: " + id)
					continue
				var entry: Dictionary = catalog[hash]
				if frames != entry.durations_ms.size():
					failures.append("Missing frames: " + id)
					continue
				groups[sid] = entry.group
				for f in frames:
					var frame_hash := Fingerprint.new()._hash(pixels.get_region(source.get_tile_texture_region(coords,f)).get_data())
					if frame_hash != entry.frame_hashes[f] or not is_equal_approx(source.get_tile_animation_frame_duration(coords,f),float(entry.durations_ms[f])/1000.0):
						failures.append("Frame pixels/timing differ: " + id)
					frame_count += 1
		var cells := {}
		for layer in layers:
			for cell in layer.get_used_cells():
				var sid := layer.get_cell_source_id(cell)
				if groups.has(sid):
					cells[groups[sid]] = int(cells.get(groups[sid],0)) + 1
					cell_count += 1
		if cells.size() != report.maps[id].animated_cells.size() or cells.keys().any(func(group): return int(cells[group]) != int(report.maps[id].animated_cells.get(group,-1))):
			failures.append("Animated cell counts differ: " + id)
		root.free()
	for failure in failures:
		push_error(failure)
	print("MAP_ANIMATION_CHECK ", JSON.stringify({"maps": report.maps.size(), "frames": frame_count, "animated_cells": cell_count, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
