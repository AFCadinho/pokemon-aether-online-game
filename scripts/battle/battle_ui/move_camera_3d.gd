extends RefCounted
## Draco Meteor shots follow the VFX's native clock, including pause/recovery.
var effect: Node
var actor := ""
var target := ""

func begin(owner: Node, source: String, destination: String) -> void:
	effect = owner
	actor = source
	target = destination

func clear(owner: Node = null) -> bool:
	if owner != null and effect != owner: return false
	effect = null
	return true

func apply(stage: Node) -> void:
	if not is_instance_valid(effect) or effect.done: return
	if not effect.clock.is_valid() or not effect.valid.is_valid() or not effect.valid.call(): return
	var seconds: float = effect.clock.call()
	var p := clampf(seconds / effect.duration, 0.0, 1.0)
	if p >= 1.0: return
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

func _distance(camera: Camera3D, radius: float) -> float:
	# Godot keeps vertical FOV by default. Account for narrow viewports too.
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5) * minf(aspect, 1.0)
	return maxf(3.0, radius / maxf(tangent, 0.1))
