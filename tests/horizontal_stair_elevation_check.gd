extends SceneTree

const HorizontalStairElevationScript := preload(
	"res://scripts/world/horizontal_stair_elevation.gd"
)

var failed := false


func _init() -> void:
	_check_directional_markers()
	_check_visual_curve()
	quit(1 if failed else 0)


func _check_directional_markers() -> void:
	var map_root := Node2D.new()
	root.add_child(map_root)
	var up_left := _make_marker_layer("StairUpLeft", Vector2i(2, 3))
	map_root.add_child(up_left)
	var up_left_position := up_left.to_global(up_left.map_to_local(Vector2i(2, 3)))

	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_left_position,
			Vector2.LEFT
		) == HorizontalStairElevationScript.ELEVATION_UP,
		"StairUpLeft climbs while walking left"
	)
	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_left_position,
			Vector2.RIGHT
		) == HorizontalStairElevationScript.ELEVATION_DOWN,
		"StairUpLeft descends while walking right"
	)
	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_left_position,
			Vector2.UP
		) == HorizontalStairElevationScript.ELEVATION_NONE,
		"vertical movement never receives a horizontal stair effect"
	)
	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_left_position + Vector2.RIGHT * 32.0,
			Vector2.RIGHT
		) == HorizontalStairElevationScript.ELEVATION_NONE,
		"the unmarked landing tile does not need a duplicate stair marker"
	)

	up_left.name = "UnusedMarker"
	var up_right := _make_marker_layer("StairsUpRight", Vector2i(4, 1))
	map_root.add_child(up_right)
	var up_right_position := up_right.to_global(up_right.map_to_local(Vector2i(4, 1)))
	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_right_position,
			Vector2.RIGHT
		) == HorizontalStairElevationScript.ELEVATION_UP,
		"StairsUpRight alias climbs while walking right"
	)
	_check(
		HorizontalStairElevationScript.elevation_for_stair_exit(
			map_root,
			up_right_position,
			Vector2.LEFT
		) == HorizontalStairElevationScript.ELEVATION_DOWN,
		"StairsUpRight alias descends while walking left"
	)
	map_root.queue_free()


func _check_visual_curve() -> void:
	_check(
		HorizontalStairElevationScript.visual_offset(
			0.0,
			HorizontalStairElevationScript.ELEVATION_UP
		) == Vector2.ZERO,
		"stair presentation starts on the logical player position"
	)
	_check(
		HorizontalStairElevationScript.visual_offset(
			0.5,
			HorizontalStairElevationScript.ELEVATION_UP
		) == Vector2(0.0, -8.0),
		"ascending presentation lifts the player at mid-step"
	)
	_check(
		HorizontalStairElevationScript.visual_offset(
			0.5,
			HorizontalStairElevationScript.ELEVATION_DOWN
		) == Vector2(0.0, 8.0),
		"descending presentation lowers the player at mid-step"
	)
	_check(
		HorizontalStairElevationScript.visual_offset(
			1.0,
			HorizontalStairElevationScript.ELEVATION_DOWN
		) == Vector2.ZERO,
		"stair presentation ends exactly on the logical player position"
	)


func _make_marker_layer(layer_name: String, cell: Vector2i) -> TileMapLayer:
	var marker_layer := TileMapLayer.new()
	marker_layer.name = layer_name
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(32, 32, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, 0)
	marker_layer.tile_set = tile_set
	marker_layer.set_cell(cell, 0, Vector2i.ZERO)
	return marker_layer


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
