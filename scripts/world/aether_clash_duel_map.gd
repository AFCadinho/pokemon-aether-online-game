extends Node2D

const VISUAL_PATH := ^"ClanWarsMapX1Jail"
const OBJECTS_TOP_PATH := ^"ClanWarsMapX1Jail/ObjectsTop"
const JAIL_BARS_LAYER_NAME := "JailBarsTop"
const JAIL_BARS_RECT := Rect2i(66, 71, 9, 3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_split_jail_bars_for_depth_sorting()


func _ready() -> void:
	_split_jail_bars_for_depth_sorting()


func _split_jail_bars_for_depth_sorting() -> void:
	var visual := get_node_or_null(VISUAL_PATH)
	var objects_top := get_node_or_null(OBJECTS_TOP_PATH) as TileMapLayer
	if visual == null or objects_top == null or visual.get_node_or_null(JAIL_BARS_LAYER_NAME) != null:
		return

	var jail_bars := TileMapLayer.new()
	jail_bars.name = JAIL_BARS_LAYER_NAME
	jail_bars.tile_set = objects_top.tile_set
	jail_bars.position = objects_top.position
	jail_bars.z_index = objects_top.z_index
	jail_bars.z_as_relative = objects_top.z_as_relative
	jail_bars.visible = objects_top.visible
	jail_bars.modulate = objects_top.modulate
	jail_bars.self_modulate = objects_top.self_modulate
	jail_bars.set_meta("tiled_name", JAIL_BARS_LAYER_NAME)
	jail_bars.set_meta("tiled_visual_layer", true)
	visual.add_child(jail_bars)

	var moved_cell_count := 0
	for y in range(JAIL_BARS_RECT.position.y, JAIL_BARS_RECT.end.y):
		for x in range(JAIL_BARS_RECT.position.x, JAIL_BARS_RECT.end.x):
			var cell := Vector2i(x, y)
			var source_id := objects_top.get_cell_source_id(cell)
			if source_id == -1:
				continue
			jail_bars.set_cell(
				cell,
				source_id,
				objects_top.get_cell_atlas_coords(cell),
				objects_top.get_cell_alternative_tile(cell)
			)
			objects_top.erase_cell(cell)
			moved_cell_count += 1

	if moved_cell_count == 0:
		jail_bars.queue_free()
