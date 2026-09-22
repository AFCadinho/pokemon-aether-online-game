extends "phase5_godot_review.gd"
## Native/default placement measurements. No runtime calibration or approvals.
var framing: Script
var placement_rules: Script
var motion_rules: Script
var output_dir: String
var overlays: Array[Label] = []
var readability: Dictionary = {}
var corrections: Dictionary = {}
var corrected_hud := false

func _motion_offset(species: String, action: String, time: float) -> float:
	return motion_rules.offset(corrections.get(species, {}).get("clips", {}), action, time)

func _render_frame() -> void:
	# Explicit draws keep offline measurements progressing if the window is hidden.
	await process_frame
	RenderingServer.force_draw(false)

func _sample(model: Node, player: AnimationPlayer, action: String, fraction: float) -> AABB:
	player.stop()
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(player.get_animation(action).length * fraction, true)
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	await _render_frame()
	return _bounds(model)

func _load_actor(entry: Dictionary) -> Node3D:
	if FileAccess.get_sha256(entry.path) != entry.glb_sha256:
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(entry.path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D

func _measure(entry: Dictionary, model: Node3D, player: AnimationPlayer) -> Dictionary:
	var placement: Dictionary = placement_rules.resolve(entry, {}, entry.glb_sha256)
	placement.scale *= float(readability.get(entry.species, 1.0))
	model.scale = Vector3.ONE * float(placement.scale)
	var clips := {}
	var idle_min := INF
	for action: String in entry.animations:
		var duration := player.get_animation(action).length
		var minimum := INF
		var maximum := -INF
		var envelope := AABB()
		var count := ceili(duration * 60.0)
		var minima := []
		for sample in count + 1:
			var box: AABB = await _sample(model, player, action, minf(sample / 60.0, duration) / duration)
			assert(box.position.is_finite() and box.size.is_finite() and box.size.length() > 0)
			minimum = minf(minimum, box.position.y)
			minima.append(box.position.y)
			maximum = maxf(maximum, box.position.y)
			envelope = box if sample == 0 else envelope.merge(box)
		clips[action] = {"duration": duration, "samples": count + 1, "minimum_y": minimum, "minimum_y_samples": minima,
			"maximum_minimum_y": maximum, "envelope_min": [envelope.position.x, envelope.position.y, envelope.position.z],
			"envelope_size": [envelope.size.x, envelope.size.y, envelope.size.z]}
		if action == "idle":
			idle_min = minimum
	assert(is_finite(idle_min))
	var lift := maxf(0.0, 0.025 - idle_min)
	for action in clips:
		clips[action]["clearance_with_idle_lift"] = float(clips[action].minimum_y) + lift
	return {"scale": placement.scale, "yaw_degrees": placement.yaw_degrees,
		"candidate_lift": lift, "clips": clips, "runtime_approved": false,
		"policy": "idle_clearance_only_preserve_source_floating; no per-clip correction"}

func _screen_box(box: AABB) -> Rect2:
	var rectangle := Rect2()
	for index in 8:
		var point := camera.unproject_position(box.get_endpoint(index))
		rectangle = Rect2(point, Vector2.ZERO) if index == 0 else rectangle.expand(point)
	return rectangle

func _draw_hud(index: int, name: String, actor: Node3D, side: int) -> Rect2:
	# Deliberately reproduce current fixed-height presentation anchor, not true bounds.
	var top := camera.unproject_position(actor.position + Vector3(0, 3, 0))
	var bottom := camera.unproject_position(framing.spawn(side))
	var point := Vector2(bottom.x - 90, top.y - 57)
	if corrected_hud:
		var bounds := _screen_box(_bounds(actor))
		point = Vector2(bounds.get_center().x - 90, bounds.position.y - 57)
	point.x = clampf(point.x, 16, root.size.x - 196)
	point.y = clampf(point.y, 62, root.size.y - 275)
	overlays[index].position = point
	overlays[index].text = name + " · HUD anchor proxy"
	return Rect2(point, Vector2(180, 45))

func _validate_motion(entry: Dictionary, model: Node3D, player: AnimationPlayer, measured: Dictionary) -> Dictionary:
	# Independent half-frame samples, not the 60 Hz samples supplied to the baker.
	var result := {}
	for action: String in entry.animations:
		var duration := player.get_animation(action).length
		var minimum := INF
		var count := ceili(duration * 120.0)
		for sample in count + 1:
			var time := minf(sample / 120.0, duration)
			model.position.y = measured.candidate_lift + _motion_offset(entry.species, action, time)
			var box := await _sample(model, player, action, time / duration)
			minimum = minf(minimum, box.position.y)
		result[action] = {"samples": count + 1, "minimum_y": minimum}
	model.position = Vector3.ZERO
	return result

func _shots(entry: Dictionary, model: Node3D, player: AnimationPlayer, measured: Dictionary,
		control: Node3D, control_player: AnimationPlayer, control_measure: Dictionary) -> Array:
	var result := []
	var poses := [["idle", 0.0], ["special_attack", 0.5], ["sleep", 0.5], ["faint_start", 1.0]]
	for arena in ["classic", "stadium"]:
		camera.position = framing.camera_home(arena)
		camera.look_at(framing.camera_target(arena))
		for side in 2:
			model.position = framing.spawn(side) + Vector3(0, measured.candidate_lift, 0)
			control.position = framing.spawn(1 - side) + Vector3(0, control_measure.candidate_lift, 0)
			var direction: Vector3 = framing.spawn(1 - side) - framing.spawn(side)
			model.rotation.y = atan2(direction.x, direction.z) + deg_to_rad(measured.yaw_degrees)
			control.rotation.y = atan2(-direction.x, -direction.z)
			await _sample(control, control_player, "idle", 0)
			for pose in poses:
				if not player.has_animation(pose[0]):
					continue
				model.position.y = measured.candidate_lift + _motion_offset(entry.species, pose[0], player.get_animation(pose[0]).length * pose[1])
				var box: AABB = await _sample(model, player, pose[0], pose[1])
				var screen := _screen_box(box)
				var hud := _draw_hud(0, entry.species, model, side)
				_draw_hud(1, "Dragonite control", control, 1 - side)
				await _render_frame()
				var image := "%s-%s-%s-%s.png" % [entry.species, arena, side, pose[0]]
				assert(root.get_texture().get_image().save_png(output_dir.path_join(image)) == OK)
				result.append({"arena_camera": arena, "side": side, "action": pose[0], "image": image,
					"minimum_y": box.position.y, "in_view": Rect2(Vector2.ZERO, Vector2(root.size)).encloses(screen),
					"model_overlaps_hud_proxy": screen.intersects(hud), "hud_gap_pixels": screen.position.y - hud.end.y,
					"screen_rect": [screen.position.x, screen.position.y, screen.size.x, screen.size.y]})
	return result

func _run() -> void:
	var source_dir := OS.get_environment("POKEAETHER_PHASE5_REVIEW")
	output_dir = OS.get_environment("POKEAETHER_PHASE5_BATTLE_OUTPUT")
	var frontend := OS.get_environment("POKEAETHER_PHASE5_FRONTEND")
	if DisplayServer.get_name() == "headless" or not output_dir.is_absolute_path() or DirAccess.dir_exists_absolute(output_dir):
		printerr("Rendered display and NEW absolute output directory required")
		quit(2)
		return
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
	framing = load(frontend.path_join("scripts/battle/arenas/shared/framing.gd"))
	placement_rules = load(frontend.path_join("scripts/battle/battle_ui/model_placement.gd"))
	motion_rules = load(frontend.path_join("scripts/battle/battle_ui/model_motion_placement.gd"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("catalog.json")))
	var candidates_path := OS.get_environment("POKEAETHER_PHASE5_CANDIDATES")
	if not candidates_path.is_empty():
		var candidates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(candidates_path))
		assert(candidates.catalog_sha256 == FileAccess.get_sha256(source_dir.path_join("catalog.json")))
		assert(candidates.runtime_approved == false)
		readability = candidates.readability
		corrections = candidates.get("motion", {})
		corrected_hud = true
	root.size = Vector2i(1152, 648)
	Engine.max_fps = 120
	world = Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("253544")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = framing.CAMERA_FOV
	world.add_child(camera)
	camera.current = true
	for index in 2:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.CYAN)
		root.add_child(label)
		overlays.append(label)
	var report := {"runtime_approved": false, "complete": false, "sample_hz": 60,
		"catalog_sha256": FileAccess.get_sha256(source_dir.path_join("catalog.json")),
		"framing_sha256": FileAccess.get_sha256(framing.resource_path),
		"placement_sha256": FileAccess.get_sha256(placement_rules.resource_path),
		"motion_rules_sha256": FileAccess.get_sha256(motion_rules.resource_path),
		"camera_fov": camera.fov, "viewport": [root.size.x, root.size.y],
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"scope": "flat_floor_two_runtime_camera_presets; HUD proxy only; not full UI or arena collision certification", "entries": []}
	var control_entry: Dictionary
	for entry: Dictionary in catalog.entries:
		if entry.species == "dragonite":
			control_entry = entry
	var control := _load_actor(control_entry)
	assert(control != null)
	world.add_child(control)
	var control_player: AnimationPlayer = control.find_children("*", "AnimationPlayer", true, false)[0]
	var control_measure: Dictionary = await _measure(control_entry, control, control_player)
	control.visible = false
	for entry: Dictionary in catalog.entries:
		if entry.status != "exported_for_review":
			report.entries.append({"species": entry.species, "status": entry.status})
			continue
		var model := _load_actor(entry)
		assert(model != null)
		world.add_child(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var measured: Dictionary = await _measure(entry, model, player)
		if corrections.has(entry.species):
			var profile: Dictionary = corrections[entry.species]
			assert(profile.sha256 == entry.glb_sha256 and is_equal_approx(profile.scale, measured.scale))
			assert(is_equal_approx(profile.lift, measured.candidate_lift) and is_equal_approx(profile.yaw_degrees, measured.yaw_degrees))
			var timing := {}
			for action in measured.clips:
				timing[action] = {"frames": measured.clips[action].duration * 60.0}
			var placement := {"scale": measured.scale, "yaw_degrees": measured.yaw_degrees,
				"lift": measured.candidate_lift, "calibrated": true}
			assert(motion_rules.resolve(profile, placement, entry.glb_sha256, timing) == profile.clips)
			measured["corrected_clearance_120hz"] = await _validate_motion(entry, model, player, measured)
		measured["bounds_hud_proxy"] = corrected_hud
		control.visible = true
		measured["shots"] = await _shots(entry, model, player, measured, control, control_player, control_measure)
		measured["species"] = entry.species
		measured["glb_sha256"] = entry.glb_sha256
		report.entries.append(measured)
		print("PLACEMENT ", entry.species, " lift=", measured.candidate_lift)
		model.free()
		control.visible = false
		var file := FileAccess.open(output_dir.path_join("battle-review.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	report.complete = true
	report["candidates_sha256"] = FileAccess.get_sha256(candidates_path) if not candidates_path.is_empty() else ""
	var completed_file := FileAccess.open(output_dir.path_join("battle-review.json"), FileAccess.WRITE)
	completed_file.store_string(JSON.stringify(report, "  "))
	completed_file.close()
	world.free()
	quit()
