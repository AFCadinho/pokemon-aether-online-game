extends SceneTree

const VISUAL_SCENE := "res://generated/tiled_visuals/open_field/open_field.visual.tscn"

var failed := false


func _init() -> void:
	var packed_scene := load(VISUAL_SCENE) as PackedScene
	_check_true(packed_scene != null, "Open Field visual scene loads")
	if packed_scene == null:
		quit(1)
		return

	var root := packed_scene.instantiate()
	_check_true(root != null, "Open Field visual scene instantiates")
	if root != null:
		_check_visual(root)
		root.free()

	quit(1 if failed else 0)


func _check_visual(root: Node) -> void:
	_check_equal(root.name, "OpenField", "root name")
	_check_true(bool(root.get_meta("pao_generated_visual", false)), "root is marked as generated visual")

	var map_metadata := root.get_meta("tiled_visual_map", {}) as Dictionary
	_check_equal(int(map_metadata.get("width", -1)), 24, "map width")
	_check_equal(int(map_metadata.get("height", -1)), 18, "map height")
	_check_equal(int(map_metadata.get("tile_width", -1)), 32, "tile width")
	_check_equal(int(map_metadata.get("tile_height", -1)), 32, "tile height")
	_check_equal(str(map_metadata.get("orientation", "")), "orthogonal", "map orientation")

	_check_equal(root.get_child_count(), 2, "visual layer count")
	var ground := root.get_node_or_null("Ground") as TileMapLayer
	var road := root.get_node_or_null("Road") as TileMapLayer
	_check_true(ground != null, "Ground layer exists")
	_check_true(road != null, "Road layer exists")
	if ground == null or road == null:
		return

	_check_equal(ground.z_index, 0, "Ground z order")
	_check_equal(road.z_index, 1, "Road z order")
	_check_equal(ground.get_used_cells().size(), 24 * 18, "Ground cell count")
	_check_equal(road.get_used_cells().size(), 4 * 18, "Road cell count")
	_check_true(ground.tile_set != null, "Ground tileset is assigned")
	_check_true(road.tile_set == ground.tile_set, "visual layers share the generated tileset")
	_check_true(ground.get_cell_source_id(Vector2i(0, 0)) >= 0, "Ground origin contains a tile")
	_check_true(road.get_cell_source_id(Vector2i(10, 0)) >= 0, "Road begins at column 10")
	_check_equal(road.get_cell_source_id(Vector2i(9, 0)), -1, "column before Road is empty")
	_check_equal(road.get_cell_source_id(Vector2i(14, 0)), -1, "column after Road is empty")


func _check_true(value: bool, label: String) -> void:
	if value:
		return

	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
