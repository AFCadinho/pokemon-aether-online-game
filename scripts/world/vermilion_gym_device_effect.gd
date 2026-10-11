extends Node2D

# Decorative power remains independent of the switch puzzle's barrier circuit.
@export var phase_offset := 0.0

var elapsed := 0.0
var animation_tick := -1


func _ready() -> void:
	elapsed = phase_offset
	var sparks := CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 0.75
	sparks.preprocess = 0.75
	sparks.local_coords = true
	sparks.fixed_fps = 20
	sparks.direction = Vector2.UP
	sparks.spread = 35.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 12.0
	sparks.initial_velocity_max = 24.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(18, 12)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	sparks.use_fixed_seed = true
	sparks.seed = 812 + int(phase_offset * 100.0)
	var pixel := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	sparks.texture = ImageTexture.create_from_image(pixel)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color("d9fbff00"), Color("d9fbff"), Color("55bfff00")])
	sparks.color_ramp = fade
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sparks)


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 60.0)
	var next_tick := int(elapsed * 12.0)
	if animation_tick != next_tick:
		animation_tick = next_tick
		queue_redraw()


func _draw() -> void:
	var pulse := 0.65 + 0.35 * sin(elapsed * 3.0)
	draw_circle(Vector2.ZERO, 24.0, Color(0.2, 0.7, 1.0, 0.04 * pulse))
	# Small discharges hug the glass rather than spanning the room.
	for side in [-1, 1]:
		if posmod(animation_tick + side * 3, 11) >= 5:
			continue
		var points := PackedVector2Array()
		for step in range(7):
			var x := float(side) * 17.0
			if step > 0 and step < 6:
				x += sin(float(step) * 2.3 + float(animation_tick) * 1.7) * 4.0
			points.append(Vector2(x, -16.0 + float(step) * 5.0))
		draw_polyline(points, Color(0.2, 0.65, 1.0, 0.22), 5.0)
		draw_polyline(points, Color("62caff"), 2.0)
		draw_polyline(points, Color("e8fbff"), 1.0)
