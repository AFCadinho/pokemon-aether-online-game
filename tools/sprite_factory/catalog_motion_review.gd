extends "res://tools/sprite_factory/phase5_godot_review.gd"
## Render three sampled times for every native clip of an existing standalone
## catalog. This produces review evidence only; it cannot approve a model.

const ACTIONS := ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]
const OPTIONAL_ACTIONS := ["physical_attack_2"]
const FRACTIONS := [0.0, 0.5, 1.0]

func _pose(model: Node3D, player: AnimationPlayer, action: String, fraction: float) -> AABB:
	player.stop()
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	if player.has_animation("RESET"):
		player.play("RESET")
		player.advance(0)
	if action == "faint_loop":
		player.play("faint_start")
		player.seek(player.get_animation("faint_start").length, true)
	player.play(action)
	player.pause()
	player.seek(player.get_animation(action).length * fraction, true)
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw
	return _bounds(model)

func _run() -> void:
	var report_path := OS.get_environment("POKEAETHER_CATALOG_MOTION_REPORT")
	var output := OS.get_environment("POKEAETHER_CATALOG_MOTION_OUTPUT")
	if not report_path.is_absolute_path() or not FileAccess.file_exists(report_path) or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name() == "headless":
		printerr("Supply an absolute standalone report, a new absolute output directory, and a rendering display")
		quit(2)
		return
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not rows is Array or DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Invalid report or output directory")
		quit(2)
		return
	root.size = Vector2i(640, 640)
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
	var reflection_review := OS.get_environment("POKEAETHER_CATALOG_REVIEW_REFLECTIONS") == "neutral_studio"
	if reflection_review:
		# A black reflection environment makes silver metals look black even
		# with white diffuse ambient light. Keep the background unchanged.
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.55, 0.55, 0.55)
		sky_material.sky_horizon_color = Color(0.8, 0.8, 0.8)
		sky_material.ground_bottom_color = Color(0.16, 0.16, 0.16)
		sky_material.ground_horizon_color = Color(0.8, 0.8, 0.8)
		environment.environment.sky = Sky.new()
		environment.environment.sky.sky_material = sky_material
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
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
	var result := {"schema": 1, "runtime_approved": false, "renderer": RenderingServer.get_current_rendering_method(), "entries": []}
	var quick_review := OS.get_environment("POKEAETHER_CATALOG_REVIEW_QUICK") == "1"
	var eye_review := OS.get_environment("POKEAETHER_CATALOG_REVIEW_EYES_ONLY") == "1"
	result["capture_profile"] = "eye_pair" if eye_review else ("quick_pair" if quick_review else "full_motion")
	result["reflection_environment"] = "neutral_studio" if reflection_review else "default"
	var eye_level_review := OS.get_environment("POKEAETHER_CATALOG_REVIEW_EYE_LEVEL") == "1"
	var side_review := OS.get_environment("POKEAETHER_CATALOG_REVIEW_SIDE") == "1"
	result["camera_angle"] = "side" if side_review else ("low_front" if eye_level_review else "default")
	var failed := false
	for row: Variant in rows:
		if not row is Dictionary:
			failed = true
			continue
		var record := {"species": str(row.get("species", "")), "runtime_sha256": str(row.get("runtime_sha256", "")), "errors": [], "captures": []}
		var path := str(row.get("runtime_path", ""))
		if not path.is_absolute_path() or FileAccess.get_sha256(path) != record.runtime_sha256:
			record.errors.append("SCN hash mismatch")
		else:
			var scene: PackedScene = load(path)
			var model: Node3D = scene.instantiate() if scene != null else null
			if model == null:
				record.errors.append("SCN load failed")
			else:
				world.add_child(model)
				var players := model.find_children("*", "AnimationPlayer", true, false)
				if players.size() != 1:
					record.errors.append("Expected one AnimationPlayer")
				else:
					var player: AnimationPlayer = players[0]
					var actions := ["idle", "sleep"] if eye_review else (["idle", "physical_attack", "special_attack", "sleep", "faint_start"] if quick_review else ACTIONS.duplicate())
					if not eye_review:
						for optional: String in OPTIONAL_ACTIONS:
							if player.has_animation(optional):
								actions.append(optional)
					var framing := AABB()
					var found := false
					for action: String in actions:
						if not player.has_animation(action):
							record.errors.append("Missing clip: " + action)
							continue
						for fraction: float in FRACTIONS:
							var box := await _pose(model, player, action, fraction)
							if not box.position.is_finite() or not box.size.is_finite() or box.size.length() <= 0:
								record.errors.append("Invalid pose: " + action)
							else:
								framing = framing.merge(box) if found else box
								found = true
					if found:
						camera.size = maxf(framing.size.length() * 1.12, 0.1)
						var target := framing.get_center()
						var direction := Vector3(7, 2, 3) if side_review else (Vector3(3, 0.4, 7) if eye_level_review else Vector3(3, 2, 7))
						camera.position = target + direction.normalized() * camera.size * 3
						camera.look_at(target)
						for action: String in actions:
							if not player.has_animation(action):
								continue
							var capture_fractions: Array = [0.5] if eye_review else ([1.0 if action == "faint_start" else 0.5] if quick_review else FRACTIONS)
							for fraction: float in capture_fractions:
								var box := await _pose(model, player, action, fraction)
								await RenderingServer.frame_post_draw
								var image_name := "%s-%s-%d.png" % [record.species, action, roundi(fraction * 100)]
								if root.get_texture().get_image().save_png(output.path_join(image_name)) != OK:
									record.errors.append("Screenshot failed: " + image_name)
								record.captures.append({"action": action, "fraction": fraction, "image": image_name, "bounds_position": [box.position.x, box.position.y, box.position.z], "bounds_size": [box.size.x, box.size.y, box.size.z]})
				model.free()
		failed = failed or not record.errors.is_empty()
		result.entries.append(record)
		print("CATALOG_MOTION_REVIEW ", record.species, " images=", record.captures.size(), " errors=", record.errors)
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	world.free()
	quit(1 if failed else 0)
