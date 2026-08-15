@tool
extends Node2D

const TILE_SIZE := 32.0

@export var tile_footprint := Vector2i(4, 2)
@export_enum("up", "down", "left", "right") var flow_direction := "up"
@export var cycle_seconds := 2.2
@export var band_color := Color(0.25, 0.86, 1.0, 0.34)
@export var edge_color := Color(0.72, 0.96, 1.0, 0.92)
@export var wisp_color := Color(1.0, 0.84, 0.30, 0.90)
@export var wisp_count := 18

var _elapsed := 0.0
var _wisps: Array[Dictionary] = []
var _last_footprint := Vector2i.ZERO


func _ready() -> void:
	z_as_relative = false
	_rebuild_wisps()
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
	if _wisps.size() != maxi(wisp_count, 0) or _last_footprint != tile_footprint:
		_rebuild_wisps()

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

	for wisp: Dictionary in _wisps:
		var progress := fmod((_elapsed / safe_cycle) + float(wisp["phase"]), 1.0)
		var cross_offset := lerpf(-cross_extent + 6.0, cross_extent - 6.0, float(wisp["x_anchor"]))
		var sway := sin((_elapsed * float(wisp["speed"])) + float(wisp["phase"]) * TAU) * float(wisp["sway"])
		var alpha := sin(progress * PI) * wisp_color.a
		var radius := float(wisp["radius"]) * (0.82 + 0.18 * sin(progress * TAU))
		var center := (
			-flow_vector * (flow_extent - 4.0)
			+ flow_vector * ((flow_extent - 4.0) * 2.0 * progress)
			+ cross_vector * (cross_offset + sway)
		)
		draw_circle(center, radius * 2.6, Color(wisp_color.r, wisp_color.g, wisp_color.b, alpha * 0.18))
		draw_circle(center, radius, Color(wisp_color.r, wisp_color.g, wisp_color.b, alpha))
		draw_circle(center - Vector2(radius * 0.25, radius * 0.25), radius * 0.36, Color(1.0, 1.0, 0.88, alpha))


func _rebuild_wisps() -> void:
	_wisps.clear()
	_last_footprint = tile_footprint
	for index in range(maxi(wisp_count, 0)):
		var seed := float(index + 1)
		_wisps.append({
			"phase": fmod(seed * 0.61803398875, 1.0),
			"x_anchor": fmod(seed * 0.377, 1.0),
			"speed": 1.0 + fmod(seed * 0.241, 1.0) * 1.2,
			"sway": 2.0 + fmod(seed * 0.433, 1.0) * 5.0,
			"radius": 1.9 + fmod(seed * 0.517, 1.0) * 1.8,
		})
