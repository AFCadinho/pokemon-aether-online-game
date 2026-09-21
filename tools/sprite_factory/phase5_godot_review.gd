extends SceneTree
## Offline external-GLB diagnostic. Run in the generated, autoload-free project.
var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _bounds(model: Node) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform * vertex
				if first:
					box = AABB(point, Vector3.ZERO)
					first = false
				else:
					box = box.expand(point)
	return box

func _sample(model: Node, player: AnimationPlayer, action: String, fraction: float) -> AABB:
	player.stop()
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(player.get_animation(action).length * fraction, true)
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw
	return _bounds(model)

func _signature(model: Node) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count():
			result.append(skeleton.get_bone_pose(bone))
	return result

func _same_pose(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in a.size():
		if not a[index].is_equal_approx(b[index]):
			return false
	return true

func _review(entry: Dictionary, output: String) -> Dictionary:
	var record := {"species": entry.species, "runtime_approved": false, "errors": [], "poses": []}
	if FileAccess.get_sha256(entry.path) != entry.glb_sha256:
		record.errors.append("GLB hash mismatch")
		return record
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(entry.path, state) != OK:
		record.errors.append("GLB parse failed")
		return record
	var model := document.generate_scene(state)
	if model == null:
		record.errors.append("Scene generation failed")
		return record
	world.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		record.errors.append("Expected one AnimationPlayer")
		model.free()
		return record
	var player: AnimationPlayer = players[0]
	record["clips"] = {}
	var midpoints := {}
	for action: String in entry.animations:
		if not player.has_animation(action):
			record.errors.append("Missing clip: " + action)
			continue
		var duration := player.get_animation(action).length
		if absf(duration - float(entry.animations[action].duration)) > 0.02:
			record.errors.append("Timing mismatch: " + action)
		var samples := []
		var initial: Array = []
		for fraction in [0.0, 0.5, 1.0]:
			var box: AABB = await _sample(model, player, action, fraction)
			if not box.position.is_finite() or not box.size.is_finite() or box.size.length() <= 0:
				record.errors.append("Invalid posed geometry: " + action)
			if fraction == 0.0:
				initial = _signature(model)
			elif fraction == 0.5:
				midpoints[action] = _signature(model)
			samples.append({"fraction": fraction, "min": [box.position.x, box.position.y, box.position.z],
				"size": [box.size.x, box.size.y, box.size.z]})
		record.clips[action] = {"duration": duration, "tracks": player.get_animation(action).get_track_count(),
			"bone_pose_changes": not _same_pose(initial, midpoints[action]), "samples": samples}
	var reverse := midpoints.keys()
	reverse.reverse()
	for action: String in reverse:
		await _sample(model, player, action, 0.5)
		if not _same_pose(midpoints[action], _signature(model)):
			record.errors.append("Pose depends on previous clip: " + action)
	record["pose_policy"] = "reset_skeleton_before_clip; reverse-order midpoint regression"
	var poses := [["idle", 0.0, "front"], ["idle", 0.5, "back"],
		["special_attack", 0.5, "front"], ["sleep", 0.5, "front"], ["faint_start", 1.0, "front"]]
	var framing := AABB()
	var first := true
	for pose in poses:
		if not player.has_animation(pose[0]):
			continue
		var box: AABB = await _sample(model, player, pose[0], pose[1])
		framing = box if first else framing.merge(box)
		first = false
	camera.size = maxf(framing.size.length() * 1.12, 0.1)
	var target := framing.get_center()
	for pose in poses:
		if not player.has_animation(pose[0]):
			record.poses.append({"action": pose[0], "view": pose[2], "status": "missing"})
			continue
		await _sample(model, player, pose[0], pose[1])
		var direction := Vector3(3, 2, 7) if pose[2] == "front" else Vector3(-3, 2, -7)
		camera.position = target + direction.normalized() * camera.size * 3
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		var image := str(entry.species) + "-" + str(pose[0]) + "-" + str(pose[2]) + ".png"
		if root.get_texture().get_image().save_png(output.path_join(image)) != OK:
			record.errors.append("Screenshot failed: " + image)
		record.poses.append({"action": pose[0], "view": pose[2], "image": image})
	record["missing_actions"] = entry.missing_actions
	record["material_limitations"] = entry.material_limitations
	model.free()
	return record

func _run() -> void:
	var output := OS.get_environment("POKEAETHER_PHASE5_REVIEW")
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("Supply external review directory and a rendering display")
		quit(2)
		return
	if FileAccess.file_exists(output.path_join("godot-review.json")):
		printerr("Refusing to overwrite completed review")
		quit(2)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("catalog.json")))
	root.size = Vector2i(512, 512)
	DisplayServer.window_set_title("Phase 5 — diagnostic only")
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.12, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	for rotation in [Vector3(-50, -30, 0), Vector3(-25, 140, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = 1.2 if rotation.y < 0 else 0.5
		world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 1000
	world.add_child(camera)
	camera.current = true
	var report := {"runtime_approved": false, "scope": "native_scale_autofit_not_battle_framing",
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "entries": []}
	var failed := false
	for entry: Dictionary in catalog.entries:
		if entry.status != "exported_for_review":
			report.entries.append({"species": entry.species, "status": entry.status})
			failed = failed or entry.status == "blocked"
			continue
		var result: Dictionary = await _review(entry, output)
		report.entries.append(result)
		failed = failed or not result.errors.is_empty()
		print("REVIEW ", entry.species, " errors=", result.errors)
	var file := FileAccess.open(output.path_join("godot-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	world.free()
	quit(1 if failed else 0)
