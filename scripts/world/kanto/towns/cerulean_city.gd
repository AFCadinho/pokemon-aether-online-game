extends "res://scripts/world/map_metadata.gd"

const MAP_SIZE := Vector2i(75, 70)
const EXIT_OPENINGS := {
	"route_4": {
		"axis": "left",
		"from": 23,
		"to": 27,
	},
	"route_24": {
		"axis": "top",
		"from": 68,
		"to": 70,
	},
	"route_9": {
		"axis": "right",
		"from": 44,
		"to": 46,
	},
	"route_5": {
		"axis": "bottom",
		"from": 14,
		"to": 16,
	},
}

func _ready() -> void:
	_open_exterior_connections()
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
					collision.erase_cell(Vector2i(offset, -1))
				"bottom":
					collision.erase_cell(Vector2i(offset, MAP_SIZE.y))
				"left":
					collision.erase_cell(Vector2i(-1, offset))
				"right":
					collision.erase_cell(Vector2i(MAP_SIZE.x, offset))
