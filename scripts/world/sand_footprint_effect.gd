extends Node2D

const DURATION := 1.8
const Z_OFFSET := -1
const FOOT_OFFSET := 5.0

var elapsed := 0.0
var footprint_color := Color(0.45, 0.27, 0.12, 0.42)
var facing := Vector2.DOWN
var is_left_foot := false


func play(world_position: Vector2, movement_direction: Vector2, left_foot: bool) -> void:
	global_position = world_position
	facing = movement_direction if movement_direction != Vector2.ZERO else Vector2.DOWN
	is_left_foot = left_foot
	z_as_relative = false
	z_index = floori(world_position.y) + Z_OFFSET
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var color := footprint_color
	color.a *= 1.0 - progress

	# De afdruk is standaard omhoog gericht. Roteer hem vervolgens naar de
	# looprichting en wissel hem duidelijk links/rechts af per stap.
	var rotation := facing.angle() + PI * 0.5
	var side := -FOOT_OFFSET if is_left_foot else FOOT_OFFSET
	var side_offset := Vector2(-facing.y, facing.x) * side
	draw_set_transform(side_offset, rotation, Vector2.ONE)
	var sole := PackedVector2Array([
		Vector2(-2.2, 4.5),
		Vector2(2.2, 4.5),
		Vector2(2.6, -0.5),
		Vector2(1.7, -4.4),
		Vector2(-1.7, -4.4),
		Vector2(-2.6, -0.5),
	])
	draw_colored_polygon(sole, color)
	draw_circle(Vector2(0.0, -4.0), 1.8, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
