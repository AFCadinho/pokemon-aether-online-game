extends Node2D

# Only the rendered Look moves; the shadow, tile position and collision stay on
# the ground. Both local and remote avatars use the same time-based motion.
var visual_offset := Vector2.ZERO
var elapsed := 0.0
var height := 0.0
var amplitude := 0.0
var period := 2.4
var shadow_points := PackedVector2Array()


func configure(definition: Dictionary) -> void:
	height = maxf(float(definition.get("hoverHeight", 0.0)), 0.0)
	amplitude = clampf(float(definition.get("hoverAmplitude", 2.0)), 0.0, height)
	period = maxf(float(definition.get("hoverPeriod", 2.4)), 0.1)
	elapsed = 0.0
	visible = height > 0.0
	z_index = -2
	shadow_points.clear()
	for index in range(32):
		var angle := TAU * index / 32.0
		shadow_points.append(Vector2(cos(angle) * 22.0, 12.0 + sin(angle) * 6.0))
	advance(0.0)
	queue_redraw()


func advance(delta: float) -> void:
	if height <= 0.0:
		visual_offset = Vector2.ZERO
		return
	elapsed = fposmod(elapsed + maxf(delta, 0.0), period)
	# Whole pixels keep the original pixel art sharp.
	visual_offset = Vector2(0.0, roundf(-height + sin(elapsed * TAU / period) * amplitude))


func _draw() -> void:
	if height > 0.0:
		draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, 0.22))
