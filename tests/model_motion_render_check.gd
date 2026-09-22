extends "res://tools/sprite_factory/measure_model_grounding.gd"
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
const Profiles = preload("res://scripts/battle/battle_ui/reviewed_motion_placement.json")

func _vertices(meshes: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in meshes:
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(mesh.global_transform * vertex)
	return points

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".grounding.json"))
	var world := Node3D.new()
	root.add_child(world)
	for entry: Dictionary in catalog:
		var hash := FileAccess.get_sha256(entry.runtime_path)
		var placement := Placement.resolve(entry, calibration.entries[entry.species], hash)
		var clips := Motion.resolve(Profiles.data[entry.species], placement, hash, entry.action_timing)
		assert(not clips.is_empty(), "Reviewed profile did not bind: " + str(entry.species))
		var actor: Node3D = load(entry.runtime_path).instantiate()
		world.add_child(actor)
		actor.scale = Vector3.ONE * float(placement.scale)
		actor.rotation.y = deg_to_rad(placement.yaw_degrees)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		for action in clips:
			var duration: float = player.get_animation(action).length
			player.play(action)
			player.pause()
			var clearance := INF
			# Independent half-frame sweep, not the samples used by the baker.
			for frame in ceili(duration * 60):
				var time := minf((frame + 0.5) / 60.0, duration)
				actor.position.y = placement.lift + Motion.offset(clips, action, time)
				await _pose(player, skeletons, time)
				clearance = minf(clearance, _minimum(meshes))
			assert(clearance >= .015, str(entry.species) + ": " + action + " floor=" + str(clearance))
			assert(player.get_animation(action).length == duration)
			print("MOTION_CLEARANCE ", entry.species, " ", action, " ", clearance)
		# Verify the full corrected mesh at the join, not only its lowest vertex.
		player.play("faint_start")
		player.pause()
		var end: float = player.get_animation("faint_start").length
		actor.position.y = placement.lift + Motion.offset(clips, "faint_start", end)
		await _pose(player, skeletons, end)
		var ending := _vertices(meshes)
		player.play("faint_loop")
		player.pause()
		actor.position.y = placement.lift + Motion.offset(clips, "faint_loop", 0)
		await _pose(player, skeletons, 0)
		var beginning := _vertices(meshes)
		assert(ending.size() == beginning.size())
		var seam := 0.0
		for vertex in ending.size():
			seam = maxf(seam, ending[vertex].distance_to(beginning[vertex]))
		assert(seam < .003, "Faint seam: " + str(seam))
		print("MOTION_FAINT_SEAM ", entry.species, " ", seam)
		# Full chronological sequence at normal and accelerated playback. Includes
		# actual eased descent into sleep and upward clearance on wake/attack.
		for speed in [1.0, 4.0]:
			var offset := 0.0
			for action in ["idle", "sleep", "idle", "physical_attack", "idle", "faint_start", "faint_loop", "faint_loop"]:
				player.play(action)
				player.pause()
				var duration := player.get_animation(action).length
				for frame in ceili(duration * 30 / speed) + 1:
					var time := minf(frame * speed / 30, duration)
					offset = Motion.advance(offset, Motion.offset(clips, action, time), speed / 30)
					actor.position.y = placement.lift + offset
					await _pose(player, skeletons, time)
					assert(_minimum(meshes) >= .015, "%s %s speed=%s" % [entry.species, action, speed])
		print("MOTION_TRANSITIONS_OK ", entry.species)
		actor.free()
	world.free()
	print("MODEL_MOTION_RENDER_OK")
	quit()
