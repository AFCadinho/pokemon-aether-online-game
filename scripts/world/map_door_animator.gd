extends Node

@export var visual_root_path: NodePath
@export var door_layer_name := ""
@export var door_cover_layer_names: PackedStringArray = []
@export var open_offset := Vector2(10.0, 0.0)
@export_range(0.0, 1.0, 0.01) var tween_seconds := 0.16
@export var opening_color := Color(0.025, 0.035, 0.055, 1.0)
@export var cell_animated_regions: Dictionary = {}
@export var cell_opening_regions: Dictionary = {}
@export var animate_all_door_groups := false
@export var composite_door_definitions: Array[DoorVisualDefinition] = []

var door_layer: TileMapLayer
var door_groups: Array[Dictionary] = []
var door_tweens: Dictionary = {}


func _ready() -> void:
	_setup_door_animation_groups()
	_setup_composite_doors()


func _process(_delta: float) -> void:
	_update_door_animation_state()


func _setup_door_animation_groups() -> void:
	if door_layer_name.is_empty():
		return
	var visuals := get_node_or_null(visual_root_path)
	if visuals == null:
		return
	door_layer = visuals.get_node_or_null(door_layer_name) as TileMapLayer
	if door_layer == null:
		return

	var door_z_index := door_layer.z_index
	for cover_layer_name: String in door_cover_layer_names:
		var cover_layer := visuals.get_node_or_null(cover_layer_name) as TileMapLayer
		if cover_layer != null and cover_layer.z_index > door_z_index:
			door_z_index = mini(door_z_index, cover_layer.z_index - 1)

	var groups := _build_door_cell_groups(door_layer.get_used_cells())
	for group_index in range(groups.size()):
		var cells: Array[Vector2i] = groups[group_index]
		if animate_all_door_groups or _group_has_partial_regions(cells):
			_create_partial_door_group(visuals, group_index, cells, door_z_index)


func _group_has_partial_regions(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if cell_animated_regions.has(cell):
			return true
	return false


func _create_partial_door_group(visuals: Node, group_index: int, cells: Array[Vector2i], door_z_index: int) -> void:
	var group_id := door_groups.size()
	var opening_parts := Node2D.new()
	opening_parts.name = "DoorOpening%d" % group_index
	opening_parts.z_as_relative = door_layer.z_as_relative
	opening_parts.z_index = door_z_index
	visuals.add_child(opening_parts)
	var static_parts := Node2D.new()
	static_parts.name = "DoorFrame%d" % group_index
	static_parts.z_as_relative = door_layer.z_as_relative
	static_parts.z_index = door_z_index
	static_parts.modulate = door_layer.modulate
	visuals.add_child(static_parts)
	var animated_parts := Node2D.new()
	animated_parts.name = "AnimatedDoor%d" % group_index
	animated_parts.z_as_relative = door_layer.z_as_relative
	animated_parts.z_index = door_z_index
	animated_parts.modulate = door_layer.modulate
	visuals.add_child(animated_parts)
	for cell: Vector2i in cells:
		_add_partial_door_opening(cell, opening_parts)
		_split_door_cell(cell, static_parts, animated_parts)
		door_layer.erase_cell(cell)
	door_groups.append({"id": group_id, "cells": cells, "layer": animated_parts, "closed_position": animated_parts.position, "open": false})


func _add_partial_door_opening(cell: Vector2i, opening_parts: Node2D) -> void:
	if opening_color.a <= 0.0:
		return
	var tile_size := Vector2(door_layer.tile_set.tile_size)
	var animated_region := _get_animated_region(cell, tile_size)
	var configured_region: Variant = cell_opening_regions.get(cell, animated_region)
	var opening_region := (configured_region as Rect2).intersection(Rect2(Vector2.ZERO, tile_size))
	if opening_region.size.x <= 0.0 or opening_region.size.y <= 0.0:
		return
	var top_left := door_layer.map_to_local(cell) - tile_size * 0.5 + opening_region.position
	var opening := Polygon2D.new()
	opening.color = opening_color
	opening.polygon = PackedVector2Array([
		top_left,
		Vector2(top_left.x + opening_region.size.x, top_left.y),
		top_left + opening_region.size,
		Vector2(top_left.x, top_left.y + opening_region.size.y),
	])
	opening_parts.add_child(opening)


func _setup_composite_doors() -> void:
	var visuals := get_node_or_null(visual_root_path)
	if visuals == null:
		return
	for definition: DoorVisualDefinition in composite_door_definitions:
		if definition == null or definition.source_cells.is_empty() or definition.panel_bounds.size == Vector2.ZERO:
			continue
		var source_layer := visuals.get_node_or_null(definition.source_layer_name) as TileMapLayer
		if source_layer == null:
			continue
		var group_id := door_groups.size()
		_create_composite_opening(visuals, source_layer, definition, group_id)
		var static_parts := Node2D.new()
		static_parts.name = "CompositeDoorFrame%d" % group_id
		static_parts.z_as_relative = source_layer.z_as_relative
		static_parts.z_index = source_layer.z_index
		static_parts.modulate = source_layer.modulate
		visuals.add_child(static_parts)
		var animated_parts := Node2D.new()
		animated_parts.name = "CompositeDoorPanel%d" % group_id
		animated_parts.z_as_relative = source_layer.z_as_relative
		animated_parts.z_index = source_layer.z_index
		animated_parts.modulate = source_layer.modulate
		visuals.add_child(animated_parts)
		var fallback_source := _get_first_atlas_source(source_layer, definition.source_cells)
		for cell: Vector2i in definition.source_cells:
			_split_composite_cell(source_layer, cell, definition, fallback_source, static_parts, animated_parts)
			source_layer.erase_cell(cell)
		if not definition.overlay_layer_name.is_empty():
			var overlay_layer := visuals.get_node_or_null(definition.overlay_layer_name) as TileMapLayer
			if overlay_layer != null:
				for overlay_cell: Vector2i in definition.overlay_cells_to_erase:
					overlay_layer.erase_cell(overlay_cell)
		door_groups.append({
			"id": group_id,
			"cells": definition.source_cells,
			"trigger_cell": definition.trigger_cell,
			"layer": animated_parts,
			"closed_position": animated_parts.position,
			"open_offset": definition.open_offset,
			"tween_seconds": definition.tween_seconds,
			"open": false,
		})


func _create_composite_opening(visuals: Node, source_layer: TileMapLayer, definition: DoorVisualDefinition, group_id: int) -> void:
	if definition.opening_color.a <= 0.0:
		return
	var opening := Polygon2D.new()
	opening.name = "CompositeDoorOpening%d" % group_id
	opening.z_as_relative = source_layer.z_as_relative
	opening.z_index = source_layer.z_index
	opening.color = definition.opening_color
	opening.polygon = PackedVector2Array([
		definition.panel_bounds.position,
		Vector2(definition.panel_bounds.end.x, definition.panel_bounds.position.y),
		definition.panel_bounds.end,
		Vector2(definition.panel_bounds.position.x, definition.panel_bounds.end.y),
	])
	visuals.add_child(opening)


func _get_first_atlas_source(source_layer: TileMapLayer, cells: Array[Vector2i]) -> TileSetAtlasSource:
	for cell: Vector2i in cells:
		var source_id := source_layer.get_cell_source_id(cell)
		if source_id >= 0:
			return source_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	return null


func _split_composite_cell(source_layer: TileMapLayer, cell: Vector2i, definition: DoorVisualDefinition, fallback_source: TileSetAtlasSource, static_parts: Node2D, animated_parts: Node2D) -> void:
	var source_id := source_layer.get_cell_source_id(cell)
	var source := source_layer.tile_set.get_source(source_id) as TileSetAtlasSource if source_id >= 0 else fallback_source
	if source == null:
		return
	var atlas_coords := source_layer.get_cell_atlas_coords(cell)
	if source_id < 0:
		if not definition.synthetic_atlas_cells.has(cell):
			return
		atlas_coords = definition.synthetic_atlas_cells.get(cell) as Vector2i
	var tile_size := Vector2(source_layer.tile_set.tile_size)
	var cell_top_left := source_layer.map_to_local(cell) - tile_size * 0.5
	var cell_bounds := Rect2(cell_top_left, tile_size)
	var panel_intersection := cell_bounds.intersection(definition.panel_bounds)
	var tile_region := source.get_tile_texture_region(atlas_coords)
	if panel_intersection.size == Vector2.ZERO:
		_add_tile_piece(static_parts, source.texture, tile_region, Rect2(Vector2.ZERO, tile_size), cell_top_left)
		return
	var local_panel := Rect2(panel_intersection.position - cell_top_left, panel_intersection.size)
	for static_region: Rect2 in _get_static_regions(tile_size, local_panel):
		_add_tile_piece(static_parts, source.texture, tile_region, static_region, cell_top_left)
	_add_tile_piece(animated_parts, source.texture, tile_region, local_panel, cell_top_left)


func _split_door_cell(cell: Vector2i, static_parts: Node2D, animated_parts: Node2D) -> void:
	var source := door_layer.tile_set.get_source(door_layer.get_cell_source_id(cell)) as TileSetAtlasSource
	if source == null:
		return
	var tile_size := Vector2(door_layer.tile_set.tile_size)
	var tile_region := source.get_tile_texture_region(door_layer.get_cell_atlas_coords(cell))
	var animated_region := _get_animated_region(cell, tile_size)
	var cell_top_left := door_layer.map_to_local(cell) - tile_size * 0.5
	for static_region: Rect2 in _get_static_regions(tile_size, animated_region):
		_add_tile_piece(static_parts, source.texture, tile_region, static_region, cell_top_left)
	_add_tile_piece(animated_parts, source.texture, tile_region, animated_region, cell_top_left)


func _get_animated_region(cell: Vector2i, tile_size: Vector2) -> Rect2:
	var configured_region: Variant = cell_animated_regions.get(cell, Rect2(Vector2.ZERO, tile_size))
	return (configured_region as Rect2).intersection(Rect2(Vector2.ZERO, tile_size))


func _get_static_regions(tile_size: Vector2, animated_region: Rect2) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if animated_region.position.y > 0.0:
		regions.append(Rect2(0.0, 0.0, tile_size.x, animated_region.position.y))
	if animated_region.end.y < tile_size.y:
		regions.append(Rect2(0.0, animated_region.end.y, tile_size.x, tile_size.y - animated_region.end.y))
	if animated_region.position.x > 0.0:
		regions.append(Rect2(0.0, animated_region.position.y, animated_region.position.x, animated_region.size.y))
	if animated_region.end.x < tile_size.x:
		regions.append(Rect2(animated_region.end.x, animated_region.position.y, tile_size.x - animated_region.end.x, animated_region.size.y))
	return regions


func _add_tile_piece(parent: Node2D, texture: Texture2D, tile_region: Rect2, piece_region: Rect2, cell_top_left: Vector2) -> void:
	if piece_region.size.x <= 0.0 or piece_region.size.y <= 0.0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(tile_region.position + piece_region.position, piece_region.size)
	sprite.centered = false
	sprite.position = cell_top_left + piece_region.position
	parent.add_child(sprite)


func _build_door_cell_groups(cells: Array[Vector2i]) -> Array[Array]:
	var remaining := {}
	for cell: Vector2i in cells:
		remaining[cell] = true
	var groups: Array[Array] = []
	for start_cell: Vector2i in cells:
		if not remaining.has(start_cell):
			continue
		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_cell]
		remaining.erase(start_cell)
		while not queue.is_empty():
			var current := queue.pop_front() as Vector2i
			group.append(current)
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + offset
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					queue.append(neighbor)
		groups.append(group)
	return groups


func _update_door_animation_state() -> void:
	if door_layer == null or door_groups.is_empty():
		return
	var player := _get_local_player()
	if player == null:
		_close_all_door_groups()
		return
	var feet_position: Vector2 = player.call("get_feet_position") if player.has_method("get_feet_position") else player.global_position
	var player_cell := door_layer.local_to_map(door_layer.to_local(feet_position))
	for group: Dictionary in door_groups:
		var is_open := _is_player_in_front_of_door_group(player_cell, group)
		if is_open != bool(group.get("open", false)):
			_set_door_group_open(group, is_open)


func _get_local_player() -> Node2D:
	var player := get_node_or_null("../Entities/Players/Player") as Node2D
	if player != null:
		return player
	var tree := get_tree()
	if tree == null:
		return null
	for player_value: Variant in tree.get_nodes_in_group("player"):
		var candidate := player_value as Node2D
		if candidate != null and get_parent().is_ancestor_of(candidate):
			return candidate
	return null


func _is_player_in_front_of_door_group(player_cell: Vector2i, group: Dictionary) -> bool:
	if group.has("trigger_cell"):
		var trigger_cell := group.get("trigger_cell") as Vector2i
		return player_cell == trigger_cell
	var cells: Array = group.get("cells", [])
	if cells.is_empty():
		return false
	var bottom_y := -2147483648
	for cell: Vector2i in cells:
		bottom_y = maxi(bottom_y, cell.y)
	for cell: Vector2i in cells:
		if cell.y == bottom_y and player_cell == cell + Vector2i.DOWN:
			return true
	return false


func _close_all_door_groups() -> void:
	for group: Dictionary in door_groups:
		if bool(group.get("open", false)):
			_set_door_group_open(group, false)


func _set_door_group_open(group: Dictionary, is_open: bool) -> void:
	group["open"] = is_open
	var group_id := int(group.get("id", -1))
	var layer := group.get("layer") as Node2D
	if layer == null:
		return
	var previous_tween := door_tweens.get(group_id) as Tween
	if previous_tween != null:
		previous_tween.kill()
	var closed_position := group.get("closed_position", layer.position) as Vector2
	var resolved_offset: Vector2 = group.get("open_offset", open_offset)
	var resolved_seconds := float(group.get("tween_seconds", tween_seconds))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(layer, "position", closed_position + (resolved_offset if is_open else Vector2.ZERO), resolved_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer, "modulate:a", 0.0 if is_open else 1.0, resolved_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	door_tweens[group_id] = tween
