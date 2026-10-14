extends RefCounted
## Static arena bounds, prepared once. No physics helpers or material mutations.
var arena_ref: WeakRef
var grass: Array[AABB] = []
var props: Array[AABB] = []
var prop_batches: Array[Dictionary] = []
const MARGIN := 0.4
const MAX_LIFT := 12.0

func prepare(arena: Node3D) -> void:
	if arena_ref != null and arena_ref.get_ref() == arena:
		return
	grass.clear()
	props.clear()
	prop_batches.clear()
	arena_ref = weakref(arena) if is_instance_valid(arena) else null
	if is_instance_valid(arena):
		_collect(arena, false)

func _collect(node: Node, is_grass: bool) -> void:
	if node is Node3D and not node.is_visible_in_tree():
		return
	is_grass = is_grass or node.name == "SharedForestGrass"
	if node is MultiMeshInstance3D and not is_grass and node.multimesh != null and node.multimesh.mesh is BoxMesh:
		# Stadium walls, stairs and overhead beams share one draw batch. Its
		# combined bounds fill the empty space between them, including the court.
		var boxes: Array[AABB] = []
		var batch: MultiMesh = node.multimesh
		var count := batch.instance_count if batch.visible_instance_count<0 else mini(batch.instance_count,batch.visible_instance_count)
		for i in count:
			var box: AABB = node.global_transform*batch.get_instance_transform(i)*batch.mesh.get_aabb()
			if box.size.y>.35: boxes.append(box.grow(MARGIN))
		if not boxes.is_empty():
			var bounds := boxes[0]
			for box in boxes: bounds=bounds.merge(box)
			prop_batches.append({"bounds":bounds,"boxes":boxes})
	elif node is MeshInstance3D or node is MultiMeshInstance3D:
		var box: AABB = node.global_transform * node.get_aabb()
		# Flat ground/water is the shot's floor, not an upright obstruction.
		if box.size.y > 0.35 and node.name != "MeshTerrain":
			if is_grass: grass.append(box.grow(MARGIN))
			else: props.append(box.grow(MARGIN))
	for child in node.get_children():
		_collect(child, is_grass)

func apply(camera: Camera3D, focus: Vector3, overview: Transform3D, weight: float) -> void:
	if weight <= 0.0 or (grass.is_empty() and props.is_empty() and prop_batches.is_empty()):
		return
	var original := camera.transform
	var eye := original.origin
	var minimum := eye.y
	# Batched grass has holes around the spawn area. Protect the foreground
	# ray without treating that conservative whole-batch box as solid foliage
	# around the Pokémon itself.
	var lens_fraction := minf(0.6, 3.0 / maxf(eye.distance_to(focus), 0.01))
	var lens_end := eye.lerp(focus, lens_fraction)
	for box in grass:
		var interval := _xz_interval(box, eye, lens_end)
		if interval.x < 0.0: continue
		for fraction in [interval.x, interval.y]:
			var t: float = fraction * lens_fraction
			minimum = maxf(minimum, (box.end.y - focus.y * t) / (1.0 - t))
	minimum = maxf(minimum,_prop_minimum(props,eye,focus))
	for batch in prop_batches:
		var bounds: AABB = batch.bounds
		if bounds.intersects_segment(eye,focus)!=null:
			minimum = maxf(minimum,_prop_minimum(batch.boxes,eye,focus))
	if minimum <= eye.y + 0.001:
		return
	if minimum > eye.y + MAX_LIFT:
		# An enclosing wall cannot provide the authored close shot. The ready
		# overview is preferable to displaying scenery in front of the action.
		camera.transform = original.interpolate_with(overview, weight)
		return
	camera.position.y = minimum + 0.05
	camera.look_at(focus)
	camera.transform = original.interpolate_with(camera.transform, weight)

static func _prop_minimum(boxes: Array[AABB], eye: Vector3, focus: Vector3) -> float:
	var minimum := eye.y
	for box in boxes:
		# Roofs above the complete ray are not camera obstructions.
		if box.has_point(focus) or box.intersects_segment(eye,focus)==null: continue
		var interval := _xz_interval(box,eye,focus)
		for t in [interval.x,interval.y]:
			if t>=0 and t<.995:
				minimum=maxf(minimum,(box.end.y-focus.y*t)/(1.-t))
	return minimum

static func _xz_interval(box: AABB, start: Vector3, finish: Vector3) -> Vector2:
	var low := 0.0
	var high := 1.0
	for axis in [0, 2]:
		var distance: float = finish[axis] - start[axis]
		if absf(distance) < 0.0001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]:
				return Vector2(-1, -1)
			continue
		var a: float = (box.position[axis] - start[axis]) / distance
		var b: float = (box.end[axis] - start[axis]) / distance
		low = maxf(low, minf(a, b))
		high = minf(high, maxf(a, b))
		if low > high: return Vector2(-1, -1)
	return Vector2(low, high)
