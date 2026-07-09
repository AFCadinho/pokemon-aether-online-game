extends Node2D

@export_range(16.0, 512.0, 1.0, "or_greater") var width := 128.0
@export_range(8.0, 192.0, 1.0, "or_greater") var height := 56.0
@export var cycle_seconds := 2.8
@export var band_color := Color(0.78, 1.0, 0.56, 0.30)
@export var edge_color := Color(0.96, 1.0, 0.78, 0.72)
@export var wisp_color := Color(1.0, 0.96, 0.54, 0.58)
@export var wisp_count := 14

var _elapsed := 0.0
var _wisps: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	_rebuild_wisps()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, maxf(cycle_seconds, 0.01))
	queue_redraw()


func _draw() -> void:
	if width <= 0.0 or height <= 0.0:
		return

	if _wisps.size() != wisp_count:
		_rebuild_wisps()

	var half_width := width * 0.5
	var half_height := height * 0.5
	var center_rect := Rect2(Vector2(-half_width, -half_height * 0.55), Vector2(width, height * 0.55))
	draw_rect(center_rect, Color(band_color.r, band_color.g, band_color.b, band_color.a * 0.42), true)

	for index in range(5):
		var offset := float(index) * 3.0
		var alpha := edge_color.a * (1.0 - float(index) / 5.0)
		var color := Color(edge_color.r, edge_color.g, edge_color.b, alpha)
		draw_line(Vector2(-half_width, -offset), Vector2(half_width, -offset), color, 2.5)

	for index in range(4):
		var progress := fmod((_elapsed / cycle_seconds) + float(index) * 0.25, 1.0)
		var alpha := sin(progress * PI) * band_color.a
		var y := lerpf(half_height * 0.45, -half_height * 0.8, progress)
		var color := Color(band_color.r, band_color.g, band_color.b, alpha)
		draw_line(Vector2(-half_width, y), Vector2(half_width, y), color, 2.0)

	for wisp in _wisps:
		var progress := fmod((_elapsed / cycle_seconds) + float(wisp["phase"]), 1.0)
		var x := lerpf(-half_width, half_width, float(wisp["x_anchor"]))
		var y := lerpf(half_height * 0.5, -half_height, progress) + float(wisp["y_offset"])
		var sway := sin((_elapsed * float(wisp["speed"])) + float(wisp["phase"]) * TAU) * float(wisp["sway"])
		var alpha := sin(progress * PI) * wisp_color.a
		var radius := float(wisp["radius"]) * (0.75 + 0.25 * sin(progress * TAU))
		draw_circle(Vector2(x + sway, y), radius, Color(wisp_color.r, wisp_color.g, wisp_color.b, alpha))


func _rebuild_wisps() -> void:
	_wisps.clear()
	var count := maxi(wisp_count, 0)
	for index in range(count):
		var seed := float(index + 1)
		_wisps.append({
			"phase": fmod(seed * 0.61803398875, 1.0),
			"x_anchor": fmod(seed * 0.377, 1.0),
			"y_offset": (fmod(seed * 0.719, 1.0) - 0.5) * height * 0.22,
			"speed": 0.9 + fmod(seed * 0.241, 1.0) * 1.0,
			"sway": 5.0 + fmod(seed * 0.433, 1.0) * 10.0,
			"radius": 1.6 + fmod(seed * 0.517, 1.0) * 2.2,
		})
