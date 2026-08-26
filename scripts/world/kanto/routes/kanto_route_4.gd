extends "res://scripts/world/map_metadata.gd"

const MAP_SIZE := Vector2i(100, 50)
const CERULEAN_WATER_MIN_Y := 28
const CERULEAN_WATER_MAX_Y := 34
const CERULEAN_ROAD_MIN_Y := 36
const CERULEAN_ROAD_MAX_Y := 39


func _ready() -> void:
	_build_map_boundaries()
	super._ready()


func _build_map_boundaries() -> void:
	if collision == null:
		push_error("Route 4 could not resolve its Collision tile layer.")
		return
	var tile_template := _get_collision_tile_template()
	if tile_template.is_empty():
		push_error("Route 4 Collision has no tile template for map boundaries.")
		return
	for x: int in range(MAP_SIZE.x):
		_set_boundary_cell(Vector2i(x, 0), tile_template)
		_set_boundary_cell(Vector2i(x, MAP_SIZE.y - 1), tile_template)
	for y: int in range(1, MAP_SIZE.y - 1):
		_set_boundary_cell(Vector2i(0, y), tile_template)
		if not _is_cerulean_connection_y(y):
			_set_boundary_cell(Vector2i(MAP_SIZE.x - 1, y), tile_template)


func _is_cerulean_connection_y(y: int) -> bool:
	return (
		(y >= CERULEAN_WATER_MIN_Y and y <= CERULEAN_WATER_MAX_Y)
		or (y >= CERULEAN_ROAD_MIN_Y and y <= CERULEAN_ROAD_MAX_Y)
	)


func _get_collision_tile_template() -> Dictionary:
	for cell: Vector2i in collision.get_used_cells():
		var source_id := collision.get_cell_source_id(cell)
		if source_id < 0:
			continue
		return {
			"source_id": source_id,
			"atlas_coords": collision.get_cell_atlas_coords(cell),
			"alternative_tile": collision.get_cell_alternative_tile(cell),
		}
	return {}


func _set_boundary_cell(cell: Vector2i, tile_template: Dictionary) -> void:
	collision.set_cell(
		cell,
		int(tile_template.get("source_id", -1)),
		tile_template.get("atlas_coords", Vector2i.ZERO) as Vector2i,
		int(tile_template.get("alternative_tile", 0))
	)
