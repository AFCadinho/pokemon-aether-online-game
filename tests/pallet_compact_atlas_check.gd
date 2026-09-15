extends SceneTree

const ORIGINAL := "res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn"
const COMPACT := "res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn"
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var old_scene: PackedScene = load(ORIGINAL)
	var new_scene: PackedScene = load(COMPACT)
	_check(old_scene != null and new_scene != null, "Both visual scenes load")
	if old_scene == null or new_scene == null:
		quit(1)
		return
	var old := old_scene.instantiate()
	var compact := new_scene.instantiate()
	_check(old.get_child_count() == compact.get_child_count(), "Layer count preserved")
	var decoded := {}
	var verified := {}
	var cells_checked := 0
	var bytes := 0
	var new_tiles: TileSet
	for layer: TileMapLayer in old.get_children():
		var target := compact.get_node_or_null(NodePath(layer.name)) as TileMapLayer
		_check(target != null, "Layer names preserved")
		if target == null:
			continue
		for property in layer.get_property_list():
			var name: String = property.name
			if int(property.usage) & PROPERTY_USAGE_STORAGE and name not in ["tile_set", "tile_map_data", "script"]:
				_check(layer.get(name) == target.get(name), "Layer property preserved: %s/%s" % [layer.name, name])
		_check(layer.get_used_cells() == target.get_used_cells(), "Cell positions/order preserved")
		new_tiles = target.tile_set
		for cell: Vector2i in layer.get_used_cells():
			var id := layer.get_cell_source_id(cell)
			_check(id == target.get_cell_source_id(cell), "Source identity preserved")
			_check(layer.get_cell_alternative_tile(cell) == target.get_cell_alternative_tile(cell), "Cell flips/transforms preserved")
			var before := layer.tile_set.get_source(id) as TileSetAtlasSource
			var after := target.tile_set.get_source(id) as TileSetAtlasSource
			_check(before.use_texture_padding == after.use_texture_padding, "Renderer padding policy preserved")
			var a := layer.get_cell_atlas_coords(cell)
			var b := target.get_cell_atlas_coords(cell)
			var key := "%s/%s" % [id, a]
			if not verified.has(key):
				for source in [before, after]:
					var path: String = source.texture.resource_path
					if not decoded.has(path):
						var image: Image = source.texture.get_image()
						image.convert(Image.FORMAT_RGBA8)
						decoded[path] = image
				var first: Image = decoded[before.texture.resource_path]
				var second: Image = decoded[after.texture.resource_path]
				_check(first.get_region(before.get_tile_texture_region(a)).get_data() == second.get_region(after.get_tile_texture_region(b)).get_data(), "Exact tile RGBA preserved")
				var old_data := before.get_tile_data(a, 0)
				var new_data := after.get_tile_data(b, 0)
				for property in old_data.get_property_list():
					if int(property.usage) & PROPERTY_USAGE_STORAGE:
						_check(old_data.get(property.name) == new_data.get(property.name), "TileData property preserved: %s" % property.name)
				verified[key] = true
			cells_checked += 1
	_check(cells_checked == 4376 and verified.size() == 325, "Original cell/tile counts preserved")
	_check(new_tiles != null and new_tiles.get_source_count() == 7, "Only seven used sources retained")
	for index in new_tiles.get_source_count():
		var source := new_tiles.get_source(new_tiles.get_source_id(index)) as TileSetAtlasSource
		var texture := source.texture as PortableCompressedTexture2D
		_check(texture != null and texture.get_compression_mode() == PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS, "Portable lossless texture")
		_check(texture.get_width() <= 4096 and texture.get_height() <= 4096, "Browser-safe dimensions")
		_check(ResourceLoader.get_cached_ref(texture.resource_path) == texture, "Embedded compact texture is visible to cached-only diagnostics")
		bytes += texture.get_width() * texture.get_height() * 4
	_check(bytes < 2 * 1024 * 1024, "Compact RGBA estimate below 2 MiB")
	_check_door_parts(old.get_node("Doors"), compact.get_node("Doors"))
	var game_scene := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
	_check(game_scene.contains(COMPACT) and not game_scene.contains(ORIGINAL), "Gameplay uses compact visual")
	old.free()
	compact.free()
	print("PALLET_COMPACT_CHECK ", JSON.stringify({"cells": cells_checked, "tiles": verified.size(),
		"baseRGBABytes": bytes, "success": failures == 0, "realBrowserMeasurement": false}))
	quit(0 if failures == 0 else 1)

func _check_door_parts(before: TileMapLayer, after: TileMapLayer) -> void:
	var script := load("res://scripts/world/map_door_animator.gd")
	var first = script.new()
	var second = script.new()
	first.door_layer = before
	second.door_layer = after
	for cell: Vector2i in before.get_used_cells():
		first.cell_animated_regions[cell] = Rect2(0, 0, 32, 24)
		second.cell_animated_regions[cell] = Rect2(0, 0, 32, 24)
		var old_static := Node2D.new()
		var old_animated := Node2D.new()
		var new_static := Node2D.new()
		var new_animated := Node2D.new()
		first._split_door_cell(cell, old_static, old_animated)
		second._split_door_cell(cell, new_static, new_animated)
		for pair in [[old_static, new_static], [old_animated, new_animated]]:
			_check(pair[0].get_child_count() == pair[1].get_child_count(), "Door piece counts preserved")
			for index in pair[0].get_child_count():
				var a := pair[0].get_child(index) as Sprite2D
				var b := pair[1].get_child(index) as Sprite2D
				_check(a.position == b.position and a.centered == b.centered, "Door piece placement preserved")
				_check(a.texture.get_image().get_region(Rect2i(a.region_rect)).get_data() == b.texture.get_image().get_region(Rect2i(b.region_rect)).get_data(), "Door piece pixels preserved")
		for node: Node in [old_static, old_animated, new_static, new_animated]:
			node.free()
	first.free()
	second.free()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
