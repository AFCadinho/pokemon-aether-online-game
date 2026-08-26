extends "res://scripts/world/map_metadata.gd"

const CeruleanWeatherWaterMaskScript := preload(
	"res://scripts/world/kanto/towns/cerulean_weather_water_mask.gd"
)

const MAP_SIZE := Vector2i(75, 70)
const EXIT_OPENINGS := {
	"route_4": {
		"axis": "left",
		"from": 23,
		"to": 27,
	},
	"route_24_water": {
		"axis": "top",
		"from": 56,
		"to": 60,
	},
	"route_24_path": {
		"axis": "top",
		"from": 67,
		"to": 71,
	},
	"route_5": {
		"axis": "right",
		"from": 42,
		"to": 47,
	},
	"route_9_left": {
		"axis": "bottom",
		"from": 11,
		"to": 13,
	},
	"route_9_grass": {
		"axis": "bottom",
		"from": 15,
		"to": 18,
	},
	"route_9_right": {
		"axis": "bottom",
		"from": 20,
		"to": 22,
	},
}

const ROUTE_24_WATER_MIN_X := 56
const ROUTE_24_WATER_MAX_X := 60
const ROUTE_24_WATER_MAX_Y := 14

@onready var water: TileMapLayer = find_map_tilemap_layer("Water")

func _ready() -> void:
	CeruleanWeatherWaterMaskScript.build(get_node_or_null("CeruleanCityVisual"))
	_open_exterior_connections()
	_build_route_24_water_connection()
	super._ready()


func _open_exterior_connections() -> void:
	if collision == null:
		push_error("Cerulean City could not resolve its Collision tile layer.")
		return
	for opening_value: Variant in EXIT_OPENINGS.values():
		var opening: Dictionary = opening_value as Dictionary
		var opening_axis := str(opening.get("axis", ""))
		var opening_from := int(opening.get("from", 0))
		var opening_to := int(opening.get("to", -1))
		for offset: int in range(opening_from, opening_to + 1):
			match opening_axis:
				"top":
					collision.erase_cell(Vector2i(offset, 0))
					collision.erase_cell(Vector2i(offset, -1))
				"bottom":
					collision.erase_cell(Vector2i(offset, MAP_SIZE.y - 1))
					collision.erase_cell(Vector2i(offset, MAP_SIZE.y))
				"left":
					collision.erase_cell(Vector2i(0, offset))
					collision.erase_cell(Vector2i(-1, offset))
				"right":
					collision.erase_cell(Vector2i(MAP_SIZE.x - 1, offset))
					collision.erase_cell(Vector2i(MAP_SIZE.x, offset))


func _build_route_24_water_connection() -> void:
	if water == null:
		push_error("Cerulean City could not resolve its Water tile layer.")
		return
	for x: int in range(ROUTE_24_WATER_MIN_X, ROUTE_24_WATER_MAX_X + 1):
		for y: int in range(0, ROUTE_24_WATER_MAX_Y + 1):
			water.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
