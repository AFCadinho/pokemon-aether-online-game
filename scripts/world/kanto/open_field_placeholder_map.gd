extends "res://scripts/world/map_metadata.gd"

const MAP_SIZE := Vector2i(24, 18)
const COLLISION_SOURCE_ID := 0

@export var map_size := MAP_SIZE
@export_enum("top", "bottom", "left", "right") var connection_side := "top"
@export_range(0, 255, 1) var opening_from := 10
@export_range(0, 255, 1) var opening_to := 13
@export_range(-1, 255, 1) var second_opening_from := -1
@export_range(-1, 255, 1) var second_opening_to := -1
@export_range(-1, 255, 1) var third_opening_from := -1
@export_range(-1, 255, 1) var third_opening_to := -1
@export_range(-1, 255, 1) var fourth_opening_from := -1
@export_range(-1, 255, 1) var fourth_opening_to := -1
@export_enum("none", "top", "bottom", "left", "right") var water_connection_side := "none"
@export_range(0, 255, 1) var water_opening_from := 0
@export_range(0, 255, 1) var water_opening_to := 0
@export_range(-1, 255, 1) var second_water_opening_from := -1
@export_range(-1, 255, 1) var second_water_opening_to := -1
@export_range(1, 255, 1) var water_connection_depth := 4

@onready var water: TileMapLayer = find_map_tilemap_layer("Water")


func _ready() -> void:
	_build_map_boundaries()
	_build_water_connection()
	super._ready()


func _build_map_boundaries() -> void:
	if collision == null:
		push_error("Open-field placeholder could not resolve its Collision tile layer.")
		return
	for x: int in range(map_size.x):
		if not _is_opening("top", x):
			collision.set_cell(Vector2i(x, 0), COLLISION_SOURCE_ID, Vector2i.ZERO)
		if not _is_opening("bottom", x):
			collision.set_cell(Vector2i(x, map_size.y - 1), COLLISION_SOURCE_ID, Vector2i.ZERO)
	for y: int in range(1, map_size.y - 1):
		if not _is_opening("left", y):
			collision.set_cell(Vector2i(0, y), COLLISION_SOURCE_ID, Vector2i.ZERO)
		if not _is_opening("right", y):
			collision.set_cell(Vector2i(map_size.x - 1, y), COLLISION_SOURCE_ID, Vector2i.ZERO)


func _is_opening(side: String, offset: int) -> bool:
	if side != connection_side:
		return false
	return (
		_is_offset_in_range(offset, opening_from, opening_to)
		or _is_offset_in_range(offset, second_opening_from, second_opening_to)
		or _is_offset_in_range(offset, third_opening_from, third_opening_to)
		or _is_offset_in_range(offset, fourth_opening_from, fourth_opening_to)
	)


func _is_offset_in_range(offset: int, range_from: int, range_to: int) -> bool:
	return range_from >= 0 and range_to >= range_from and offset >= range_from and offset <= range_to


func _build_water_connection() -> void:
	if water_connection_side == "none":
		return
	if water == null:
		push_error("Open-field placeholder could not resolve its Water tile layer.")
		return
	var water_openings: Array[Vector2i] = [
		Vector2i(water_opening_from, water_opening_to),
		Vector2i(second_water_opening_from, second_water_opening_to),
	]
	for opening: Vector2i in water_openings:
		if opening.x < 0 or opening.y < opening.x:
			continue
		for offset: int in range(opening.x, opening.y + 1):
			for depth: int in range(water_connection_depth):
				var cell := Vector2i.ZERO
				match water_connection_side:
					"top":
						cell = Vector2i(offset, depth)
					"bottom":
						cell = Vector2i(offset, map_size.y - 1 - depth)
					"left":
						cell = Vector2i(depth, offset)
					"right":
						cell = Vector2i(map_size.x - 1 - depth, offset)
				water.set_cell(cell, COLLISION_SOURCE_ID, Vector2i.ZERO)
