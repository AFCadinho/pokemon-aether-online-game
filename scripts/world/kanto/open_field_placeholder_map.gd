extends "res://scripts/world/map_metadata.gd"

const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")
const MAP_SIZE := Vector2i(24, 18)
const COLLISION_SOURCE_ID := 0

@export_enum("top", "bottom", "left", "right") var connection_side := "top"
@export_range(0, 23, 1) var opening_from := 10
@export_range(0, 23, 1) var opening_to := 13

@onready var collision: TileMapLayer = MapLayerResolverScript.find_tilemap_layer(
	self,
	["Collision"]
)


func _ready() -> void:
	_build_map_boundaries()
	super._ready()


func _build_map_boundaries() -> void:
	if collision == null:
		push_error("Open-field placeholder could not resolve its Collision tile layer.")
		return
	for x: int in range(MAP_SIZE.x):
		if not _is_opening("top", x):
			collision.set_cell(Vector2i(x, 0), COLLISION_SOURCE_ID, Vector2i.ZERO)
		if not _is_opening("bottom", x):
			collision.set_cell(Vector2i(x, MAP_SIZE.y - 1), COLLISION_SOURCE_ID, Vector2i.ZERO)
	for y: int in range(1, MAP_SIZE.y - 1):
		if not _is_opening("left", y):
			collision.set_cell(Vector2i(0, y), COLLISION_SOURCE_ID, Vector2i.ZERO)
		if not _is_opening("right", y):
			collision.set_cell(Vector2i(MAP_SIZE.x - 1, y), COLLISION_SOURCE_ID, Vector2i.ZERO)


func _is_opening(side: String, offset: int) -> bool:
	return side == connection_side and offset >= opening_from and offset <= opening_to
