@tool
extends RefCounted

# The approved Route 1 sprite, recognized by exact artwork rather than GIDs.
# Runs only while importing/migrating; runtime uses ordinary native animations.
const PIXELS_SHA256 := "51da45d3409e3df7cebf73c9532d68feff02438ac2a9eab5f04fa36532ab23d4"
const FOREST_SHA256 := "579fbc399f9504e092163b147ba6131a0b1421bd5feb93a427849f37efef7129"
const IMAGES := {
	PIXELS_SHA256:"res://addons/tiled_tmx_importer/assets/tall_grass_wind.png",
	FOREST_SHA256:"res://addons/tiled_tmx_importer/assets/tall_grass_wind_forest.png",
}
const PAUSES := [600, 1400, 2300, 3200]
const VERSION := 1
const META := "pao_tall_grass_wind_version"

static func phase_at(cell: Vector2i) -> int:
	var h := (floori(float(cell.x) / 2.0) * 73856093) ^ (floori(float(cell.y) / 2.0) * 19349663)
	return ((h >> 8) ^ h) & 3

func apply(root: Node, incoming: Dictionary = {}) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd").new()._collect(root, layers)
	if layers.is_empty():
		return {"animations": incoming, "cells": 0}
	var tiles := layers[0].tile_set
	if int(tiles.get_meta(META,0)) == VERSION:
		return {"animations": incoming, "cells": 0}
	var matches := {}
	for i in tiles.get_source_count():
		var id := tiles.get_source_id(i)
		var source := tiles.get_source(id) as TileSetAtlasSource
		if source == null or source.texture_region_size != Vector2i(32,32):
			continue
		var image := source.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(image.get_region(source.get_tile_texture_region(coords)).get_data())
			var key := hash.finish().hex_encode()
			if IMAGES.has(key):
				if not matches.has(id):
					matches[id] = {}
				matches[id][coords] = {"hash":key,"variants":{}}
	if matches.is_empty():
		return {"animations": incoming, "cells": 0}
	var animations := incoming.duplicate(true)
	var textures := {}
	var count := 0
	var phase_counts := [0,0,0,0]
	for layer in layers:
		for cell in layer.get_used_cells():
			var old_id := layer.get_cell_source_id(cell)
			var old_coords := layer.get_cell_atlas_coords(cell)
			if not matches.get(old_id,{}).has(old_coords):
				continue
			var phase := phase_at(cell)
			var match_data: Dictionary = matches[old_id][old_coords]
			var variants: Dictionary = match_data.variants
			if not textures.has(match_data.hash):
				textures[match_data.hash]=ImageTexture.create_from_image(Image.load_from_file(IMAGES[match_data.hash]))
			if not variants.has(phase):
				var old := tiles.get_source(old_id) as TileSetAtlasSource
				var source := TileSetAtlasSource.new()
				source.texture = textures[match_data.hash]
				source.texture_region_size = Vector2i(32,32)
				source.use_texture_padding = old.use_texture_padding
				source.set_meta("pao_tall_grass_family",match_data.hash)
				var sid := tiles.add_source(source)
				for n in 53:
					source.create_tile(Vector2i(n%8,n/8))
				for a in old.get_alternative_tiles_count(old_coords):
					var alt := old.get_alternative_tile_id(old_coords,a)
					if alt != 0:
						source.create_alternative_tile(Vector2i.ZERO,alt)
					var before := old.get_tile_data(old_coords,alt)
					var after := source.get_tile_data(Vector2i.ZERO,alt)
					for property in before.get_property_list():
						if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
							after.set(property.name,before.get(property.name))
					for key in before.get_meta_list():
						after.set_meta(key,before.get_meta(key))
				var frames: Array = [{"source_id":sid,"atlas_coords":Vector2i(4,0),"duration":PAUSES[phase]}]
				for f in range(1,49):
					var n := 4+f
					frames.append({"source_id":sid,"atlas_coords":Vector2i(n%8,n/8),"duration":70})
				frames.append({"source_id":sid,"atlas_coords":Vector2i(4,0),"duration":4200-PAUSES[phase]})
				animations[sid] = {Vector2i.ZERO:frames}
				variants[phase] = sid
			layer.set_cell(cell,variants[phase],Vector2i.ZERO,layer.get_cell_alternative_tile(cell))
			phase_counts[phase] += 1
			count += 1
	if count > 0:
		tiles.set_meta(META,VERSION)
	return {"animations":animations,"cells":count,"phase_counts":phase_counts}
