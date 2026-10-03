extends "res://tools/vermilion_water_animation.gd"

# Match approved water artwork in every generated map, including maps whose
# grass/trees are still animated. Never reconstruct geometry from authoring TMX.
const RECOVERY_REPORT := "res://tools/water_animation_recovery_report.json"


func _run() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for entry: Dictionary in data.tiles:
		if entry.group == "water":
			catalog[entry.source_pixel_sha256] = entry
	var reviewed: Array[String] = []
	var repairs := {}
	var ids := DirAccess.get_directories_at("res://generated/tiled_visuals")
	ids.sort()
	for id in ids:
		var path := _path(id)
		if not FileAccess.file_exists(path):
			continue
		reviewed.append(id)
		var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var visual := packed.instantiate()
		var missing := missing_water(visual, catalog)
		if missing == 0:
			visual.free()
			continue
		print("MISSING_WATER ", id, " tiles=", missing)
		if not apply:
			visual.free()
			continue
		var before := Fingerprint.new().capture(visual)
		var prior_animations := _animation_signatures(visual)
		var plan := _plan(visual)
		scratch = "user://water_recovery_%d" % OS.get_process_id()
		var temp := scratch.path_join(id + "/" + id + ".visual.tscn")
		var saved := _save(visual, temp, plan.animations)
		visual.free()
		if not saved.success or _verify(temp, before).is_empty():
			_fail("Water staging failed: " + id)
			return
		var staged := (ResourceLoader.load(temp, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		var staged_animations := _animation_signatures(staged)
		for hash in prior_animations:
			if staged_animations.get(hash) != prior_animations[hash]:
				_fail("Existing animation changed: " + id)
				staged.free()
				return
		staged.free()
		visual = (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		plan = _plan(visual)
		saved = _save(visual, path, plan.animations)
		visual.free()
		if not saved.success:
			_fail("Water save failed: " + id)
			return
		var after := _verify(path, before)
		if after.is_empty():
			return
		repairs[id] = {"before": before, "after": after, "animated_cells": plan.cells,
			"animated_types": plan.types, "preserved_animations": prior_animations}
		if id == "vermilion_city" or id == "vermilion_port_exterior":
			var report_path := "res://tools/vermilion_water_animation_report.json" if id == "vermilion_city" else "res://tools/vermilion_port_water_animation_report.json"
			var water_data: Dictionary = repairs[id].duplicate(true)
			water_data["version"] = 1
			water_data["map"] = id
			_write(report_path, water_data)
		_cleanup(scratch)
	if apply and not repairs.is_empty():
		_write(RECOVERY_REPORT, {"version": 1, "reviewed_maps": reviewed, "maps": repairs})
	print("WATER_RECOVERY ", JSON.stringify({"reviewed": reviewed.size(), "restored": repairs.keys(), "applied": apply}))
	quit(0)


static func missing_water(visual: Node, water_catalog: Dictionary) -> int:
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(visual, layers)
	if layers.is_empty():
		return 0
	var tiles := layers[0].tile_set
	var count := 0
	for index in tiles.get_source_count():
		var source := tiles.get_source(tiles.get_source_id(index)) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for tile in source.get_tiles_count():
			var coords := source.get_tile_id(tile)
			var hash := Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords, 0)).get_data())
			if water_catalog.has(hash) and source.get_tile_animation_frames_count(coords) == 1:
				count += 1
	return count
