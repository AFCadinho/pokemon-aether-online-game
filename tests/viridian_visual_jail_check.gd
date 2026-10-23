extends SceneTree

const VISUAL_SCENE_PATH := "res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn"
const Builder := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_scene_builder.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node = load("res://scripts/world/world.gd").new()
	_check_explicit_sorting(world)
	var visual: Node2D = load(VISUAL_SCENE_PATH).instantiate()
	root.add_child(visual)
	var originals := {}
	for name in ["JailBack", "JailFront", "JailSides", "JailPosts"]:
		var layer := visual.get_node(name) as TileMapLayer
		originals[name] = _cells(layer)
		_check(layer.get_meta("pao_depth_sort", "") == ("rows" if name == "JailSides" else "groups"), name + " carries the authored sorting mode")
	world.call("_normalize_map_depth_layer_z_indices", visual)
	for name: String in originals:
		var layer := visual.get_node(name) as TileMapLayer
		var groups := visual.get_node(name + "DepthGroups")
		var found := {}
		for group: TileMapLayer in groups.get_children():
			for cell in _cells(group):
				_check(not found.has(cell), name + " has no duplicated tiles")
				found[cell] = _cells(group)[cell]
		_check(found == originals[name], name + " retains all tile identities and positions")
		_check(not layer.visible, name + " draws only its runtime groups")
	var back := visual.get_node("JailBackDepthGroups").get_child(0) as TileMapLayer
	var front := visual.get_node("JailFrontDepthGroups").get_child(0) as TileMapLayer
	_check(back.z_index == 1228, "rear ground contact excludes the 20px corner continuation")
	# These are visual sample positions around the walls, not collision requirements.
	_check(1200 + 9 < back.z_index and back.z_index < 1232, "rear wall covers actors north of its visible base, but not the nearest southern tile")
	_check(1424 + 9 < front.z_index and front.z_index < 1456, "front wall covers actors inside and stays behind actors outside")
	_check(back.z_index < front.z_index, "rear and front wall have independent depth")
	var sides := visual.get_node("JailSidesDepthGroups")
	_check(sides.get_child_count() == 3, "side rails have independent row depths")
	for side: TileMapLayer in sides.get_children():
		_check(side.z_index > back.z_index and side.z_index < front.z_index, "side rails sort between the two walls")
	for post: TileMapLayer in visual.get_node("JailPostsDepthGroups").get_children():
		_check(post.z_index == front.z_index, "complete jail posts sort at their feet")
	var child_count := visual.get_child_count()
	world.call("_normalize_map_depth_layer_z_indices", visual)
	_check(visual.get_child_count() == child_count and _cells(visual.get_node("JailBackDepthGroups").get_child(0)) == originals.JailBack,
		"repeat normalization preserves the jail without duplicating geometry")
	visual.free()
	world.free()
	print("Viridian jail visual depth checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_explicit_sorting(world: Node) -> void:
	var map := Node2D.new()
	map.position = Vector2(-48, 160)
	root.add_child(map)
	var layer := TileMapLayer.new()
	layer.name = "CustomRail"
	layer.position = Vector2(16, 32)
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(32, 32)
	map.add_child(layer)
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	layer.set_meta("pao_depth_sort", "rows")
	var rows: Array = world.call("_build_structure_depth_groups", map, layer, cells)
	_check(rows.size() == 3, "explicit row mode splits vertically connected artwork")
	for row: Array[Vector2i] in rows:
		_check(world.call("_get_tile_group_bottom_z_index", layer, row, 0) == 192 + (row[0].y + 1) * 32, "row depth uses the translated world ground position")
	layer.set_meta("pao_depth_sort", "groups")
	_check(world.call("_build_structure_depth_groups", map, layer, cells).size() == 1, "explicit assembly mode keeps a complete object together")
	layer.set_meta("pao_depth_offset_y", -20.0)
	_check(world.call("_get_tile_group_bottom_z_index", layer, cells, 0) == 268, "authored offset changes the sort boundary without moving the layer")
	map.scale = Vector2(2.0, 2.0)
	_check(world.call("_get_tile_group_bottom_z_index", layer, cells, 0) == 376, "ground offset scales with the artwork in world space")
	_check(layer.position == Vector2(16, 32), "ground offset does not move artwork")
	layer.remove_meta("pao_depth_offset_y")
	layer.remove_meta("pao_depth_sort")
	_check(world.call("_build_structure_depth_groups", map, layer, cells).size() == 1, "unconfigured layers preserve connected-group behavior")
	var imported := Builder.new()._create_tile_layer({"name": "UnknownHint", "properties": {"pao_depth_sort": "typo"}}, {}, layer.tile_set, 0, {})
	_check(not imported.has_meta("pao_depth_sort"), "unknown import hint cannot silently enable sorting")
	imported.free()
	map.free()


func _cells(layer: TileMapLayer) -> Dictionary:
	var cells := {}
	for cell: Vector2i in layer.get_used_cells():
		cells[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)]
	return cells


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
