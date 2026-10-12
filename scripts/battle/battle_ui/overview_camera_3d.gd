extends RefCounted
## Presentation only: fit resting model envelopes above the battle controls.
## Off-centre framing uses a camera transform, so cinematic shots do not inherit
## a projection offset or a changed FOV.
const SAFE_RECT := Rect2(0.14, 0.18, 0.72, 0.55)

static func fit(camera: Camera3D, points: Array[Vector3], focus: Vector3, offset: Vector3, safe: Rect2 = SAFE_RECT) -> Transform3D:
	var basis := Basis.looking_at(-offset.normalized())
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5)
	var horizontal := tangent if camera.keep_aspect == Camera3D.KEEP_WIDTH else tangent * aspect
	var vertical := tangent / aspect if camera.keep_aspect == Camera3D.KEEP_WIDTH else tangent
	var low := Vector2(safe.position.x * 2.0 - 1.0, 1.0 - safe.end.y * 2.0)
	var high := Vector2(safe.end.x * 2.0 - 1.0, 1.0 - safe.position.y * 2.0)
	var center := (low + high) * 0.5
	var distance := offset.length()
	for point in points:
		var local := basis.inverse() * (point - focus)
		# Solve each asymmetric frustum plane for the minimum safe distance.
		distance = maxf(distance, local.z + camera.near + 0.1)
		distance = maxf(distance, (local.x / horizontal + high.x * local.z) / (high.x - center.x))
		distance = maxf(distance, (-local.x / horizontal - low.x * local.z) / (center.x - low.x))
		distance = maxf(distance, (local.y / vertical + high.y * local.z) / (high.y - center.y))
		distance = maxf(distance, (-local.y / vertical - low.y * local.z) / (center.y - low.y))
	return Transform3D(basis, focus + basis.z * distance - basis.x * center.x * horizontal * distance - basis.y * center.y * vertical * distance)

static func resting_points(stage: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in stage._slot_count():
		# Reserve every battle slot while models load or a partner is switching.
		var identity: String = stage.identities[index]
		var data: Dictionary = stage.visual_bounds.get(identity, {}).get("idle", {})
		var box: AABB
		if not data.is_empty():
			box = AABB(Vector3(data.min[0], data.min[1], data.min[2]), Vector3(data.size[0], data.size[1], data.size[2]))
		else:
			if not stage.fallback_effect_bounds.has(identity) and is_instance_valid(stage.world) and is_instance_valid(stage.actors[index]):
				stage._effect_bounds(index) # Populate the existing per-model fallback cache.
			box = stage.fallback_effect_bounds.get(identity, AABB())
			if not box.has_volume(): box = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 2, 1))
		var placement: Dictionary = stage.placements.get(identity, {})
		var scale_value := float(placement.get("scale", 1.0))
		var home: Vector3 = stage._position(index)
		home.y += float(placement.get("lift", 0.0)) + float(placement.get("hover_height", 0.0))
		var direction: Vector3 = stage._position(index + 1 if index % 2 == 0 else index - 1) - stage._position(index)
		var yaw := atan2(direction.x, direction.z) + deg_to_rad(float(placement.get("yaw_degrees", 0.0)))
		var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value), home)
		# Never fit live attack poses, lunge positions or Poké Ball shrink scales:
		# that would move the overview during an action and invalidate 2D anchors.
		box = box.grow(0.12 / maxf(scale_value, 0.001))
		for corner in 8: points.append(transform * box.get_endpoint(corner))
	return points

static func safe_rect(stage: Control) -> Rect2:
	var safe := SAFE_RECT
	if stage.size.y <= 0.0 or stage.get_parent() == null: return safe
	# Read layout, not visibility: hiding the move buttons during an attack must
	# not zoom the camera. Reserve extra room when UI scaling raises the prompt.
	for path in ["%CurrentActionPanel", "%MovesGrid"]:
		var control := stage.get_parent().get_node_or_null(path) as Control
		if control == null or control.size.y <= 0.0: continue
		var top := (stage.get_global_transform().affine_inverse() * control.global_position).y / stage.size.y
		if top > 0.4: safe.end.y = minf(safe.end.y, top - 0.035)
	return safe
