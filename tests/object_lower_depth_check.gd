extends SceneTree

const Lower := preload("res://scripts/world/object_lower_depth_sorting.gd")
const TreeLower := preload("res://scripts/world/tree_lower_depth_sorting.gd")
const VISUAL := "res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn"
var artwork: Node
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	artwork = load(VISUAL).instantiate()
	_check_layer_aliases()
	_check_jail_sides()
	_check_guards()
	_check_real_visual()
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(world.contains("ObjectLowerDepthSortingScript.build_depth_layers(structure_layer, group_root)"),
		"world normalization applies object lower depth after final crown groups")
	artwork.free()
	print("Object lower depth checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _fixture(name: String, anchor := Vector2i(25, 8)) -> Dictionary:
	var map := Node2D.new()
	map.position = Vector2(-80, 112)
	map.scale = Vector2(1.25, 1.25)
	root.add_child(map)
	var top := TileMapLayer.new()
	top.name = "ObjectsTop"
	top.tile_set = (artwork.get_node("StructureTop") as TileMapLayer).tile_set
	top.position = Vector2(64, -32)
	map.add_child(top)
	var bottom := TileMapLayer.new()
	bottom.name = name
	bottom.set_meta("tiled_name", name)
	bottom.tile_set = top.tile_set
	bottom.transform = top.transform
	bottom.modulate = Color(0.6, 0.7, 0.8, 0.9)
	bottom.material = CanvasItemMaterial.new()
	bottom.collision_enabled = false
	map.add_child(bottom)
	for row in range(5):
		var source := artwork.get_node("StructureTop" if row < 3 else "StructureBottom") as TileMapLayer
		_copy(source, anchor + Vector2i(0, row), top if row < 3 else bottom, Vector2i(0, row))
	# These two lower-layer details are walkable and not part of the post.
	_copy(artwork.get_node("StructureBottom"), Vector2i(47, 44), bottom, Vector2i(1, 4))
	_copy(artwork.get_node("StructureBottom"), Vector2i(45, 45), bottom, Vector2i(2, 4))
	var groups := Node2D.new()
	map.add_child(groups)
	var group := top.duplicate(0) as TileMapLayer
	group.z_as_relative = false
	group.z_index = 1443
	group.set_meta(Lower.STRUCTURE_GROUP_META, true)
	groups.add_child(group)
	return {"map":map,"top":top,"bottom":bottom,"groups":groups,"group":group}


func _check_layer_aliases() -> void:
	for name in ["ObjectsBottom", "ObjectBottom", "Objects Bottom", "Objects", "StructureBottom"]:
		var f := _fixture(name)
		var top_before := _cells(f.top)
		var before := _cells(f.bottom)
		_check(Lower.build_depth_layers(f.top, f.groups) == 2, name + " moves just the lower shaft and foot")
		var moved := _replacement(f.map)
		_check(moved != null, name + " creates its native depth layer")
		if moved != null:
			_check(moved.z_index == 1443 and not moved.z_as_relative, name + " uses existing absolute upper depth")
			_check(moved.get_index() < f.groups.get_index(), name + " keeps lower parts behind upper overlays")
			_check(moved.tile_set == f.bottom.tile_set and moved.material == f.bottom.material and moved.modulate == f.bottom.modulate,
				name + " shares animation/material resources and preserves tint")
			_check(moved.transform == f.bottom.transform and not moved.collision_enabled, name + " preserves transforms and collision settings")
			_check(not moved.get_meta(TreeLower.DEPTH_LAYER_META, false), name + " remains an object layer rather than a tree layer")
			for cell: Vector2i in moved.get_used_cells():
				_check(_cells(moved)[cell] == before[cell], name + " preserves moved tile identity")
				_check(moved.to_global(moved.map_to_local(cell)) == f.bottom.to_global(f.bottom.map_to_local(cell)),
					name + " keeps tiles in place under map transforms")
		_check(_cells(f.bottom) == {Vector2i(1, 4):before[Vector2i(1, 4)], Vector2i(2, 4):before[Vector2i(2, 4)]},
			name + " leaves stairs and ground details on their original layer")
		_check(_cells(f.top) == top_before and f.group.z_index == 1443, name + " leaves upper geometry and boundaries unchanged")
		var count: int = f.map.get_child_count()
		_check(Lower.build_depth_layers(f.top, f.groups) == 0 and f.map.get_child_count() == count, name + " is idempotent")
		f.map.free()


func _check_jail_sides() -> void:
	for anchor in [Vector2i(45, 40), Vector2i(52, 40)]:
		var f := _fixture("StructureBottom", anchor)
		# The right-hand bars also overlap the lower post's cells in the upper layer.
		if anchor.x == 52:
			for row in [3, 4]:
				_copy(artwork.get_node("StructureTop"), anchor + Vector2i(0, row), f.top, Vector2i(0, row))
				_copy(f.top, Vector2i(0, row), f.group, Vector2i(0, row))
		var before := _cells(f.top)
		_check(Lower.build_depth_layers(f.top, f.groups) == 2, "jail side %s moves both lower post cells" % anchor)
		_check(_cells(f.top) == before and _cells(f.group) == before, "jail bars retain their complete upper overlay")
		_check(_replacement(f.map).get_index() < f.groups.get_index(), "jail bars render above the corrected posts")
		f.map.free()


func _check_guards() -> void:
	for scenario in ["missing_cap", "missing_foot", "stairs", "flipped", "different_group", "duplicate", "hidden"]:
		var f := _fixture("ObjectsBottom")
		match scenario:
			"missing_cap":
				f.top.erase_cell(Vector2i.ZERO)
			"missing_foot":
				f.bottom.erase_cell(Vector2i(0, 4))
			"stairs":
				_copy(f.bottom, Vector2i(1, 4), f.bottom, Vector2i(0, 4))
			"flipped":
				var cell := Vector2i(0, 4)
				f.bottom.set_cell(cell, f.bottom.get_cell_source_id(cell), f.bottom.get_cell_atlas_coords(cell), TileSetAtlasSource.TRANSFORM_FLIP_H)
			"different_group":
				f.group.erase_cell(Vector2i(0, 2))
			"duplicate":
				f.map.add_child(f.bottom.duplicate(0))
			"hidden":
				f.bottom.visible = false
		var before := _cells(f.bottom)
		_check(Lower.build_depth_layers(f.top, f.groups) == 0, scenario + " object stays put")
		_check(_cells(f.bottom) == before and _replacement(f.map) == null, scenario + " cannot raise unrelated objects")
		f.map.free()


func _check_real_visual() -> void:
	var visual: Node = load(VISUAL).instantiate()
	root.add_child(visual)
	var top := visual.get_node("StructureTop") as TileMapLayer
	var bottom := visual.get_node("StructureBottom") as TileMapLayer
	var before := _cells(bottom)
	var top_before := _cells(top)
	var objects_before := _cells(visual.get_node("Objects"))
	var groups := Node2D.new()
	visual.add_child(groups)
	var group := top.duplicate(0) as TileMapLayer
	group.z_as_relative = false
	group.z_index = 1443
	group.set_meta(Lower.STRUCTURE_GROUP_META, true)
	groups.add_child(group)
	_check(Lower.build_depth_layers(top, groups) == 36, "Viridian's 18 complete lantern/post assemblies move 36 lower cells")
	_check(_cells(top) == top_before and _cells(visual.get_node("Objects")) == objects_before, "Viridian's other object artwork is unchanged")
	var moved := _replacement(visual)
	if moved != null:
		_check(bottom.get_used_cells().size() + moved.get_used_cells().size() == before.size(), "Viridian keeps every lower visual cell exactly once")
		for cell in [Vector2i(45, 43), Vector2i(45, 44), Vector2i(52, 43), Vector2i(52, 44)]:
			_check(moved.get_cell_source_id(cell) >= 0 and bottom.get_cell_source_id(cell) == -1, "jail lower post %s is depth sorted" % cell)
		for cell in [Vector2i(47, 44), Vector2i(47, 45), Vector2i(45, 45), Vector2i(52, 45)]:
			_check(_cells(bottom)[cell] == before[cell], "jail walkable detail %s is preserved" % cell)
	visual.free()


func _copy(source: TileMapLayer, cell: Vector2i, target: TileMapLayer, point: Vector2i) -> void:
	target.set_cell(point, source.get_cell_source_id(cell), source.get_cell_atlas_coords(cell), source.get_cell_alternative_tile(cell))


func _cells(layer: TileMapLayer) -> Dictionary:
	var cells := {}
	for cell: Vector2i in layer.get_used_cells():
		cells[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)]
	return cells


func _replacement(node: Node) -> TileMapLayer:
	for child: Node in node.get_children():
		if child is TileMapLayer and child.get_meta(Lower.DEPTH_LAYER_META, false):
			return child as TileMapLayer
	return null


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
