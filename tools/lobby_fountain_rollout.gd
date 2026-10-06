extends "res://tools/vermilion_water_animation.gd"

# Import the authored transparent water layer through the normal TMX pipeline,
# then compact it with the existing visual without rebuilding its other layers.
const INTAKE := "res://tools/lobby_fountain_assets/source_manifest.json"
const FOUNTAIN_REPORT := "res://tools/lobby_fountain_rollout_report.json"
const VisualImporter := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
var intake: Dictionary


func _run() -> void:
	intake = JSON.parse_string(FileAccess.get_file_as_string(INTAKE))
	var path := _path("lobby")
	var visual := _load(path)
	var before := Fingerprint.new().capture(visual)
	var prior := _animation_signatures(visual)
	if visual.has_node("FountainWater"):
		var existing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOUNTAIN_REPORT))
		if JSON.stringify(existing.catalog, "", true) == JSON.stringify(intake.catalog, "", true):
			assert(_check_visual(visual, path, existing.before, existing.preserved_animations))
			visual.free()
			print("LOBBY_FOUNTAIN already imported; no changes")
			quit()
			return
		# Replace only the previous fountain overlay; retain the original static
		# reference and all pre-fountain animation timelines across revisions.
		before = existing.before
		prior = existing.preserved_animations
		var old_water := visual.get_node("FountainWater")
		old_water.owner = null
		visual.remove_child(old_water)
		old_water.free()
	scratch = "user://lobby_fountain_%d" % OS.get_process_id()
	var library_path := scratch.path_join("library/library.visual.tscn")
	var result := VisualImporter.new().import_tmx(ProjectSettings.globalize_path("res://tools/lobby_fountain_assets/FountainWater.tmx"), library_path)
	assert(result.get("success", false), str(result))
	var library := _load(library_path)
	var water := library.get_node("FountainWater") as TileMapLayer
	water.owner = null
	library.remove_child(water)
	var original := (visual.get_node("Ground") as TileMapLayer).tile_set
	var imported := water.tile_set
	var mapping := {}
	for i in imported.get_source_count():
		var sid := imported.get_source_id(i)
		mapping[sid] = original.add_source(imported.get_source(sid).duplicate())
	for cell in water.get_used_cells():
		water.set_cell(cell, mapping[water.get_cell_source_id(cell)], water.get_cell_atlas_coords(cell), water.get_cell_alternative_tile(cell))
	water.tile_set = original
	visual.add_child(water)
	water.owner = visual
	library.free()
	var staged := scratch.path_join("lobby/lobby.visual.tscn")
	result = _save(visual, staged, {})
	visual.free()
	assert(result.get("success", false), str(result))
	visual = _load(staged)
	assert(_check_visual(visual, staged, before, prior), "Fountain staging failed")
	var applied := "--apply" in OS.get_cmdline_user_args()
	if applied:
		var old_paths := VisualImporter.new()._owned_compact_paths(path)
		result = _save(visual, path, {})
		assert(result.get("success", false), str(result))
		visual.free()
		visual = _load(path)
		assert(_check_visual(visual, path, before, prior), "Fountain save verification failed")
		var after := Fingerprint.new().capture(visual)
		_write(FOUNTAIN_REPORT, {"version": 1, "before": before, "after": after,
			"preserved_animations": prior, "source": intake.source, "source_sha256": intake.source_sha256,
			"backup": intake.backup, "catalog": intake.catalog, "cells": intake.cells,
			"existing_visual_and_gameplay_preserved": true})
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		baseline.lobby = after
		_write(EXPECTED, baseline)
		var rollout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
		rollout.maps.lobby.current_static_reference = after
		rollout.maps.lobby.animation_overrides = intake.catalog
		rollout.maps.lobby.animated_cells.fountain = intake.cells.size()
		_write(REPORT, rollout)
		var tileset_text := FileAccess.get_file_as_string(path.trim_suffix(".tscn") + ".tileset.tres")
		for old_path: String in old_paths:
			if not tileset_text.contains(old_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	visual.free()
	_cleanup(scratch)
	print("LOBBY_FOUNTAIN ", JSON.stringify({"success": true, "applied": applied, "cells": intake.cells.size(), "frames": 24}))
	quit()


func _check_visual(visual: Node, path: String, before: Dictionary, prior: Dictionary) -> bool:
	var errors := Validator.new().validate(visual, path.trim_suffix(".tscn") + ".tileset.tres")
	var water := visual.get_node("FountainWater") as TileMapLayer
	assert(water.z_index == int(intake.z_index) and water.get_used_cells().size() == intake.cells.size(), "Fountain layer/placement differs")
	for cell: Dictionary in intake.cells:
		var pos := Vector2i(int(cell.x), int(cell.y))
		var source := water.tile_set.get_source(water.get_cell_source_id(pos)) as TileSetAtlasSource
		var coords := water.get_cell_atlas_coords(pos)
		var entry: Dictionary = intake.catalog[cell.hash]
		assert(water.get_cell_alternative_tile(pos) == 0 and source.get_tile_animation_frames_count(coords) == 24)
		assert(is_equal_approx(source.get_tile_animation_speed(coords), 1.0))
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for frame in 24:
			assert(Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, frame)).get_data()) == entry.frame_hashes[frame], "Authored fountain pixels differ")
			assert(is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.08), "Authored fountain timing differs")
	var timelines := _animation_signatures(visual)
	for hash: String in prior:
		var expected: Array = prior[hash]
		var actual: Array = timelines.get(hash, [])
		assert(actual.size() == expected.size(), "Existing animation frame count changed")
		for frame in actual.size():
			assert(actual[frame].hash == expected[frame].hash and is_equal_approx(actual[frame].duration, expected[frame].duration) and is_equal_approx(actual[frame].speed, expected[frame].speed), "Existing animation changed")
	# Excluding only the new overlay must reproduce every original sprite,
	# layer property, cell transform, TileData and placement exactly.
	water.owner = null
	visual.remove_child(water)
	var original := Fingerprint.new().capture(visual)
	visual.add_child(water)
	water.owner = visual
	for key in ["fingerprint", "cells", "layers", "usedTiles"]:
		assert(original[key] == before[key], "Original lobby changed: " + key)
	assert(errors.is_empty(), str(errors))
	return true


func _load(path: String) -> Node:
	return (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
