extends "res://scripts/world/map_metadata.gd"

const MAP_SIZE := Vector2i(24, 18)
const ROAD_MIN_X := 10
const ROAD_MAX_X := 13
const CERULEAN_ROAD_MIN_Y := 8
const CERULEAN_ROAD_MAX_Y := 10
const COLLISION_SOURCE_ID := 1

@onready var collision: TileMapLayer = $Collision


func _ready() -> void:
	_build_placeholder_boundaries()
	super._ready()


func _build_placeholder_boundaries() -> void:
	if collision == null:
		return
	for x: int in range(MAP_SIZE.x):
		if x < ROAD_MIN_X or x > ROAD_MAX_X:
			_set_boundary_cell(Vector2i(x, 0))
		_set_boundary_cell(Vector2i(x, MAP_SIZE.y - 1))
	for y: int in range(1, MAP_SIZE.y - 1):
		_set_boundary_cell(Vector2i(0, y))
		if y < CERULEAN_ROAD_MIN_Y or y > CERULEAN_ROAD_MAX_Y:
			_set_boundary_cell(Vector2i(MAP_SIZE.x - 1, y))


func _set_boundary_cell(cell: Vector2i) -> void:
	collision.set_cell(cell, COLLISION_SOURCE_ID, Vector2i.ZERO)
