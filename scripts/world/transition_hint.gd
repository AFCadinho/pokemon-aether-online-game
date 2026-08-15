@tool
extends Node2D

const TILE_SIZE := 32.0

@export var tile_footprint := Vector2i.ONE
@export_enum("up", "down", "left", "right") var flow_direction := "up"
@export var cycle_seconds := 1.7
@export var tint := Color(0.82, 0.64, 1.0, 0.94)

var _elapsed := 0.0


func _ready() -> void:
	z_as_relative = false
	set_process(true)


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, maxf(cycle_seconds, 0.01))
	queue_redraw()


func get_footprint_size() -> Vector2:
	return Vector2(
		float(maxi(1, tile_footprint.x)) * TILE_SIZE,
		float(maxi(1, tile_footprint.y)) * TILE_SIZE
	)


func get_flow_vector() -> Vector2:
	match flow_direction:
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.UP


func _draw() -> void:
	var size := get_footprint_size()
	var half_size := size * 0.5
	var safe_cycle := maxf(cycle_seconds, 0.01)
	var flow_vector := get_flow_vector()
	var cross_vector := Vector2(-flow_vector.y, flow_vector.x)
	var flow_extent := absf(flow_vector.x) * half_size.x + absf(flow_vector.y) * half_size.y

	for chevron_index in range(3):
		var progress := fmod((_elapsed / safe_cycle) + float(chevron_index) / 3.0, 1.0)
		var center := (
			-flow_vector * (flow_extent - 6.0)
			+ flow_vector * ((flow_extent - 6.0) * 2.0 * progress)
		)
		var alpha := sin(progress * PI) * tint.a
		draw_polyline(
			PackedVector2Array([
				center - flow_vector * 4.0 - cross_vector * 6.0,
				center + flow_vector * 2.0,
				center - flow_vector * 4.0 + cross_vector * 6.0,
			]),
			Color(tint.r, tint.g, tint.b, alpha),
			2.5,
			true
		)
