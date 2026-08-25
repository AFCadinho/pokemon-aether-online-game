extends Node2D

const DEFAULT_TILE_SIZE := Vector2(32.0, 32.0)
const RUSTLE_Z_OFFSET := 2
const RUSTLE_DISTANCE := 2.0


static func get_render_z_index(
	tilemap: TileMapLayer,
	tile_position: Vector2i,
	tile_size: Vector2
) -> int:
	if bool(tilemap.get_meta("pao_tall_grass_depth_row", false)):
		return mini(tilemap.z_index + 1, RenderingServer.CANVAS_ITEM_Z_MAX)
	return floori(tilemap.to_global(
		tilemap.map_to_local(tile_position) + Vector2(0.0, tile_size.y * 0.5)
	).y) + RUSTLE_Z_OFFSET


func play(tilemap: TileMapLayer, tile_position: Vector2i) -> void:
	if tilemap == null or tilemap.tile_set == null:
		queue_free()
		return

	var source_id := tilemap.get_cell_source_id(tile_position)
	if source_id == -1:
		queue_free()
		return

	var tile_size := Vector2(tilemap.tile_set.tile_size)
	if tile_size == Vector2.ZERO:
		tile_size = DEFAULT_TILE_SIZE

	global_position = tilemap.to_global(tilemap.map_to_local(tile_position))
	z_as_relative = false
	z_index = get_render_z_index(tilemap, tile_position, tile_size)

	var overlay := TileMapLayer.new()
	overlay.tile_set = tilemap.tile_set
	overlay.position = -tile_size * 0.5
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.82)
	overlay.set_cell(
		Vector2i.ZERO,
		source_id,
		tilemap.get_cell_atlas_coords(tile_position),
		tilemap.get_cell_alternative_tile(tile_position)
	)
	add_child(overlay)

	scale = Vector2(1.0, 1.0)
	rotation_degrees = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:x", position.x - RUSTLE_DISTANCE, 0.06)
	tween.parallel().tween_property(self, "rotation_degrees", -2.5, 0.06)
	tween.tween_property(self, "position:x", position.x + RUSTLE_DISTANCE, 0.08)
	tween.parallel().tween_property(self, "rotation_degrees", 2.5, 0.08)
	tween.tween_property(self, "position:x", position.x, 0.08)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.08)
	tween.parallel().tween_property(overlay, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
