extends Node2D


@export var half_width := 1280.0
@export var wall_height := 56.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var glow := Color("3ce8ff2e")
	var core := Color("b9f8ffff")
	var edge := Color("38dfffe8")
	draw_rect(
		Rect2(Vector2(-half_width, -wall_height * 0.5), Vector2(half_width * 2.0, wall_height)),
		glow
	)
	draw_line(Vector2(-half_width, 0.0), Vector2(half_width, 0.0), edge, 12.0, true)
	draw_line(Vector2(-half_width, -2.0), Vector2(half_width, -2.0), core, 3.0, true)
	for x: int in range(-int(half_width), int(half_width) + 1, 64):
		draw_circle(Vector2(float(x), 0.0), 5.0, core)
