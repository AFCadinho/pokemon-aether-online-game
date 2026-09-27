extends SceneTree

# Match exact RGBA artwork, not historical atlas coordinates or relocated TMX paths.
# This preserves the current shipped layout, TileData, layers and cell transforms.
const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const CATALOG := "res://tools/map_animation_assets/catalog.json"
const EXPECTED := "res://tests/fixtures/tiled/migrated_visual_fingerprints.json"
const REPORT := "res://tools/map_animation_rollout_report.json"
var catalog := {}
var scratch := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for entry: Dictionary in data.tiles:
		catalog[entry.source_pixel_sha256] = entry
	scratch = "user://map_animation_rollout_%d" % OS.get_process_id()
	var results := {}
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	var ids := DirAccess.get_directories_at("res://generated/tiled_visuals")
	for id in ids:
		if id in ["pallet_animated_tiles_test", "viridian_water_test"]:
			continue
		var path := _path(id)
		var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if packed == null:
			_fail("Cannot load " + path)
			return
		var root := packed.instantiate()
		var before := Fingerprint.new().capture(root)
		var plan := _plan(root)
		if plan.get("already_animated", false):
			root.free()
			continue
		if plan.animations.is_empty():
			root.free()
			continue
		var temp := scratch.path_join(id + "/" + id + ".visual.tscn")
		var result := _save(root, temp, plan.animations)
		root.free()
		if not result.get("success", false):
			_fail(str(result))
			return
		var after := _verify(temp, before)
		if after.is_empty():
			return
		results[id] = {"before": before, "after": after, "animated_cells": plan.cells, "animated_types": plan.types}
		print("ANIMATION_STAGE ", id, " ", JSON.stringify(results[id]))
	# All affected maps stage successfully before canonical resources are changed.
	if apply and not results.is_empty():
		for id in results:
			var path := _path(id)
			var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			var root := packed.instantiate()
			var plan := _plan(root)
			var result := _save(root, path, plan.animations)
			root.free()
			if not result.get("success", false):
				_fail(str(result))
				return
			var verified := _verify(path, results[id].before)
			if verified.is_empty():
				return
			# Artwork/layout fingerprint is asserted unchanged. Only the explicitly
			# measured animation memory allowance changes in the existing fixture.
			if baseline.has(id):
				if baseline[id].fingerprint != verified.fingerprint:
					_fail("Existing baseline artwork differs: " + id)
					return
				baseline[id].baseRGBABytes = verified.baseRGBABytes
		_write(EXPECTED, baseline)
		_write(REPORT, {"version": 1, "maps": results, "catalog": CATALOG})
	_cleanup(scratch)
	print("MAP_ANIMATION_ROLLOUT ", JSON.stringify({"maps": results.size(), "applied": apply, "success": true}))
	quit(0)

func _plan(root: Node) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(root, layers)
	var tiles := layers[0].tile_set
	var matches := {}
	var types := 0
	for i in tiles.get_source_count():
		var id := tiles.get_source_id(i)
		var source := tiles.get_source(id) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			if source.get_tile_animation_frames_count(coords) > 1:
				return {"already_animated": true}
			var pixels := image.get_region(source.get_tile_texture_region(coords)).get_data()
			var key := Fingerprint.new()._hash(pixels)
			if catalog.has(key):
				if not matches.has(id):
					matches[id] = {}
				matches[id][coords] = catalog[key]
				types += 1
	var cells := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			var entry: Dictionary = matches.get(layer.get_cell_source_id(cell), {}).get(layer.get_cell_atlas_coords(cell), {})
			if not entry.is_empty():
				cells[entry.group] = int(cells.get(entry.group, 0)) + 1
	var frame_sources := {}
	var animations := {}
	for id in matches:
		animations[id] = {}
		for coords in matches[id]:
			var entry: Dictionary = matches[id][coords]
			var key: String = entry.source_pixel_sha256
			if not frame_sources.has(key):
				var image := Image.load_from_file(CATALOG.get_base_dir().path_join(entry.image))
				image.convert(Image.FORMAT_RGBA8)
				var source := TileSetAtlasSource.new()
				source.texture = ImageTexture.create_from_image(image)
				source.texture_region_size = Vector2i(32,32)
				for f in entry.durations_ms.size():
					source.create_tile(Vector2i(f,0))
					assert(Fingerprint.new()._hash(image.get_region(Rect2i(f*32,0,32,32)).get_data()) == entry.frame_hashes[f])
				frame_sources[key] = tiles.add_source(source)
			var frames: Array = []
			for f in entry.durations_ms.size():
				frames.append({"source_id": frame_sources[key], "atlas_coords": Vector2i(f,0), "duration": entry.durations_ms[f]})
			animations[id][coords] = frames
	return {"animations": animations, "cells": cells, "types": types}

func _save(root: Node, path: String, animations: Dictionary) -> Dictionary:
	var result := Compactor.new().compact(root, path.trim_suffix(".tscn") + ".tileset.tres", animations)
	if not result.get("success", false):
		return result
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene,path)
	return {"success": err == OK, "error": error_string(err)}

func _verify(path: String, before: Dictionary) -> Dictionary:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var root := packed.instantiate()
	var after := Fingerprint.new().capture(root)
	var errors := Validator.new().validate(root,path.trim_suffix(".tscn")+".tileset.tres")
	root.free()
	if before.fingerprint != after.fingerprint or before.cells != after.cells or before.layers != after.layers or before.usedTiles != after.usedTiles or not errors.is_empty():
		_fail("Static frame/layout/TileData changed: " + path + str(errors))
		return {}
	return after

func _path(id: String) -> String:
	return "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id,id]
func _write(path: String, data: Dictionary) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t",true)+"\n")
func _cleanup(path: String) -> void:
	for child in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(child))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
