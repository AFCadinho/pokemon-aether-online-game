extends Node2D

@export var particle_count := 8
@export_range(8.0, 256.0, 1.0, "or_greater") var width := 24.0
@export var height := 18.0
@export var cycle_seconds := 1.4
@export var particle_radius := 2.0
@export var tint := Color(0.78, 0.95, 1.0, 0.65)

var _elapsed := 0.0
var _particles: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	_rebuild_particles()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, cycle_seconds)
	queue_redraw()


func _draw() -> void:
	if particle_count <= 0 or cycle_seconds <= 0.0:
		return

	if _particles.size() != particle_count:
		_rebuild_particles()

	for particle in _particles:
		var progress := fmod((_elapsed / cycle_seconds) + float(particle["phase"]), 1.0)
		var x_offset := float(particle["x_offset"])
		var sway := sin((_elapsed * float(particle["sway_speed"])) + float(particle["sway_phase"])) * float(particle["sway_width"])
		var pulse := 0.78 + 0.22 * sin((progress * TAU) + float(particle["phase"]) * TAU)
		var position := Vector2(x_offset + sway, (0.5 - progress) * height + float(particle["y_offset"]))
		var alpha := pulse * tint.a
		var color := Color(tint.r, tint.g, tint.b, alpha)
		var radius := particle_radius * float(particle["scale"]) * pulse
		draw_circle(position, radius, color)


func _rebuild_particles() -> void:
	_particles.clear()
	var count: int = maxi(particle_count, 0)
	if count == 0:
		return

	for index in range(count):
		var seed: float = float(index + 1)
		_particles.append({
			"phase": fmod(seed * 0.61803398875, 1.0),
			"x_offset": (fmod(seed * 37.31, 1.0) - 0.5) * width,
			"y_offset": (fmod(seed * 19.73, 1.0) - 0.5) * height,
			"sway_phase": seed * 2.41,
			"sway_speed": 2.0 + fmod(seed * 1.37, 1.0) * 2.0,
			"sway_width": 1.5 + fmod(seed * 2.13, 1.0) * 3.5,
			"scale": 0.7 + fmod(seed * 5.17, 1.0) * 0.65,
		})
