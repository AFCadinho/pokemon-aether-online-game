extends "res://tools/vermilion_water_animation.gd"

# Import the authored flower library through the TMX pipeline, then match exact
# artwork in the active visuals. Stage every change before replacing resources.
const INTAKE := "res://tools/route_flower_rollout_intake.json"
const ROUTE_REPORT := "res://tools/route_flower_rollout_report.json"
const VisualImporter := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
var library_sources := {}


func _run() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var intake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INTAKE))
	catalog = intake.catalog
	scratch = "user://route_flower_rollout_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	var fixture := scratch.path_join("flowers.tmx")
	var csv: Array[String] = []
	for index in catalog.size():
		csv.append(str(index + 1))
	var xml := '<map orientation="orthogonal" renderorder="right-down" width="%d" height="1" tilewidth="32" tileheight="32" infinite="0"><tileset firstgid="1" source="%s"/><layer id="1" name="Flowers" width="%d" height="1"><data encoding="csv">%s</data></layer></map>' % [catalog.size(), str(intake.flower_tileset).xml_escape(), catalog.size(), ",".join(csv)]
	FileAccess.open(fixture, FileAccess.WRITE).store_string(xml)
	var library_path := scratch.path_join("library/library.visual.tscn")
	var imported := VisualImporter.new().import_tmx(ProjectSettings.globalize_path(fixture), library_path)
	if not imported.get("success", false):
		_fail(str(imported))
		return
	var library := _load_visual(library_path)
	var flower_layer := library.get_node("Flowers") as TileMapLayer
	for hash: String in catalog:
		var cell := Vector2i(int(catalog[hash].local_id), 0)
		var source := flower_layer.tile_set.get_source(flower_layer.get_cell_source_id(cell)) as TileSetAtlasSource
		library_sources[hash] = source
		if not _matches(source, Vector2i.ZERO, catalog[hash]):
			_fail("TMX flower library differs from the authored frames: " + hash)
			library.free()
			return
	library.free()
	var results := {}
	var changed := []
	for id: String in intake.maps:
		var path := _path(id)
		var visual := _load_visual(path)
		var before := Fingerprint.new().capture(visual)
		var prior := _animation_signatures(visual)
		var plan := _flower_plan(visual)
		if not _same_counts(plan.cells, intake.maps[id].expected_flower_cells):
			visual.free()
			_fail("Active route flower artwork/placement differs from its audited source: " + id)
			return
		var after := before
		if not plan.animations.is_empty():
			var temp := scratch.path_join(id + "/" + id + ".visual.tscn")
			var saved := _save(visual, temp, plan.animations)
			visual.free()
			if not saved.get("success", false):
				_fail(str(saved))
				return
			after = _verify(temp, before)
			if after.is_empty() or not _preserved(temp, prior):
				return
			changed.append(id)
		else:
			visual.free()
		var preserved := prior.duplicate()
		for hash: String in catalog:
			preserved.erase(hash)
		results[id] = {"before": before, "after": after, "flower_cells": plan.cells,
			"updated_types": plan.types, "preserved_animations": preserved,
			"source": intake.maps[id].source, "source_sha256": intake.maps[id].source_sha256,
			"scene_paths": intake.maps[id].scene_paths, "registered_areas": intake.maps[id].registered_areas}
		print("ROUTE_FLOWER_STAGE ", id, " ", JSON.stringify({"cells": plan.cells.values().reduce(func(total, value): return total + int(value), 0), "updated_types": plan.types}))
	if apply:
		for id: String in changed:
			var path := _path(id)
			var previous_textures := VisualImporter.new()._owned_compact_paths(path)
			var visual := _load_visual(path)
			var prior := _animation_signatures(visual)
			var plan := _flower_plan(visual)
			var saved := _save(visual, path, plan.animations)
			visual.free()
			if not saved.get("success", false):
				_fail(str(saved))
				return
			var after := _verify(path, results[id].before)
			if after.is_empty() or not _preserved(path, prior):
				return
			results[id].after = after
			var saved_tileset := FileAccess.get_file_as_string(path.trim_suffix(".tscn") + ".tileset.tres")
			for texture: String in previous_textures:
				if not saved_tileset.contains(texture):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(texture))
		if not changed.is_empty():
			_write(ROUTE_REPORT, {"version": 1, "catalog": catalog, "maps": results,
				"changed_visuals": changed, "godot_backup": intake.godot_backup,
				"source_backup": intake.source_backup, "unused_sources": intake.unused_sources,
				"gameplay_and_original_visual_geometry_preserved": true})
	library_sources.clear()
	_cleanup(scratch)
	print("ROUTE_FLOWER_ROLLOUT ", JSON.stringify({"reviewed": results.size(), "changed": changed.size(), "applied": apply, "success": true}))
	quit()


func _flower_plan(visual: Node) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(visual, layers)
	var tiles := layers[0].tile_set
	var matches := {}
	var lookup := {}
	var cells := {}
	var types := 0
	for index in tiles.get_source_count():
		var id := tiles.get_source_id(index)
		var source := tiles.get_source(id) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for tile in source.get_tiles_count():
			var coords := source.get_tile_id(tile)
			var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
			if not catalog.has(hash):
				continue
			lookup[str(id) + str(coords)] = hash
			if _matches(source, coords, catalog[hash]):
				continue
			if not matches.has(id):
				matches[id] = {}
			matches[id][coords] = hash
			types += 1
	for layer in layers:
		for cell in layer.get_used_cells():
			var key := str(layer.get_cell_source_id(cell)) + str(layer.get_cell_atlas_coords(cell))
			if lookup.has(key):
				var hash: String = lookup[key]
				cells[hash] = int(cells.get(hash, 0)) + 1
	var frame_sources := {}
	var animations := {}
	for id in matches:
		animations[id] = {}
		for coords in matches[id]:
			var hash: String = matches[id][coords]
			if not frame_sources.has(hash):
				frame_sources[hash] = tiles.add_source(library_sources[hash].duplicate())
			var frames := []
			for frame in 48:
				frames.append({"source_id": frame_sources[hash], "atlas_coords": Vector2i.ZERO,
					"frame_index": frame, "duration": 70})
			animations[id][coords] = frames
	return {"animations": animations, "cells": cells, "types": types}


func _matches(source: TileSetAtlasSource, coords: Vector2i, entry: Dictionary) -> bool:
	if source.get_tile_animation_frames_count(coords) != 48 or not is_equal_approx(source.get_tile_animation_speed(coords), 1.0):
		return false
	var image := source.texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for frame in 48:
		if not is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.07):
			return false
		if Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, frame)).get_data()) != entry.frame_hashes[frame]:
			return false
	return true


func _preserved(path: String, prior: Dictionary) -> bool:
	var visual := _load_visual(path)
	var actual := _animation_signatures(visual)
	visual.free()
	for hash: String in prior:
		if catalog.has(hash):
			continue
		if not _same_signature(actual.get(hash, []), prior[hash]):
			_fail("Existing non-flower animation changed: " + path)
			return false
	return true


func _same_signature(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for frame in actual.size():
		if actual[frame].hash != expected[frame].hash or not is_equal_approx(actual[frame].duration, expected[frame].duration) or not is_equal_approx(actual[frame].speed, expected[frame].speed):
			return false
	return true


func _same_counts(actual: Dictionary, expected: Dictionary) -> bool:
	return actual.size() == expected.size() and expected.keys().all(func(hash): return int(actual.get(hash, -1)) == int(expected[hash]))


func _load_visual(path: String) -> Node:
	return (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
