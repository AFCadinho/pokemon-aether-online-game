extends "res://tools/sprite_factory/measure_model_grounding.gd"
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
const Profiles = preload("res://scripts/battle/battle_ui/reviewed_motion_placement.json")

func _run() -> void:
	var output := OS.get_environment("POKEAETHER_POSE_REVIEW_OUTPUT")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		quit(2)
		return
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".grounding.json"))
	var world := Node3D.new()
	root.add_child(world)
	preload("res://scripts/battle/battle_ui/material_response.gd").apply_neutral_lighting(world)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 30)
	world.add_child(floor_mesh)
	review_camera = Camera3D.new()
	world.add_child(review_camera)
	review_camera.current = true
	var label := Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_font_size_override("font_size", 40)
	root.add_child(label)
	for entry: Dictionary in catalog:
		var placement := Placement.resolve(entry, calibration.entries[entry.species], FileAccess.get_sha256(entry.runtime_path))
		var clips := Motion.resolve(Profiles.data[entry.species], placement, FileAccess.get_sha256(entry.runtime_path), entry.action_timing)
		assert(not clips.is_empty())
		var actor: Node3D = load(entry.runtime_path).instantiate()
		world.add_child(actor)
		actor.scale = Vector3.ONE * float(placement.scale)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop", "sleep_wake"]:
			var atlas := Image.create(480 * 5, 270 * 3, false, Image.FORMAT_RGBA8)
			for row in 3:
				var angle: int = [0, 90, 180][row]
				review_camera.position = Vector3(0, 4.0 if row == 2 else 2.6, 7.5).rotated(Vector3.UP, deg_to_rad(angle))
				review_camera.look_at(Vector3(0, 1.3, 0))
				for column in 5:
					var name: String = ("sleep" if column < 2 else "idle") if action == "sleep_wake" else action
					var duration := player.get_animation(name).length
					var time := duration * column / 4.0
					player.play(name)
					player.pause()
					actor.position.y = placement.lift + Motion.offset(clips, name, time)
					label.text = "%s %s %.2fs / %d°" % [entry.species, name, time, angle]
					await _pose(player, skeletons, time)
					await RenderingServer.frame_post_draw
					var frame := root.get_texture().get_image()
					frame.convert(Image.FORMAT_RGBA8)
					frame.resize(480, 270)
					atlas.blit_rect(frame, Rect2i(0, 0, 480, 270), Vector2i(column * 480, row * 270))
			assert(atlas.save_png(output.path_join(entry.species + "-" + action + ".png")) == OK)
		actor.free()
	print("MOTION_SEQUENCE_REVIEW_OK")
	world.free()
	label.free()
	quit()
