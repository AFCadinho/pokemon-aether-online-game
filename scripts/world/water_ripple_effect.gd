extends Node2D

const KIND_SURF_STEP := "surf_step"
const KIND_SURF_START := "surf_start"
const KIND_FISH_CAST := "fish_cast"
const KIND_FISH_BITE := "fish_bite"
const KIND_FISH_REEL := "fish_reel"

const Z_OFFSET := 1
const SURF_Z_OFFSET := -2

var duration := 0.34
var elapsed := 0.0
var start_radius := 3.0
var end_radius := 15.0
var ring_count := 2
var line_width := 1.4
var ripple_color := Color(0.78, 0.93, 1.0, 0.72)


func play(world_position: Vector2, kind := KIND_SURF_STEP) -> void:
	global_position = world_position
	z_as_relative = false
	# Surf rings originate underneath the rider. Keep them below the complete
	# mount layer (which renders one level below the player), rather than over it.
	z_index = floori(world_position.y) + (SURF_Z_OFFSET if kind.begins_with("surf_") else Z_OFFSET)
	_configure_kind(kind)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := ripple_color.a * (1.0 - progress)
	var eased_progress := sin(progress * PI * 0.5)

	for ring_index in range(ring_count):
		var ring_delay := float(ring_index) * 0.18
		var ring_progress := clampf((eased_progress - ring_delay) / maxf(1.0 - ring_delay, 0.01), 0.0, 1.0)
		if ring_progress <= 0.0:
			continue

		var radius := lerpf(start_radius, end_radius, ring_progress)
		var ring_alpha := alpha * (1.0 - float(ring_index) * 0.28)
		var color := Color(ripple_color.r, ripple_color.g, ripple_color.b, ring_alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, color, line_width, true)


func _configure_kind(kind: String) -> void:
	match kind:
		KIND_SURF_START:
			duration = 0.42
			start_radius = 5.0
			end_radius = 22.0
			ring_count = 3
			line_width = 1.6
			ripple_color = Color(0.82, 0.95, 1.0, 0.78)
		KIND_FISH_CAST:
			duration = 0.38
			start_radius = 2.0
			end_radius = 13.0
			ring_count = 2
			line_width = 1.2
			ripple_color = Color(0.86, 0.96, 1.0, 0.72)
		KIND_FISH_BITE:
			duration = 0.48
			start_radius = 3.0
			end_radius = 24.0
			ring_count = 3
			line_width = 1.7
			ripple_color = Color(0.95, 0.99, 1.0, 0.86)
		KIND_FISH_REEL:
			duration = 0.36
			start_radius = 4.0
			end_radius = 18.0
			ring_count = 2
			line_width = 1.5
			ripple_color = Color(0.90, 0.98, 1.0, 0.82)
		_:
			duration = 0.32
			start_radius = 3.0
			end_radius = 14.0
			ring_count = 2
			line_width = 1.2
			ripple_color = Color(0.78, 0.93, 1.0, 0.62)
