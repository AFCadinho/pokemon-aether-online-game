extends SceneTree
## Project manually selected lip/surface pixels onto the captured skinned mesh.
## Weighted bone offsets follow linear skin deformation; blend shapes are rejected.
## Output is an unapproved proposal and always requires a new visual review.
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
var options := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] not in ["--catalog", "--input", "--capture", "--landmarks", "--output", "--part"]: continue
		if i + 1 >= args.size():
			printerr("Missing value for ", args[i])
			quit(1)
			return
		options[args[i]] = args[i + 1]
	for key in ["--catalog", "--input", "--capture", "--landmarks", "--output"]:
		if not options.has(key):
			printerr("Missing ", key)
			quit(1)
			return
	_run.call_deferred()

func _transform(raw: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(raw[0], raw[1], raw[2]), Vector3(raw[3], raw[4], raw[5]), Vector3(raw[6], raw[7], raw[8])), Vector3(raw[9], raw[10], raw[11]))

static func _intersection(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Array:
	var edge_b := b - a
	var edge_c := c - a
	var cross_direction := direction.cross(edge_c)
	var determinant := edge_b.dot(cross_direction)
	if absf(determinant) < 1e-12: return []
	var delta := origin - a
	var u := delta.dot(cross_direction) / determinant
	if u < 0.0 or u > 1.0: return []
	var cross_delta := delta.cross(edge_b)
	var v := direction.dot(cross_delta) / determinant
	if v < 0.0 or u + v > 1.0: return []
	var distance := edge_c.dot(cross_delta) / determinant
	return [distance, 1.0 - u - v, u, v] if distance > 0.0 else []

func _fail(message: String) -> void:
	printerr(message)
	quit(1)

func _run() -> void:
	var proposal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(options["--input"]))
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(options["--capture"]))
	var landmarks: Array = JSON.parse_string(FileAccess.get_file_as_string(options["--landmarks"]))
	if landmarks.is_empty() or proposal.identity != sheet.identity or proposal.runtime_sha256 != sheet.runtime_sha256:
		_fail("Landmarks are empty or capture and proposal revisions differ")
		return
	if sheet.get("pose_sampling", "") != "forward_from_start_v1":
		_fail("Render a fresh capture with forward pose sampling and mesh visibility")
		return
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(options["--catalog"]))
	if entries is Dictionary: entries = entries.entries
	var entry := {}
	for candidate: Dictionary in entries:
		if Catalog.entry_key(candidate) == str(proposal.identity):
			entry = candidate
			break
	if entry.is_empty() or str(entry.runtime_sha256) != str(proposal.runtime_sha256) or FileAccess.get_sha256(str(entry.runtime_path)) != str(proposal.runtime_sha256) or Catalog.resolve(str(proposal.identity), str(proposal.runtime_sha256)).is_empty():
		_fail("Missing or unapproved runtime revision")
		return
	var packed := ResourceLoader.load(str(entry.runtime_path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var actor := packed.instantiate() as Node3D
	root.add_child(actor)
	preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor, str(proposal.identity), str(proposal.runtime_sha256))
	var combined := {}
	var evidence := []
	var total := 0.0
	for landmark: Dictionary in landmarks:
		var capture := {}
		for value: Dictionary in sheet.captures:
			if value.action == landmark.action and int(value.column) == int(landmark.column): capture = value
		var factor := float(landmark.get("weight", 1.0))
		if capture.is_empty() or factor <= 0.0 or not is_finite(factor):
			_fail("Invalid landmark pose or weight")
			return
		var pixel: Array = landmark.pixel
		if pixel.size() != 2 or not is_finite(float(pixel[0])) or not is_finite(float(pixel[1])) or float(pixel[0]) < 0 or float(pixel[0]) >= float(sheet.width) or float(pixel[1]) < 0 or float(pixel[1]) >= float(sheet.height):
			_fail("Landmark pixel is outside the capture")
			return
		var camera := _transform(capture.camera)
		var tangent := tan(deg_to_rad(float(capture.fov)) * 0.5)
		var local := Vector3((2.0 * float(pixel[0]) / float(sheet.width) - 1.0) * float(sheet.width) / float(sheet.height) * tangent, (1.0 - 2.0 * float(pixel[1]) / float(sheet.height)) * tangent, -1.0)
		var direction := (camera.basis * local).normalized()
		var closest := INF
		var chosen := {}
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null or mesh.skin == null: continue
			var mesh_path := str(actor.get_path_to(mesh))
			if not capture.get("meshes", {}).has(mesh_path):
				_fail("Capture does not contain mesh state: " + mesh_path)
				return
			var state: Dictionary = capture.meshes[mesh_path]
			if not state.visible: continue
			if landmark.has("mesh_contains") and str(landmark.mesh_contains) not in mesh_path: continue
			if landmark.has("mesh_excludes") and str(landmark.mesh_excludes) in mesh_path: continue
			for value: float in state.blend_shapes:
				if absf(value) > 0.000001:
					_fail("Active blend shape cannot be represented by bone offsets: " + mesh_path)
					return
			var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
			if skeleton == null: continue
			var bindings := {}
			for bind in mesh.skin.get_bind_count():
				var bone := str(mesh.skin.get_bind_name(bind))
				if bone.is_empty(): bone = skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
				if capture.bones.has(bone): bindings[bind] = {"bone":bone, "pose":_transform(capture.bones[bone]), "bind":mesh.skin.get_bind_pose(bind)}
			for surface in mesh.mesh.get_surface_count():
				if landmark.has("surface") and int(landmark.surface) != surface: continue
				if mesh.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if vertices.is_empty() or bones.is_empty(): continue
				if weights.size() != bones.size() or bones.size() % vertices.size() != 0:
					_fail("Invalid skin influence arrays: " + mesh_path)
					return
				var stride := bones.size() / vertices.size()
				var points := PackedVector3Array()
				var definitions := []
				for vertex in vertices.size():
					var point := Vector3.ZERO
					var group := []
					var sum_weight := 0.0
					for influence in stride:
						var weight := float(weights[vertex * stride + influence])
						if not is_finite(weight) or weight < 0:
							_fail("Invalid skin weight: " + mesh_path)
							return
						if weight == 0.0: continue
						var bind: int = bones[vertex * stride + influence]
						if not bindings.has(bind):
							_fail("Missing skin binding in capture: " + mesh_path)
							return
						var binding: Dictionary = bindings[bind]
						var offset: Vector3 = binding.bind * vertices[vertex]
						point += (binding.pose * offset) * weight
						sum_weight += weight
						group.append({"bone":binding.bone, "offset":offset, "weight":weight})
					if sum_weight <= 0.0:
						_fail("Unweighted vertex in skinned mesh: " + mesh_path)
						return
					points.append(point / sum_weight)
					for definition: Dictionary in group: definition.weight /= sum_weight
					definitions.append(group)
				var index_count := indices.size() if not indices.is_empty() else vertices.size()
				for triangle in range(0, index_count - 2, 3):
					var ids := [triangle, triangle + 1, triangle + 2]
					if not indices.is_empty(): ids = [indices[triangle], indices[triangle + 1], indices[triangle + 2]]
					var hit := _intersection(camera.origin, direction, points[ids[0]], points[ids[1]], points[ids[2]])
					if hit.is_empty() or float(hit[0]) >= closest: continue
					closest = float(hit[0])
					var group := []
					for corner in 3:
						for definition: Dictionary in definitions[ids[corner]]:
							var item := definition.duplicate()
							item.weight *= float(hit[corner + 1])
							group.append(item)
					chosen = {"mesh":mesh_path, "surface":surface, "triangle":triangle / 3, "vertex_indices":ids, "barycentric":hit.slice(1), "definitions":group, "distance":closest}
		if chosen.is_empty():
			_fail("No skinned surface under landmark: " + JSON.stringify(landmark))
			return
		for definition: Dictionary in chosen.definitions:
			var weight := float(definition.weight) * factor
			if weight <= 1e-12: continue
			var bone := str(definition.bone)
			if not combined.has(bone): combined[bone] = {"weight":0.0, "weighted_offset":Vector3.ZERO}
			combined[bone].weight += weight
			combined[bone].weighted_offset += definition.offset * weight
		total += factor
		chosen.erase("definitions")
		chosen.merge(landmark, true)
		evidence.append(chosen)
	var group := []
	for bone: String in combined:
		var value: Dictionary = combined[bone]
		var offset: Vector3 = value.weighted_offset / float(value.weight)
		group.append({"bone":bone, "offset":[offset.x, offset.y, offset.z], "weight":float(value.weight) / total})
	proposal.candidate_parts[str(options.get("--part", "mouth"))] = [group]
	proposal.review_status = "unreviewed"
	proposal["manual_surface_landmarks"] = {"capture_sha256":FileAccess.get_sha256(options["--capture"]), "landmarks":evidence, "method":"ray_triangle_barycentric_skin_binding"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(options["--output"]).get_base_dir()))
	var file := FileAccess.open(options["--output"], FileAccess.WRITE)
	file.store_string(JSON.stringify(proposal, "\t", true) + "\n")
	file.close()
	print("ATTACHMENT_SURFACE_PROPOSAL ", proposal.identity, " bones=", group.size(), " landmarks=", evidence.size())
	actor.free()
	quit()
