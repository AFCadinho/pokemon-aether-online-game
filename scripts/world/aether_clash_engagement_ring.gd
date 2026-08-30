extends Node2D


const RADIUS := 28.0
const BLUE_COLOR := Color("58b8ffff")
const RED_COLOR := Color("ff6678ff")

var side := "blue"


func _ready() -> void:
	show_behind_parent = true
	z_index = -1
	queue_redraw()


func configure(next_side: String) -> void:
	side = next_side
	queue_redraw()


func _draw() -> void:
	var color := BLUE_COLOR if side == "blue" else RED_COLOR
	draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.14))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(color, 0.92), 2.0, true)
