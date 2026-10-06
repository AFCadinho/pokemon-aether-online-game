extends SceneTree

const Lower := preload("res://scripts/world/tree_lower_depth_sorting.gd")
const VISUAL := "res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn"
var failed := false
var artwork: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	artwork = load(VISUAL).instantiate()
	_check_complete_tree()
	_check_guards()
	_check_real_maps()
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(world_source.contains("TreeLowerDepthSortingScript.build_depth_layers(structure_layer, group_root)"),
		"world normalization extends the final crown depth to supported lower parts")
	artwork.free()
	print("Tree lower depth checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _fixture() -> Dictionary:
	var map := Node2D.new()
	map.position = Vector2(100, -80)
	map.scale = Vector2(1.5, 1.5)
	root.add_child(map)
	var top := TileMapLayer.new()
	top.name = "StructureTop"
	top.set_meta("tiled_name", "StructureTop")
	top.tile_set = (artwork.get_node("StructureTop") as TileMapLayer).tile_set
	map.add_child(top)
	var bottom := TileMapLayer.new()
	bottom.name = "TreeBottom"
	bottom.set_meta("tiled_name", "TreeBottom")
	bottom.tile_set = top.tile_set
	bottom.position = Vector2(32, 64)
	top.position = bottom.position
	bottom.modulate = Color(0.7, 0.8, 0.9, 0.6)
	bottom.self_modulate = Color(0.9, 0.9, 0.9, 0.8)
	bottom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bottom.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	bottom.material = CanvasItemMaterial.new()
	bottom.light_mask = 3
	bottom.collision_enabled = false
	bottom.navigation_enabled = false
	map.add_child(bottom)
	for row in range(4):
		var source := artwork.get_node("StructureTop" if row < 2 else "TreeBottom") as TileMapLayer
		var target := top if row < 2 else bottom
		for column in range(2):
			_copy_cell(source, Vector2i(46 + column, 52 + row), target, Vector2i(column, row))
	# An unrelated grass detail on the same bottom layer must stay there.
	_copy_cell(artwork.get_node("TreeBottom"), Vector2i(46, 52), bottom, Vector2i(8, 8))
	var groups := Node2D.new()
	groups.name = "StructureTopDepthGroups"
	map.add_child(groups)
	var group := top.duplicate(0) as TileMapLayer
	group.name = "Crown"
	group.z_as_relative = false
	group.z_index = 777
	group.set_meta(Lower.STRUCTURE_GROUP_META, true)
	groups.add_child(group)
	return {"map":map, "top":top, "bottom":bottom, "groups":groups, "group":group}


func _check_complete_tree() -> void:
	var fixture := _fixture()
	var bottom: TileMapLayer = fixture.bottom
	var group: TileMapLayer = fixture.group
	var before := _cells(bottom)
	var top_before := _cells(fixture.top)
	_check(Lower.build_depth_layers(fixture.top, fixture.groups) == 4, "a complete tree moves its four lower cells")
	var replacement := _replacement(fixture.map)
	_check(replacement != null, "lower depth layer exists")
	if replacement != null:
		_check(replacement.z_index == 777 and not replacement.z_as_relative, "lower parts use the existing absolute crown depth")
		_check(replacement.get_index() < fixture.groups.get_index(), "lower parts draw before overlapping crowns at equal depth")
		_check(replacement.tile_set == bottom.tile_set, "animation sources are shared without reimporting or retiming")
		for property in ["transform", "modulate", "self_modulate", "texture_filter", "texture_repeat", "material", "light_mask", "collision_enabled", "navigation_enabled"]:
			_check(replacement.get(property) == bottom.get(property), "lower layer preserves " + property)
		for cell: Vector2i in replacement.get_used_cells():
			_check(_cells(replacement)[cell] == before[cell], "moved cell retains its tile and alternative")
			_check(replacement.to_global(replacement.map_to_local(cell)) == bottom.to_global(bottom.map_to_local(cell)),
				"translated/scaled map keeps every moved tile in its original position")
			_check(bottom.get_cell_source_id(cell) == -1, "moved cells are not duplicated")
	_check(bottom.get_used_cells() == [Vector2i(8, 8)], "mixed grass stays on its original layer")
	_check(_cells(fixture.top) == top_before and group.z_index == 777, "existing crown geometry and depth stay unchanged")
	var count: int = fixture.map.get_child_count()
	_check(Lower.build_depth_layers(fixture.top, fixture.groups) == 0 and fixture.map.get_child_count() == count,
		"repeated normalization cannot duplicate tree layers")
	fixture.map.free()


func _check_guards() -> void:
	for scenario in ["missing", "flipped", "unknown", "unaligned", "split_groups", "duplicate_bottom", "duplicate_top", "children", "scripted", "scripted_top", "hidden"]:
		var fixture := _fixture()
		var bottom: TileMapLayer = fixture.bottom
		match scenario:
			"missing":
				bottom.erase_cell(Vector2i(1, 3))
			"flipped":
				var cell := Vector2i(0, 2)
				bottom.set_cell(cell, bottom.get_cell_source_id(cell), bottom.get_cell_atlas_coords(cell), TileSetAtlasSource.TRANSFORM_FLIP_H)
			"unknown":
				_copy_cell(bottom, Vector2i(8, 8), bottom, Vector2i(0, 2))
			"unaligned":
				bottom.position.x += 1
			"split_groups":
				var second := fixture.group.duplicate(0) as TileMapLayer
				second.clear()
				_copy_cell(fixture.top, Vector2i(1, 1), second, Vector2i(1, 1))
				fixture.group.erase_cell(Vector2i(1, 1))
				fixture.groups.add_child(second)
			"duplicate_bottom":
				fixture.map.add_child(bottom.duplicate(0))
			"duplicate_top":
				fixture.map.add_child(fixture.top.duplicate(0))
			"children":
				bottom.add_child(Node.new())
			"scripted":
				var behavior := GDScript.new()
				behavior.source_code = "extends TileMapLayer\n"
				behavior.reload()
				bottom.set_script(behavior)
			"scripted_top":
				var behavior := GDScript.new()
				behavior.source_code = "extends TileMapLayer\n"
				behavior.reload()
				fixture.top.set_script(behavior)
			"hidden":
				bottom.visible = false
		var before := _cells(bottom)
		_check(Lower.build_depth_layers(fixture.top, fixture.groups) == 0, scenario + " tree is left alone")
		_check(_cells(bottom) == before and _replacement(fixture.map) == null, scenario + " cannot move unrelated cells")
		fixture.map.free()


func _check_real_maps() -> void:
	# Route 2 has one crown duplicated in Objects; that ambiguous tree stays put.
	for entry in [["viridian_city", 1316], ["kanto_route_2", 120], ["kanto_route_22", 540], ["route_1", 348], ["viridian_forest", 0], ["cerulean_city", 0]]:
		var name: String = entry[0]
		var map: Node = load("res://generated/tiled_visuals/%s/%s.visual.tscn" % [name, name]).instantiate()
		root.add_child(map)
		var original_layers: Array[TileMapLayer] = []
		var snapshots := {}
		var total_before := 0
		for child: Node in map.get_children():
			var layer := child as TileMapLayer
			if layer != null:
				original_layers.append(layer)
				snapshots[layer] = _cells(layer)
				total_before += layer.get_used_cells().size()
		var moved := 0
		for top: TileMapLayer in original_layers:
			if str(top.get_meta("tiled_name",top.name)) not in ["TreeTop", "StructureTop", "StructureTopVisual"]:
				continue
			var groups := Node2D.new()
			map.add_child(groups)
			var group := top.duplicate(0) as TileMapLayer
			group.z_as_relative = false
			group.z_index = 1234
			group.set_meta(Lower.STRUCTURE_GROUP_META, true)
			groups.add_child(group)
			moved += Lower.build_depth_layers(top, groups)
			_check(_cells(top) == snapshots[top], name + " crowns are unchanged")
			groups.free()
		var total_after := 0
		for child: Node in map.get_children():
			var layer := child as TileMapLayer
			if layer != null:
				total_after += layer.get_used_cells().size()
		_check(moved == int(entry[1]), name + " moves only its known complete trees")
		_check(total_after == total_before, name + " preserves the complete visual cell count")
		for layer: TileMapLayer in original_layers:
			if str(layer.get_meta("tiled_name", layer.name)) not in Lower.BOTTOM_LAYER_NAMES:
				_check(_cells(layer) == snapshots[layer], name + " grass and other layers remain unchanged")
		map.free()


func _copy_cell(source: TileMapLayer, cell: Vector2i, target: TileMapLayer, point: Vector2i) -> void:
	target.set_cell(point, source.get_cell_source_id(cell), source.get_cell_atlas_coords(cell), source.get_cell_alternative_tile(cell))


func _cells(layer: TileMapLayer) -> Dictionary:
	var cells := {}
	for cell: Vector2i in layer.get_used_cells():
		cells[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)]
	return cells


func _replacement(map: Node) -> TileMapLayer:
	for child: Node in map.get_children():
		if child is TileMapLayer and child.get_meta(Lower.DEPTH_LAYER_META, false):
			return child as TileMapLayer
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
