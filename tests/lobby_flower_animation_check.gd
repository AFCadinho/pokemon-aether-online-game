extends "res://tools/route_flower_rollout.gd"


func _run() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/lobby_flower_rollout_report.json"))
	catalog = report.catalog
	var record: Dictionary = report.maps.lobby
	var path := _path("lobby")
	var visual := _load_visual(path)
	var actual := Fingerprint.new().capture(visual)
	var failures: Array[String] = []
	for key in ["fingerprint", "cells", "layers", "usedTiles"]:
		if actual[key] != record.before[key]:
			failures.append("Original lobby artwork/geometry/TileData changed: " + key)
	if actual.baseRGBABytes != record.after.baseRGBABytes:
		failures.append("Measured flower animation budget differs")
	failures.append_array(Validator.new().validate(visual, path.trim_suffix(".tscn") + ".tileset.tres"))
	var signatures := _animation_signatures(visual)
	for hash: String in record.preserved_animations:
		if not _same_signature(signatures.get(hash, []), record.preserved_animations[hash]):
			failures.append("Existing fountain/water/canopy animation changed")
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(visual, layers)
	var tiles := layers[0].tile_set
	var lookup := {}
	var counts := {}
	var samples := 0
	for index in tiles.get_source_count():
		var sid := tiles.get_source_id(index)
		var source := tiles.get_source(sid) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for tile in source.get_tiles_count():
			var coords := source.get_tile_id(tile)
			var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
			if not record.flower_cells.has(hash):
				continue
			lookup[str(sid) + str(coords)] = hash
			if not _matches(source, coords, catalog[hash]):
				failures.append("Flower pixels/timing differ from the towns and routes")
			samples += 48
	for layer in layers:
		for cell in layer.get_used_cells():
			var key := str(layer.get_cell_source_id(cell)) + str(layer.get_cell_atlas_coords(cell))
			if lookup.has(key):
				var hash: String = lookup[key]
				counts[hash] = int(counts.get(hash, 0)) + 1
	if not _same_counts(counts, record.flower_cells) or counts.values().reduce(func(total, value): return total + int(value), 0) != 60:
		failures.append("Expected all 60 existing pink flower tiles")
	visual.free()
	for failure in failures:
		push_error(failure)
	print("LOBBY_FLOWER_CHECK ", JSON.stringify({"cells": 60, "frame_samples": samples, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
