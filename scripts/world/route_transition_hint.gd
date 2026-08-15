@tool
extends Node2D

const TILE_SIZE := 32.0
const GROUND_OVERLAY_Z_INDEX := 7

@export var tile_footprint := Vector2i(4, 2)
@export_enum("up", "down", "left", "right") var flow_direction := "up"
@export var cycle_seconds := 2.2
@export var edge_color := Color(0.72, 0.96, 1.0, 0.92)

var _elapsed := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = GROUND_OVERLAY_Z_INDEX
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
	var cross_extent := absf(cross_vector.x) * half_size.x + absf(cross_vector.y) * half_size.y
	var cross_tiles := tile_footprint.y if absf(flow_vector.x) > 0.5 else tile_footprint.x
	var lane_count := clampi(maxi(1, cross_tiles), 1, 8)
	for lane_index in range(lane_count):
		var lane_offset := -cross_extent + (float(lane_index) + 0.5) * TILE_SIZE
		for chevron_index in range(3):
			var progress := fmod(
				(_elapsed / safe_cycle) + float(chevron_index) / 3.0 + float(lane_index) * 0.07,
				1.0
			)
			var center := (
				-flow_vector * (flow_extent - 8.0)
				+ flow_vector * ((flow_extent - 8.0) * 2.0 * progress)
				+ cross_vector * lane_offset
			)
			var alpha := sin(progress * PI) * edge_color.a
			var chevron_color := Color(edge_color.r, edge_color.g, edge_color.b, alpha)
			draw_polyline(
				PackedVector2Array([
					center - flow_vector * 4.0 - cross_vector * 6.0,
					center + flow_vector * 2.0,
					center - flow_vector * 4.0 + cross_vector * 6.0,
				]),
				chevron_color,
				2.4,
				true
			)
