# Read-only block-1 investigation. No ResourceSaver, image writes or gameplay.
extends SceneTree

const SCENE := "res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load(SCENE)
	assert(scene != null)
	var root := scene.instantiate()
	var layers: Array = []
	_collect(root, layers)
	var used := {}
	var transformed_cells := 0
	var tile_set: TileSet
	var layer_rows: Array = []
	for layer: TileMapLayer in layers:
		assert(layer.tile_set != null)
		if tile_set == null:
			tile_set = layer.tile_set
		assert(layer.tile_set == tile_set)
		var cells := layer.get_used_cells()
		layer_rows.append({"layer": layer.name, "cells": cells.size()})
		for cell: Vector2i in cells:
			if layer.get_cell_alternative_tile(cell) != 0:
				transformed_cells += 1
			var source_id := layer.get_cell_source_id(cell)
			var coords := layer.get_cell_atlas_coords(cell)
			if not used.has(source_id):
				used[source_id] = {}
			used[source_id][coords] = true
	var rows: Array = []
	var total_defined := 0
	var total_used := 0
	var total_rgba := 0
	var total_regions := 0
	var total_frames := 0
	var total_animated := 0
	var defined_animated := 0
	var bbox_rgba := 0
	for index in tile_set.get_source_count():
		var id := tile_set.get_source_id(index)
		var source := tile_set.get_source(id) as TileSetAtlasSource
		assert(source != null and source.texture != null)
		for tile_index in source.get_tiles_count():
			if source.get_tile_animation_frames_count(source.get_tile_id(tile_index)) > 1:
				defined_animated += 1
		var coords_used: Dictionary = used.get(id, {})
		var regions := {}
		var frames := 0
		var animated := 0
		var bounds := Rect2i()
		var first := true
		for coords: Vector2i in coords_used:
			assert(source.has_tile(coords))
			var count := source.get_tile_animation_frames_count(coords)
			assert(count >= 1)
			frames += count
			if count > 1:
				animated += 1
			for frame in count:
				var region := source.get_tile_texture_region(coords, frame)
				assert(region.size == Vector2i(32, 32))
				assert(Rect2i(Vector2i.ZERO, source.texture.get_size()).encloses(region))
				regions[region] = true
				bounds = region if first else bounds.merge(region)
				first = false
		var rgba := source.texture.get_width() * source.texture.get_height() * 4
		var bounding_bytes := bounds.get_area() * 4
		rows.append({"sourceId": id, "width": source.texture.get_width(), "height": source.texture.get_height(),
			"definedTiles": source.get_tiles_count(), "usedTiles": coords_used.size(), "animatedUsedTiles": animated,
			"referencedFrames": frames, "distinct32pxRegions": regions.size(), "baseRGBABytes": rgba,
			"boundingCropRGBABytes": bounding_bytes})
		total_defined += source.get_tiles_count()
		total_used += coords_used.size()
		total_rgba += rgba
		total_regions += regions.size()
		total_frames += frames
		total_animated += animated
		bbox_rgba += bounding_bytes
	root.free()
	print("PALLET_ATLAS_USAGE ", JSON.stringify({"scene": SCENE, "layers": layer_rows, "sources": rows,
		"sceneSHA256": FileAccess.get_sha256(SCENE), "transformedCells": transformed_cells,
		"definedAnimatedTiles": defined_animated,
		"definedTiles": total_defined, "usedTiles": total_used, "animatedUsedTiles": total_animated,
		"referencedFrames": total_frames, "distinct32pxRegions": total_regions, "baseRGBABytes": total_rgba,
		"usedRegionRGBABytes": total_regions * 32 * 32 * 4, "boundingCropRGBABytes": bbox_rgba,
		"limits": ["Read-only generated visual scene analysis, not a compaction implementation",
			"RGBA estimates are not live GPU/RAM measurements", "Packing needs padding and coordinate remapping",
			"Runtime-generated or dynamically selected tiles require separate dependency review"]}))
	quit(0)

func _collect(node: Node, layers: Array) -> void:
	if node is TileMapLayer:
		layers.append(node)
	for child: Node in node.get_children():
		_collect(child, layers)
