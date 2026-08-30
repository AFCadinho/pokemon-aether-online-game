extends Node2D


const RADIUS := 18.0
const NORTH_COLOR := Color("f4c34fff")
const SOUTH_COLOR := Color("70b7ffff")

var side := "challenger"


func _ready() -> void:
	show_behind_parent = true
	z_index = -1
	queue_redraw()


func configure(next_side: String) -> void:
	side = next_side
	queue_redraw()


func _draw() -> void:
	var color := NORTH_COLOR if side == "challenger" else SOUTH_COLOR
	draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.14))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(color, 0.92), 2.0, true)
