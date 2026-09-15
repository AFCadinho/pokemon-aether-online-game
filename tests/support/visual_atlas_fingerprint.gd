extends RefCounted

# Paths and packed atlas coordinates deliberately do not affect the fingerprint.
# Artwork, cell transforms, layer order/settings and TileData do affect it.
func capture(root: Node) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd").new()._collect(root, layers)
	var records: Array = []
	var images := {}
	var tiles := {}
	var cells := 0
	var bytes := 0
	var textures := {}
	for layer in layers:
		for index in layer.tile_set.get_source_count():
			var source := layer.tile_set.get_source(layer.tile_set.get_source_id(index)) as TileSetAtlasSource
			if not textures.has(source.texture.resource_path):
				textures[source.texture.resource_path] = true
				bytes += source.texture.get_width() * source.texture.get_height() * 4
		var record := {"settings": _properties(layer, ["tile_set", "tile_map_data", "script"]), "cells": []}
		var positions := layer.get_used_cells()
		positions.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
		for cell in positions:
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var alternative := layer.get_cell_alternative_tile(cell)
			var key := "%s/%s/%d" % [source.texture.resource_path, coords, alternative & ~(4096 | 8192 | 16384)]
			if not images.has(source.texture.resource_path):
				var image := source.texture.get_image()
				image.convert(Image.FORMAT_RGBA8)
				images[source.texture.resource_path] = image
			if not tiles.has(key):
				var data := source.get_tile_data(coords, alternative & ~(4096 | 8192 | 16384))
				tiles[key] = {"pixels": _hash(images[source.texture.resource_path].get_region(source.get_tile_texture_region(coords)).get_data()), "data": _properties(data, ["script"]), "padding": source.use_texture_padding}
			record.cells.append({"position": str(cell), "alternative": alternative, "tile": tiles[key]})
			cells += 1
		records.append(record)
	return {"fingerprint": _hash(JSON.stringify(records, "", true).to_utf8_buffer()), "cells": cells, "usedTiles": tiles.size(), "layers": layers.size(), "baseRGBABytes": bytes}

func _properties(object: Object, excluded: Array) -> Dictionary:
	var result := {}
	for property in object.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in excluded:
			result[property.name] = var_to_str(object.get(property.name))
	return result

func _hash(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
