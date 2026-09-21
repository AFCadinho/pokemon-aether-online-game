extends SceneTree
## Offline, render-synchronized pose measurement; never updates active calibration.
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
var failures: Array[String] = []
var output_prefix := ""
var review_camera: Camera3D

func _init() -> void:
	_run.call_deferred()

func _minimum(meshes: Array) -> float:
	var minimum := INF
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		if posed == null:
			return NAN
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				minimum = minf(minimum, (mesh.global_transform * vertex).y)
	return minimum

func _pose(player: AnimationPlayer, skeletons: Array, time: float) -> void:
	player.seek(time, true)
	for skeleton: Skeleton3D in skeletons:
		skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw

func _measure(entry: Dictionary, scene: Node3D) -> Dictionary:
	var path: String = entry.get("runtime_path", "")
	var hash := FileAccess.get_sha256(path)
	var placement := Placement.resolve(entry, {}, hash)
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null or placement.is_empty():
		failures.append(str(entry.get("species", "?")) + ": invalid scene or placement")
		return {}
	var actor := packed.instantiate() as Node3D
	if actor == null:
		failures.append(str(entry.species) + ": expected Node3D")
		return {}
	scene.add_child(actor)
	actor.scale = Vector3.ONE * placement.scale
	actor.rotation.y = deg_to_rad(placement.yaw_degrees)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or meshes.is_empty():
		failures.append(str(entry.species) + ": expected meshes and one AnimationPlayer")
		actor.free()
		return {}
	var player: AnimationPlayer = players[0]
	var clips := {}
	# All declared clips are measured, but only idle determines the candidate
	# resting lift. Attack/faint motion must not make the resting model float.
	for action: String in entry.get("action_timing", {}):
		if not player.has_animation(action):
			failures.append(str(entry.species) + ": missing clip " + action)
			continue
		var duration := player.get_animation(action).length
		if not is_finite(duration) or duration <= 0.0 or duration > 120.0:
			failures.append(str(entry.species) + ": invalid clip duration " + action)
			continue
		player.play(action)
		player.pause()
		var minimum := INF
		var minimum_time := 0.0
		var count := ceili(duration * 60.0)
		for sample in count + 1:
			var time := minf(sample / 60.0, duration)
			await _pose(player, skeletons, time)
			var value := _minimum(meshes)
			if not is_finite(value):
				failures.append(str(entry.species) + ": invalid posed geometry " + action)
				break
			if value < minimum:
				minimum = value
				minimum_time = time
		clips[action] = {"minimum_y": minimum, "minimum_time": minimum_time, "samples": count + 1, "duration": duration}
	var record := {}
	if clips.has("idle") and is_finite(float(clips.idle.minimum_y)):
		var lift := maxf(0.0, 0.025 - float(clips.idle.minimum_y))
		# Independent half-frame idle sweep checks the candidate between samples.
		actor.position.y = lift
		player.play("idle")
		player.pause()
		var verification := INF
		for sample in ceili(float(clips.idle.duration) * 60.0):
			await _pose(player, skeletons, minf((sample + 0.5) / 60.0, clips.idle.duration))
			verification = minf(verification, _minimum(meshes))
		for action in clips:
			clips[action].clearance_with_idle_lift = clips[action].minimum_y + lift
		if not is_finite(verification) or verification < 0.015:
			failures.append(str(entry.species) + ": idle half-frame verification failed")
		await _pose(player, skeletons, 0.0)
		var safe_name := str(entry.species).validate_filename()
		for angle in [0, 90, 180]:
			review_camera.position = Vector3(0, 3, 10).rotated(Vector3.UP, deg_to_rad(angle))
			review_camera.look_at(Vector3(0, 1.5, 0))
			await RenderingServer.frame_post_draw
			var image_path := output_prefix + "." + safe_name + "." + str(angle) + ".png"
			if FileAccess.file_exists(image_path) or root.get_texture().get_image().save_png(image_path) != OK:
				failures.append(str(entry.species) + ": could not save new review image")
		record = {"sha256": hash, "scale": placement.scale, "yaw_degrees": placement.yaw_degrees,
			"candidate_lift": lift, "idle_verification_minimum": verification,
			"idle_verified": is_finite(verification) and verification >= 0.015,
			"policy": "idle_clearance_preserve_existing_flight", "sample_hz": 60, "clips": clips}
	else:
		failures.append(str(entry.species) + ": no measurable idle clip")
	if FileAccess.get_sha256(path) != hash:
		failures.append(str(entry.species) + ": runtime scene changed while measuring")
	actor.free()
	return record

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Rendered skinning is required; do not use --headless")
		quit(2)
		return
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var output := OS.get_environment("POKEAETHER_GROUNDING_REVIEW_OUTPUT")
	output_prefix = output
	if not output.is_absolute_path() or FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		printerr("Provide a NEW absolute POKEAETHER_GROUNDING_REVIEW_OUTPUT file")
		quit(2)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array or data.is_empty():
		quit(2)
		return
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	review_camera = camera
	scene.add_child(camera)
	camera.position = Vector3(0, 3, 12)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	preload("res://scripts/battle/battle_ui/material_response.gd").apply_neutral_lighting(scene)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 30)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.35, 0.35, 0.35)
	floor_mesh.material_override = floor_material
	scene.add_child(floor_mesh)
	var results := {}
	for entry in data:
		if not entry is Dictionary or not entry.get("species") is String or results.has(entry.species):
			failures.append("Invalid or duplicate model entry")
			continue
		results[entry.species] = await _measure(entry, scene)
	var report := {"review_schema": 1, "not_runtime_calibration": true, "entries": results, "errors": failures}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GROUNDING_REVIEW ", output, " errors=", failures.size())
	scene.free()
	quit(0 if failures.is_empty() else 1)
