extends SceneTree
const Importer := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")

func _init() -> void:
	var scope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/browser-misty-scope.json"))
	var requested := OS.get_cmdline_user_args()
	for id: String in scope.additionalVisualDirectories:
		if not requested.is_empty() and not requested.has(id):
			continue
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var before: Node = load(path).instantiate()
		var original := _pixels(before)
		var source := str(before.get_meta("tiled_source_path", ""))
		if id == "route_3" and not FileAccess.file_exists(source):
			source = "/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/routes/Route 3.tmx"
		before.free()
		var result: Dictionary = Importer.new().import_tmx(source, path)
		if not result.get("success", false):
			push_error(str(result))
			quit(1)
			return
		var after: Node = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP).instantiate()
		if original != _pixels(after):
			push_error("Visual pixels changed during regeneration: " + id)
			after.free()
			quit(1)
			return
		after.free()
		print("REBUILT pixel-identical 4096px atlases: ", id)
	quit(0)

func _pixels(node: Node) -> Dictionary:
	var result := {}
	var tiles := {}
	for child in node.get_children():
		if not child is TileMapLayer:
			continue
		var layer := child as TileMapLayer
		var cells := {}
		for cell in layer.get_used_cells():
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var coords := layer.get_cell_atlas_coords(cell)
			var key := str(source.texture.resource_path) + str(coords)
			if not tiles.has(key):
				var image := source.texture.get_image().get_region(Rect2i(coords * source.texture_region_size, source.texture_region_size))
				var hash := HashingContext.new()
				hash.start(HashingContext.HASH_SHA256)
				hash.update(image.get_data())
				tiles[key] = hash.finish().hex_encode()
			cells[str(cell)] = [tiles[key], layer.get_cell_alternative_tile(cell)]
		result[str(child.name)] = cells
	return result
