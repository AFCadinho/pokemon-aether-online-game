extends "res://tools/sprite_factory/phase5_godot_review.gd"
## Render three sampled times for every native clip of an existing standalone
## catalog. This produces review evidence only; it cannot approve a model.

const ACTIONS := ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]
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
					var framing := AABB()
					var found := false
					for action: String in ACTIONS:
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
						camera.position = target + Vector3(3, 2, 7).normalized() * camera.size * 3
						camera.look_at(target)
						for action: String in ACTIONS:
							if not player.has_animation(action):
								continue
							for fraction: float in FRACTIONS:
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
