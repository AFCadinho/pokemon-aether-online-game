extends Node2D

# Zekrom's turbine, in native 192px mount-cell coordinates. The forward-facing
# body occludes the jet; other angles emit directly from the visible turbine.
const CENTERS := {"down": Vector2(95, 88), "left": Vector2(119, 87), "right": Vector2(73, 87), "up": Vector2(95, 100)}
const NOZZLES := {"down": Vector2(95, 88), "left": Vector2(121, 87), "right": Vector2(71, 87), "up": Vector2(95, 103)}
const AXES := {"down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT, "up": Vector2.DOWN}

class Jet extends Node2D:
	var energy := 0.0
	var clock := 0.0
	var axis := Vector2.RIGHT

	func _draw() -> void:
		var shape := _jet_shape()
		if shape.is_empty():
			return
		var length := shape[4].x
		_polygon(shape, Color(0.12, 0.23, 1.0, 0.20 * energy), 1.45)
		_polygon(shape, Color(0.12, 0.43, 1.0, 0.78 * energy), 1.0)
		_polygon(shape, Color(0.13, 0.86, 1.0, 0.90 * energy), 0.63)
		_polygon(shape, Color(0.85, 1.0, 1.0, 0.96 * energy), 0.24)
		# Short irregular current through the exhaust, not a long map-wide bolt.
		var points := PackedVector2Array()
		for i in range(5):
			points.append((axis * (3.0 + i * length / 5.0) + axis.orthogonal() * sin(i * 3.0 + floor(clock * 18.0)) * 2.0).round())
		draw_polyline(points, Color(0.68, 0.95, 1.0, energy), 1.0, false)

	func _jet_shape() -> PackedVector2Array:
		if energy <= 0.0 or is_zero_approx(energy):
			return PackedVector2Array()
		var pulse := sin(floor(clock * 16.0) * 2.1)
		var length := 31.0 + pulse * 3.0
		var shape := PackedVector2Array([
			Vector2(0, -3), Vector2(5, -5), Vector2(13, -3),
			Vector2(length - 5, -2), Vector2(length, 0),
			Vector2(length - 8, 2), Vector2(12, 4), Vector2(4, 5), Vector2(0, 3),
		])
		# Scale every longitudinal point, so the tip cannot fold back through
		# the full-size nozzle vertices during ignition or fade-out.
		for i in shape.size():
			shape[i].x *= energy
		return shape

	func _polygon(shape: PackedVector2Array, tint: Color, width_factor: float) -> void:
		draw_colored_polygon(_polygon_points(shape, width_factor), tint)

	func _polygon_points(shape: PackedVector2Array, width_factor: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for point: Vector2 in shape:
			# Keep subpixel vertices distinct, especially in the narrow core.
			points.append(axis * point.x + axis.orthogonal() * point.y * width_factor)
		return points


var jet: Jet
var sparks: CPUParticles2D
var enabled := false
var active := false
var direction := "down"
var energy := 0.0
var clock := 0.0
var center := Vector2.ZERO


func configure(definition: Dictionary, mount: AnimatedSprite2D) -> void:
	var next_enabled := str(definition.get("movementEffect", "")) == "zekrom_turbo"
	if jet == null and next_enabled:
		jet = Jet.new()
		jet.name = "TurboJet"
		jet.show_behind_parent = true
		mount.add_child(jet)
		sparks = CPUParticles2D.new()
		sparks.name = "TurboSparks"
		sparks.emitting = false
		sparks.amount = 12
		sparks.lifetime = 0.24
		sparks.local_coords = true
		sparks.gravity = Vector2.ZERO
		sparks.initial_velocity_min = 70.0
		sparks.initial_velocity_max = 120.0
		sparks.spread = 10.0
		sparks.fixed_fps = 20
		sparks.use_fixed_seed = true
		sparks.seed = 644
		var pixel := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		pixel.fill(Color("9eefff"))
		sparks.texture = ImageTexture.create_from_image(pixel)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.5, 0.9, 1.0, 0.9))
		ramp.set_color(1, Color(0.1, 0.4, 1.0, 0.0))
		sparks.color_ramp = ramp
		jet.add_child(sparks)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		jet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enabled = next_enabled
	if not enabled:
		clear()


func sync_frame(mount: AnimatedSprite2D) -> void:
	if not enabled or mount == null or not mount.visible or mount.sprite_frames == null:
		clear()
		return
	var next_direction := str(mount.animation).trim_prefix("walk_").trim_prefix("idle_")
	if not AXES.has(next_direction):
		clear()
		return
	var moving := str(mount.animation).begins_with("walk_")
	if next_direction != direction:
		sparks.restart(true)
	direction = next_direction
	var jet_parent: Node = mount if direction == "down" else get_parent()
	if jet.get_parent() != jet_parent:
		jet.reparent(jet_parent, false)
		jet_parent.move_child(jet, 0)
	jet.show_behind_parent = direction == "down"
	active = moving
	sparks.emitting = active
	var bob := Vector2(0, 2 * (mount.frame % 2)) if moving else Vector2.ZERO
	center = CENTERS[direction] - Vector2(96, 96) + bob
	jet.position = NOZZLES[direction] - Vector2(96, 96) + bob
	jet.axis = AXES[direction]
	sparks.direction = AXES[direction]
	visible = active or energy > 0.0
	jet.visible = visible
	set_process(visible)
	queue_redraw()
	jet.queue_redraw()


func clear() -> void:
	active = false
	energy = 0.0
	visible = false
	set_process(false)
	if jet != null:
		jet.visible = false
		sparks.emitting = false
		sparks.restart(true)
		sparks.emitting = false


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	clock += delta
	energy = move_toward(energy, 1.0 if active else 0.0, delta * (8.0 if active else 12.0))
	if energy <= 0.0 and not active:
		clear()
		return
	jet.energy = energy
	jet.clock = clock
	sparks.modulate.a = energy
	queue_redraw()
	jet.queue_redraw()


func _draw() -> void:
	if energy <= 0.0 or direction == "down":
		return # The forward-facing body hides the turbine.
	var pulse := 0.9 + sin(floor(clock * 16.0) * 1.3) * 0.1
	if direction != "up":
		# Illuminate the sprite's actual two turbine slits in side view.
		var side: float = AXES[direction].x
		for y in [-3, 1]:
			var a := center + Vector2(-3 * side, y)
			var b := center + Vector2(side, y)
			draw_line(a, b, Color(0.1, 0.35, 1.0, 0.32 * energy), 5.0, false)
			draw_line(a, b, Color(0.25, 0.85, 1.0, energy * pulse), 2.0, false)
		return
	var ring := PackedVector2Array()
	var radius := Vector2(8, 7)
	for i in range(9):
		var angle := i * TAU / 8.0
		ring.append((center + Vector2(cos(angle), sin(angle)) * radius).round())
	draw_polyline(ring, Color(0.1, 0.35, 1.0, 0.28 * energy), 4.0, false)
	draw_polyline(ring, Color(0.15, 0.8, 1.0, 0.85 * energy * pulse), 2.0, false)
	var core := PackedVector2Array()
	for point: Vector2 in ring:
		core.append((center + (point - center) * 0.48).round())
	draw_colored_polygon(core, Color(0.68, 0.98, 1.0, 0.82 * energy * pulse))


func _exit_tree() -> void:
	# Jet is a sibling layer, not owned by this foreground node.
	if is_instance_valid(jet) and not jet.is_queued_for_deletion():
		jet.queue_free()
