extends "res://scripts/world/map_metadata.gd"

const MAP_SIZE := Vector2i(24, 18)
const ROUTE_4_ROAD_MIN_Y := 8
const ROUTE_4_ROAD_MAX_Y := 10
const COLLISION_SOURCE_ID := 1

@onready var collision: TileMapLayer = $Collision


func _ready() -> void:
	_build_placeholder_boundaries()
	super._ready()


func _build_placeholder_boundaries() -> void:
	if collision == null:
		return
	for x: int in range(MAP_SIZE.x):
		_set_boundary_cell(Vector2i(x, 0))
		_set_boundary_cell(Vector2i(x, MAP_SIZE.y - 1))
	for y: int in range(1, MAP_SIZE.y - 1):
		if y < ROUTE_4_ROAD_MIN_Y or y > ROUTE_4_ROAD_MAX_Y:
			_set_boundary_cell(Vector2i(0, y))
		_set_boundary_cell(Vector2i(MAP_SIZE.x - 1, y))


func _set_boundary_cell(cell: Vector2i) -> void:
	collision.set_cell(cell, COLLISION_SOURCE_ID, Vector2i.ZERO)
