extends RefCounted
## Shots follow the VFX's native clock, including pause and recovery.
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const ZCinema = preload("res://scripts/battle/battle_ui/z_move_cinema_3d.gd")
const PROFILES := {
	"dracometeor":"meteor", "moonblast":"moon", "focusblast":"orb", "shadowball":"orb",
	"hyperbeam":"beam", "solarbeam":"beam", "flashcannon":"beam", "electroshot":"beam",
	"pyroball":"kick", "blizzard":"field", "hurricane":"field", "terastarstorm":"field",
}
var effect: Node
var actor := ""
var target := ""
var z_context := {}

func supports(key: String) -> bool:
	return ZCinema.supports(key) or PROFILES.has(key) or not Recipes.get_recipe(key).get("camera", "").is_empty()

func begin(owner: Node, source: String, destination: String) -> void:
	effect = owner
	actor = source
	target = destination
	z_context.clear()

func clear(owner: Node = null) -> bool:
	if owner != null and effect != owner: return false
	effect = null
	z_context.clear()
	return true

func apply(stage: Node) -> void:
	if not is_instance_valid(effect) or effect.done: return
	if not effect.clock.is_valid() or not effect.valid.is_valid() or not effect.valid.call(): return
	var seconds: float = effect.clock.call()
	var p := clampf(seconds / effect.duration, 0.0, 1.0)
	if p >= 1.0: return
	if ZCinema.supports(effect.key):
		if z_context.is_empty():
			z_context = effect.anchors.call().duplicate(true)
			z_context.actor_body = stage._move_bounds(actor).duplicate(true)
			z_context.target_body = stage._move_bounds(target).duplicate(true)
		var overview: Transform3D = stage.camera.transform
		var shot := ZCinema.shot(effect, stage.camera, z_context, seconds)
		var pose := _fit(stage.camera, shot.points, shot.direction)
		var recovery := smoothstep(maxf(0.86, effect.impact / effect.duration + 0.04), 1.0, p)
		stage.camera.transform = pose.interpolate_with(overview, recovery)
		return
	if effect.key != "dracometeor":
		_apply_catalog(stage, seconds, p)
		return
	var a: Dictionary = stage._move_bounds(actor)
	var b: Dictionary = stage._move_bounds(target)
	var anchors: Dictionary = effect.anchors.call()
	# Once released, the orb/rain uses captured world positions. Frame those
	# same positions even when the caster's mouth or a dodging target moves.
	var sky: Vector3 = effect.sky if effect.released else anchors.source.lerp(anchors.target, 0.55) + Vector3.UP * 4.3
	var forward: Vector3 = b.position - a.position
	forward.y = 0.0
	if forward.length_squared() < 0.01: return
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var camera: Camera3D = stage.camera
	var overview := camera.transform
	var focus: Vector3
	var position: Vector3
	# Cut in front of the caster, with a small dolly during the charge.
	# Keep both shots on the same side of the combat axis.
	if p < 0.43:
		var charge := clampf(seconds / maxf(effect.launch, 0.01), 0.0, 1.0)
		var body_center: Vector3 = a.position + Vector3.UP * float(a.height) * 0.58
		focus = body_center.lerp(anchors.source, 0.35)
		var body_radius := maxf(float(a.height) * 0.7, float(a.radius) * 1.5 + 0.5)
		# Draco's orb has a fixed world size: a small caster still needs room
		# for the charge glow, rather than filling the screen with the orb.
		var glow_radius: float = stage.DracoMeteorEffect.CHARGE_RADIUS * effect.presentation_scale * 2.5
		var radius := maxf(body_radius + focus.distance_to(body_center), glow_radius + focus.distance_to(anchors.source))
		var distance := _distance(camera, radius) * lerpf(1.08, 1.0, charge)
		position = focus + (forward + side * 0.72 + Vector3.UP * 0.12).normalized() * distance
		# Widen upward for the ascending orb, before cutting to the rain.
		var ascent := smoothstep(effect.launch / effect.duration, 0.43, p)
		var wide_focus: Vector3 = focus.lerp(sky, 0.5)
		var wide_distance := _distance(camera, focus.distance_to(sky) * 0.6 + radius * 0.5)
		focus = focus.lerp(wide_focus, ascent)
		position = position.lerp(wide_focus + (forward + side * 0.72 + Vector3.UP * 0.12).normalized() * wide_distance, ascent)
	else:
		# Frame the target, sky burst and satellite landing area together.
		var ground: Vector3 = effect.ground if effect.released else anchors.target_ground
		focus = ground.lerp(sky, 0.5)
		var radius := maxf(ground.distance_to(sky) * 0.6 + 1.3, float(b.height) * 0.8 + float(b.radius))
		position = focus + (-forward * 0.9 + side * 0.85 + Vector3.UP * 0.3).normalized() * _distance(camera, radius)
	camera.position = position
	camera.look_at(focus)
	# Finish inside the move lifetime; preserve the player's orbit and zoom.
	camera.transform = camera.transform.interpolate_with(overview, smoothstep(0.88, 1.0, p))

func _apply_catalog(stage: Node, seconds: float, phase: float) -> void:
	var profile: String = PROFILES.get(effect.key, Recipes.get_recipe(effect.key).get("camera", ""))
	if profile.is_empty(): return
	var a: Dictionary = stage._move_bounds(actor)
	var b: Dictionary = stage._move_bounds(target)
	var anchors: Dictionary = effect.anchors.call()
	var forward: Vector3 = b.position - a.position
	forward.y = 0.0
	if forward.length_squared() < 0.01: return
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var camera: Camera3D = stage.camera
	var overview := camera.transform
	var points: Array[Vector3] = []
	var direction := forward + side * 0.72 + Vector3.UP * 0.2
	var scale_value: float = effect.presentation_scale
	var source: Vector3 = anchors.source
	var aim: Vector3 = anchors.target
	# Recipe projectiles capture their trajectory; misses must keep framing
	# the original aim rather than following the target's dodge.
	if effect.get_script() == stage.ExtendedMoveEffect and effect.launched:
		source = effect.origin
		aim = effect.aim
	elif profile in ["beam", "kick"] and effect.get_script() == stage.StagedMoveEffect and effect.launched:
		source = effect.origin
		aim = effect.aim
	elif profile in ["moon", "orb"] and effect.launched:
		source = effect.launch_origin
	if profile == "field":
		var field: Dictionary = anchors.field
		var center: Vector3 = effect.field_center if effect.captured else field.center
		var radius: float = effect.field_radius if effect.captured else field.radius
		var height_value := 6.0 if effect.key == "terastarstorm" else 3.5
		_append_box(points, center + Vector3.UP * height_value * 0.5, Vector3(radius + 0.6, height_value * 0.5, radius + 0.6))
		# Starstorm's final burst is centered on its victim, not field center.
		if effect.key == "terastarstorm":
			_append_box(points, effect.aim, Vector3(radius + 0.5, 1.5, radius + 0.5))
		_append_body(points, a)
		_append_body(points, b)
		direction = -forward * 0.55 + side + Vector3.UP * 0.8
	elif seconds < effect.launch:
		_append_body(points, a)
		for emitter: Vector3 in anchors.get("sources", [source]):
			_append_box(points, emitter, Vector3.ONE * maxf(0.5, scale_value * effect.emission_scale * 0.7))
		if profile == "moon":
			var moon: Vector3 = anchors.moon_source + Vector3.UP * (1.35 + 0.3 * (scale_value - 1.0))
			_append_box(points, moon, Vector3.ONE * scale_value * 0.5)
	else:
		_append_body(points, b)
		_append_box(points, aim, Vector3.ONE * scale_value * 1.05)
		if profile == "beam":
			_append_body(points, a)
			for emitter: Vector3 in anchors.get("sources", [source]):
				_append_box(points, emitter, Vector3.ONE * scale_value * effect.emission_scale * 0.7)
			# A side angle keeps the complete beam and multiple emitters legible.
			direction = -forward * 0.25 + side + Vector3.UP * 0.3
		else:
			_append_box(points, source, Vector3.ONE * scale_value * effect.emission_scale * 0.7)
			direction = -forward * 0.75 + side + Vector3.UP * 0.25
			if profile == "kick":
				_append_box(points, source.lerp(aim, 0.5) + Vector3.UP * effect.projectile_arc_height, Vector3.ONE * scale_value * effect.emission_scale * 0.8)
				_append_body(points, a)
	# Fitting a fixed shot envelope avoids camera pumping with every particle.
	camera.transform = _fit(camera, points, direction.normalized())
	camera.transform = camera.transform.interpolate_with(overview, smoothstep(0.88, 1.0, phase))

func _append_body(points: Array[Vector3], bounds: Dictionary) -> void:
	var half := Vector3(float(bounds.radius), float(bounds.height) * 0.5, float(bounds.radius))
	_append_box(points, bounds.position + Vector3.UP * half.y, half)

func _append_box(points: Array[Vector3], center: Vector3, half: Vector3) -> void:
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				points.append(center + half * Vector3(x, y, z))

func _fit(camera: Camera3D, points: Array[Vector3], direction: Vector3) -> Transform3D:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points: box = box.expand(point)
	var focus := box.get_center()
	var basis := Basis.looking_at(-direction)
	var size := camera.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5)
	var horizontal := tangent if camera.keep_aspect == Camera3D.KEEP_WIDTH else tangent * aspect
	var vertical := tangent / aspect if camera.keep_aspect == Camera3D.KEEP_WIDTH else tangent
	var distance := 3.0
	for point in points:
		var local := basis.inverse() * (point - focus)
		distance = maxf(distance, local.z + maxf((absf(local.x) + 0.35) / maxf(horizontal, 0.01), (absf(local.y) + 0.35) / maxf(vertical, 0.01)))
	return Transform3D(basis, focus + direction * distance)

func _distance(camera: Camera3D, radius: float) -> float:
	# Godot keeps vertical FOV by default. Account for narrow viewports too.
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5) * minf(aspect, 1.0)
	return maxf(3.0, radius / maxf(tangent, 0.1))
