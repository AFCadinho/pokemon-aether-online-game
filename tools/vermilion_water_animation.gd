extends "res://tools/map_animation_rollout.gd"

# Rebuild Vermilion city or port sea-water frames, preserving the imported layout.
# Same 16 frames / 160 ms / 2 px horizontal motion as the approved Cerulean water.
var water_report := "res://tools/vermilion_water_animation_report.json"
var map_id := "vermilion_city"
var gameplay_scene := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"

func _run() -> void:
	if not "--apply" in OS.get_cmdline_user_args():
		_fail("Use --apply to rebuild Vermilion water animations.")
		return
	if "--port" in OS.get_cmdline_user_args():
		map_id = "vermilion_port_exterior"
		water_report = "res://tools/vermilion_port_water_animation_report.json"
		gameplay_scene = "res://scenes/overworld/kanto/towns/vermilion_docks/vermilion_docks.tscn"
	var catalog_changed := false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for entry: Dictionary in data.tiles:
		if entry.group == "water":
			catalog[entry.source_pixel_sha256] = entry
	var path := _path(map_id)
	var root := (ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	var before := Fingerprint.new().capture(root)
	var prior_animations := _animation_signatures(root)
	var ground := root.get_node("Ground") as TileMapLayer
	# The gameplay scene's reference cell identifies this map's open-water artwork.
	var gameplay := (ResourceLoader.load(gameplay_scene,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	var reference: Vector2i = gameplay.water_reference_tile
	gameplay.free()
	var source := ground.tile_set.get_source(ground.get_cell_source_id(reference)) as TileSetAtlasSource
	var pattern := source.texture.get_image().get_region(source.get_tile_texture_region(ground.get_cell_atlas_coords(reference),0))
	pattern.convert(Image.FORMAT_RGBA8)
	var colors := {}
	for y in 32:
		for x in 32:
			colors[pattern.get_pixel(x,y)] = true
	assert(colors.size() == 3, "Expected Vermilion's three-color blue water palette")
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(root,layers)
	var seen := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			var sid := layer.get_cell_source_id(cell)
			var coords := layer.get_cell_atlas_coords(cell)
			var tile_source := layer.tile_set.get_source(sid) as TileSetAtlasSource
			if tile_source.get_tile_animation_frames_count(coords) > 1:
				continue
			var tile := tile_source.texture.get_image().get_region(tile_source.get_tile_texture_region(coords))
			tile.convert(Image.FORMAT_RGBA8)
			var hash := Fingerprint.new()._hash(tile.get_data())
			if seen.has(hash):
				continue
			seen[hash] = true
			var frames: Array[Image] = [tile]
			for f in range(1,16):
				var frame := tile.duplicate() as Image
				for y in 32:
					for x in 32:
						if colors.has(tile.get_pixel(x,y)):
							frame.set_pixel(x,y,pattern.get_pixel(posmod(x-2*f,32),y))
				frames.append(frame)
			var hashes: Array[String] = []
			var strip := Image.create_empty(512,32,false,Image.FORMAT_RGBA8)
			for f in 16:
				hashes.append(Fingerprint.new()._hash(frames[f].get_data()))
				strip.blit_rect(frames[f],Rect2i(0,0,32,32),Vector2i(f*32,0))
			if hashes.all(func(value): return value == hash):
				continue
			var entry := {"source_pixel_sha256":hash,"image":hash+".png","group":"water",
				"durations_ms":[160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160],"frame_hashes":hashes}
			if not catalog.has(hash):
				assert(strip.save_png(CATALOG.get_base_dir().path_join(entry.image)) == OK)
				catalog_changed = true
				data.tiles.append(entry)
				catalog[hash] = entry
	var plan := _plan(root)
	if plan.animations.is_empty():
		root.free()
		print("VERMILION_WATER already animated; no changes")
		quit()
		return
	scratch = "user://vermilion_water_%d" % OS.get_process_id()
	var temp := scratch.path_join(map_id+"/"+map_id+".visual.tscn")
	var result := _save(root,temp,plan.animations)
	root.free()
	if not result.success or _verify(temp,before).is_empty():
		_fail("Vermilion water staging failed")
		return
	root = (ResourceLoader.load(temp,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	var staged_animations := _animation_signatures(root)
	for hash in prior_animations:
		assert(staged_animations.get(hash) == prior_animations[hash], "Existing animation changed")
	root.free()
	root = (ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	plan = _plan(root)
	result = _save(root,path,plan.animations)
	root.free()
	if not result.success:
		_fail("Vermilion water save failed")
		return
	var after := _verify(path,before)
	if after.is_empty():
		return
	if catalog_changed:
		FileAccess.open(CATALOG,FileAccess.WRITE).store_string(JSON.stringify(data,"  ",false)+"\n")
	_write(water_report,{"version":1,"map":map_id,"before":before,"after":after,
		"animated_cells":plan.cells,"animated_types":plan.types,"preserved_animations":prior_animations})
	_cleanup(scratch)
	print("VERMILION_WATER PASS ",JSON.stringify({"map":map_id,"cells":plan.cells,"types":plan.types}))
	quit()

static func _animation_signatures(root: Node) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(root,layers)
	var tiles := layers[0].tile_set
	var result := {}
	for i in tiles.get_source_count():
		var source := tiles.get_source(tiles.get_source_id(i)) as TileSetAtlasSource
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			if source.get_tile_animation_frames_count(coords) <= 1:
				continue
			var frames := []
			for f in source.get_tile_animation_frames_count(coords):
				frames.append({"hash":Fingerprint.new()._hash(image.get_region(source.get_tile_texture_region(coords,f)).get_data()),
					"duration":source.get_tile_animation_frame_duration(coords,f),"speed":source.get_tile_animation_speed(coords)})
			result[frames[0].hash] = frames
	return result

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
				continue
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
