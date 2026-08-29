extends SceneTree

const TallGrassDepthSortingScript := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const MapDepthSortingScript := preload("res://scripts/world/map_depth_sorting.gd")

const MAP_SCENE_PATH := "res://scenes/overworld/kanto/routes/viridian_forest.tscn"
const VISUAL_SCENE_PATH := "res://generated/tiled_visuals/viridian_forest/viridian_forest.visual.tscn"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const ITEM_POSITIONS := {
	"PokeBall": Vector2(1264, 1648),
	"Antidote": Vector2(1264, 1520),
	"Potion": Vector2(2064, 1840),
	"Potion2": Vector2(560, 816),
}

var failed := false


func _init() -> void:
	var packed := load(VISUAL_SCENE_PATH) as PackedScene
	_check(packed != null, "Viridian Forest visual scene loads")
	if packed == null:
		quit(1)
		return

	var map := Node2D.new()
	var visual := packed.instantiate()
	map.add_child(visual)
	var grass := visual.get_node_or_null("Grass") as TileMapLayer
	var ground_detail := visual.get_node_or_null("GroundDetail") as TileMapLayer
	var objects_top := visual.get_node_or_null("ObjectsTop") as TileMapLayer
	_check(grass != null and ground_detail != null and objects_top != null, "Viridian Forest exposes its depth layers")

	var map_source := FileAccess.get_file_as_string(MAP_SCENE_PATH)
	_check(
		map_source.contains('[node name="Entities" type="Node2D" parent="." unique_id=1962237010]\nz_index = 5'),
		"items render above GroundDetail"
	)
	if ground_detail != null:
		for item_name_value: Variant in ITEM_POSITIONS:
			var item_name := str(item_name_value)
			var item_position: Vector2 = ITEM_POSITIONS[item_name_value]
			_check(map_source.contains('[node name="%s" parent="Entities/Interactables"' % item_name), "%s exists" % item_name)
			var cell := ground_detail.local_to_map(ground_detail.to_local(item_position))
			_check(ground_detail.get_cell_source_id(cell) >= 0, "%s overlaps GroundDetail" % item_name)

	if grass != null and objects_top != null:
		_check_objects_top_grass_priority(map, grass, objects_top)

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("MapDepthSortingScript.get_tall_grass_overlap_z_floor("),
		"world normalization applies the tested grass-overlap floor"
	)
	map.free()
	quit(1 if failed else 0)


func _check_objects_top_grass_priority(
	map: Node,
	grass: TileMapLayer,
	objects_top: TileMapLayer
) -> void:
	var row_group := TallGrassDepthSortingScript.build_depth_rows(
		grass,
		grass.get_used_cells(),
		SORT_Z_MIN,
		SORT_Z_MAX,
		false,
		"GrassDepthRows"
	)
	_check(row_group != null, "Viridian Forest grass depth rows are built")
	if row_group == null:
		return

	var overlap_count := 0
	for overlap_cell: Vector2i in grass.get_used_cells():
		if objects_top.get_cell_source_id(overlap_cell) < 0:
			continue
		overlap_count += 1
		var overlap_position := objects_top.to_global(objects_top.map_to_local(overlap_cell))
		var grass_match := TallGrassDepthSortingScript.find_depth_row_at_global_position(
			map,
			overlap_position
		)
		var grass_row := grass_match.get("layer") as TileMapLayer
		_check(grass_row != null, "overlapping grass row %s is depth sorted" % overlap_cell)
		if grass_row == null:
			continue

		var structure_floor := MapDepthSortingScript.get_tall_grass_overlap_z_floor(
			map,
			objects_top,
			[overlap_cell],
			SORT_Z_MIN,
			SORT_Z_MAX
		)
		_check(
			structure_floor > grass_row.z_index,
			"ObjectsTop remains above overlapping grass at %s" % overlap_cell
		)
	_check(overlap_count == 104, "all 104 Viridian Forest Grass/ObjectsTop overlaps are covered")


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
