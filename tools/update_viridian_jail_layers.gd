# Apply the authored Viridian jail layer split without rebuilding its atlases.
# The existing Godot visual includes native tree animations absent from the TMX.
# Applies the split and the rear ground-contact offset from the paired TMX edit.
extends SceneTree

var failed := false

const SCENE := "res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn"

func _init() -> void:
	var visual: Node = load(SCENE).instantiate()
	if visual.has_node("JailBack"):
		var back := visual.get_node("JailBack") as TileMapLayer
		if float(back.get_meta("pao_depth_offset_y", 0.0)) == -20.0:
			print("Viridian jail layers and ground contact already configured")
			visual.free()
			quit(0)
		else:
			back.set_meta("pao_depth_offset_y", -20.0)
			_save(visual)
		return
	var layers := {}
	var index := visual.get_node("StructureBottom").get_index() + 1
	var first_id := 8
	for name in ["JailBack", "JailSides", "JailPosts", "JailFront"]:
		var layer := TileMapLayer.new()
		layer.name = name
		layer.tile_set = visual.get_node("StructureTop").tile_set
		layer.set_meta("tiled_name", name)
		layer.set_meta("tiled_layer_id", first_id)
		layer.set_meta("tiled_visual_layer", true)
		layer.set_meta("pao_depth_sort", "rows" if name == "JailSides" else "groups")
		if name == "JailBack":
			layer.set_meta("pao_depth_offset_y", -20.0)
		visual.add_child(layer)
		layer.owner = visual
		visual.move_child(layer, index)
		layers[name] = layer
		index += 1
		first_id += 1
	for y in range(36, 39):
		for x in range(46, 52):
			_move(visual, "TreeBottom" if y > 36 and x in range(47, 51) else "StructureTop", layers.JailBack, Vector2i(x, y))
	for y in range(39, 42):
		for x in [46, 51]:
			_move(visual, "StructureTop", layers.JailSides, Vector2i(x, y))
	for y in range(42, 45):
		for x in range(46, 52):
			_move(visual, "StructureTop", layers.JailFront, Vector2i(x, y))
	for y in range(40, 45):
		for x in [45, 52]:
			_move(visual, "StructureTop" if y < 43 else "StructureBottom", layers.JailPosts, Vector2i(x, y))
	if failed:
		visual.free()
		quit(1)
		return
	for layer: TileMapLayer in visual.get_children():
		layer.z_index = layer.get_index()
	_save(visual)


func _save(visual: Node) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(visual)
	if error == OK:
		error = ResourceSaver.save(packed, SCENE)
	visual.free()
	print("Viridian jail layer split: ", error_string(error))
	quit(0 if error == OK else 1)

func _move(visual: Node, source_name: String, target: TileMapLayer, cell: Vector2i) -> void:
	var source := visual.get_node(source_name) as TileMapLayer
	if source.get_cell_source_id(cell) < 0:
		failed = true
		push_error("Missing original jail artwork at %s/%s; output will not be saved" % [source_name, cell])
		return
	target.set_cell(cell, source.get_cell_source_id(cell), source.get_cell_atlas_coords(cell), source.get_cell_alternative_tile(cell))
	source.erase_cell(cell)
