extends "res://scripts/world/map_metadata.gd"

const ROOM_BOUNDS := Rect2i(5, 8, 19, 11)
const EXIT_COLUMNS: Array[int] = [12, 13, 14, 15, 16]


func _ready() -> void:
	_build_collision()
	super._ready()


func _build_collision() -> void:
	if collision == null:
		return
	collision.clear()

	var left := ROOM_BOUNDS.position.x
	var right := ROOM_BOUNDS.end.x - 1
	var top := ROOM_BOUNDS.position.y
	var bottom := ROOM_BOUNDS.end.y - 1
	for x: int in range(left, right + 1):
		collision.set_cell(Vector2i(x, top), 0, Vector2i.ZERO)
		if x not in EXIT_COLUMNS:
			collision.set_cell(Vector2i(x, bottom), 0, Vector2i.ZERO)
	for y: int in range(top, bottom + 1):
		collision.set_cell(Vector2i(left, y), 0, Vector2i.ZERO)
		collision.set_cell(Vector2i(right, y), 0, Vector2i.ZERO)

	var objects := get_node_or_null("BikeShopVisual/Objects") as TileMapLayer
	if objects == null:
		return
	for cell: Vector2i in objects.get_used_cells():
		collision.set_cell(cell, 0, Vector2i.ZERO)
