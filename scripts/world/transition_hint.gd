@tool
extends Node2D

const TILE_SIZE := 32.0

@export var tile_footprint := Vector2i.ONE
@export var particle_count := 16
@export var cycle_seconds := 1.7
@export var particle_radius := 2.3
@export var tint := Color(0.82, 0.64, 1.0, 0.94)

var _elapsed := 0.0
var _particles: Array[Dictionary] = []
var _last_footprint := Vector2i.ZERO


func _ready() -> void:
	z_as_relative = false
	_rebuild_particles()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, maxf(cycle_seconds, 0.01))
	queue_redraw()


func get_footprint_size() -> Vector2:
	return Vector2(
		float(maxi(1, tile_footprint.x)) * TILE_SIZE,
		float(maxi(1, tile_footprint.y)) * TILE_SIZE
	)


func _draw() -> void:
	if particle_count <= 0:
		return
	if _particles.size() != particle_count or _last_footprint != tile_footprint:
		_rebuild_particles()

	var size := get_footprint_size()
	var half_size := size * 0.5
	var footprint_rect := Rect2(-half_size, size)
	draw_rect(footprint_rect, Color(0.055, 0.025, 0.11, 0.34), true)
	draw_rect(footprint_rect.grow(-2.0), Color(tint.r, tint.g, tint.b, 0.22), true)
	draw_rect(footprint_rect.grow(-2.0), Color(tint.r, tint.g, tint.b, tint.a), false, 2.2)
	draw_rect(footprint_rect.grow(-5.0), Color(0.88, 0.95, 1.0, 0.46), false, 1.0)

	var safe_cycle := maxf(cycle_seconds, 0.01)
	for chevron_index in range(3):
		var progress := fmod((_elapsed / safe_cycle) + float(chevron_index) / 3.0, 1.0)
		var y := lerpf(half_size.y - 6.0, -half_size.y + 6.0, progress)
		var alpha := sin(progress * PI) * tint.a
		draw_polyline(
			PackedVector2Array([
				Vector2(-6.0, y + 4.0),
				Vector2(0.0, y - 2.0),
				Vector2(6.0, y + 4.0),
			]),
			Color(tint.r, tint.g, tint.b, alpha),
			2.5,
			true
		)

	for particle: Dictionary in _particles:
		var progress := fmod((_elapsed / safe_cycle) + float(particle["phase"]), 1.0)
		var x_offset := float(particle["x_anchor"]) * (size.x - 10.0) - (size.x - 10.0) * 0.5
		var sway := sin((_elapsed * float(particle["sway_speed"])) + float(particle["sway_phase"])) * float(particle["sway_width"])
		var pulse := 0.82 + 0.18 * sin((progress * TAU) + float(particle["phase"]) * TAU)
		var center := Vector2(x_offset + sway, lerpf(half_size.y - 4.0, -half_size.y + 4.0, progress))
		var alpha := sin(progress * PI) * pulse * tint.a
		var radius := particle_radius * float(particle["scale"]) * pulse
		draw_circle(center, radius * 2.8, Color(tint.r, tint.g, tint.b, alpha * 0.20))
		draw_circle(center, radius, Color(tint.r, tint.g, tint.b, alpha))
		draw_circle(center - Vector2(radius * 0.25, radius * 0.25), radius * 0.36, Color(1.0, 0.96, 1.0, alpha))


func _rebuild_particles() -> void:
	_particles.clear()
	_last_footprint = tile_footprint
	for index in range(maxi(particle_count, 0)):
		var seed := float(index + 1)
		_particles.append({
			"phase": fmod(seed * 0.61803398875, 1.0),
			"x_anchor": fmod(seed * 0.731, 1.0),
			"sway_phase": seed * 2.41,
			"sway_speed": 2.0 + fmod(seed * 1.37, 1.0) * 2.0,
			"sway_width": 0.8 + fmod(seed * 2.13, 1.0) * 2.0,
			"scale": 0.8 + fmod(seed * 5.17, 1.0) * 0.65,
		})
