extends SceneTree

const Recovery := preload("res://tools/restore_map_water_animations.gd")
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
var failures: Array[String] = []


func _init() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Recovery.RECOVERY_REPORT))
	var catalog := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Recovery.CATALOG))
	for entry: Dictionary in data.tiles:
		if entry.group == "water":
			catalog[entry.source_pixel_sha256] = entry
	var frame_count := 0
	for id: String in report.reviewed_maps:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var visual := (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		if Recovery.missing_water(visual, catalog) != 0:
			failures.append("Missing water animation: " + id)
		var layers: Array[TileMapLayer] = []
		Compactor.new()._collect(visual, layers)
		var tiles := layers[0].tile_set
		for index in tiles.get_source_count():
			var source := tiles.get_source(tiles.get_source_id(index)) as TileSetAtlasSource
			var image := source.texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			for tile in source.get_tiles_count():
				var coords := source.get_tile_id(tile)
				var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
				if not catalog.has(hash):
					continue
				var entry: Dictionary = catalog[hash]
				if source.get_tile_animation_frames_count(coords) != entry.frame_hashes.size():
					failures.append("Water frame count differs: " + id)
					continue
				for frame in entry.frame_hashes.size():
					var pixels := image.get_region(source.get_tile_texture_region(coords, frame)).get_data()
					if Fingerprint.new()._hash(pixels) != entry.frame_hashes[frame] or not is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), float(entry.durations_ms[frame]) / 1000.0):
						failures.append("Water frame artwork/timing differs: " + id)
					frame_count += 1
		if report.maps.has(id):
			var actual := Fingerprint.new().capture(visual)
			for key in ["fingerprint", "cells", "layers", "usedTiles"]:
				if actual[key] != report.maps[id].before[key]:
					failures.append("Original geometry/artwork/TileData differs: " + id + " " + key)
			var animations := Recovery._animation_signatures(visual)
			for hash: String in report.maps[id].preserved_animations:
				if not _same_animation(animations.get(hash, []), report.maps[id].preserved_animations[hash]):
					failures.append("Existing animation differs: " + id)
		visual.free()
	for failure in failures:
		push_error(failure)
	print("WATER_RECOVERY_CHECK ", JSON.stringify({"maps": report.reviewed_maps.size(), "frames": frame_count, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _same_animation(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for frame in actual.size():
		if actual[frame].hash != expected[frame].hash or not is_equal_approx(actual[frame].duration, expected[frame].duration) or not is_equal_approx(actual[frame].speed, expected[frame].speed):
			return false
	return true
