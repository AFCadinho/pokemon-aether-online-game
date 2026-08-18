extends SceneTree

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const MAP_SCENES: Array[String] = [
	"res://generated/tiled_visuals/route_1/route_1.visual.tscn",
	"res://generated/tiled_visuals/kanto_route_2/kanto_route_2.visual.tscn",
	"res://generated/tiled_visuals/route_3/route_3.visual.tscn",
	"res://generated/tiled_visuals/viridian_forest/viridian_forest.visual.tscn",
	"res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn",
]
const MAX_CHARACTER_RELATIVE_Z := 11
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096

var failed := false


func _init() -> void:
	_check(
		TallGrassDepthSortingScript.FOREGROUND_Z_OFFSET > MAX_CHARACTER_RELATIVE_Z,
		"same-row grass renders above every player and follower visual layer"
	)
	_check(
		TallGrassDepthSortingScript.FOREGROUND_Z_OFFSET < 32,
		"grass remains below a character standing one tile row farther south"
	)

	for scene_path: String in MAP_SCENES:
		var packed_scene := load(scene_path) as PackedScene
		var map := packed_scene.instantiate()
		var grass_layer := _find_grass_layer(map)
		if grass_layer == null:
			_check(false, "visual grass layer exists in %s" % scene_path)
			map.free()
			continue

		var used_cells := grass_layer.get_used_cells()
		var checked_rows: Dictionary = {}
		for cell: Vector2i in used_cells:
			if checked_rows.has(cell.y):
				continue
			checked_rows[cell.y] = true
			_check_grass_row_depth(grass_layer, cell.y, scene_path)
		map.free()

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("TallGrassDepthSortingScript.get_row_z_index("),
		"world map normalization uses the tested tall-grass depth calculation"
	)
	quit(1 if failed else 0)


func _check_grass_row_depth(grass_layer: TileMapLayer, row: int, scene_path: String) -> void:
	var tile_size := Vector2(grass_layer.tile_set.tile_size)
	var row_center := grass_layer.map_to_local(Vector2i(0, row))
	var row_bottom_y := floori(grass_layer.to_global(
		row_center + Vector2(0.0, tile_size.y * 0.5)
	).y)
	var row_z := TallGrassDepthSortingScript.get_row_z_index(
		grass_layer,
		row,
		SORT_Z_MIN,
		SORT_Z_MAX
	)
	_check(
		row_z > row_bottom_y + MAX_CHARACTER_RELATIVE_Z,
		"%s grass row %d covers a character standing in that row" % [scene_path, row]
	)
	_check(
		row_z < row_bottom_y + int(tile_size.y),
		"%s grass row %d stays behind the next character row" % [scene_path, row]
	)


func _find_grass_layer(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		var tiled_name := str(layer.get_meta("tiled_name", layer.name))
		if tiled_name in ["TallGrassVisual", "Grass"]:
			return layer
	for child: Node in node.get_children():
		var found := _find_grass_layer(child)
		if found != null:
			return found
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
