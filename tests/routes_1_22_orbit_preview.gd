extends SceneTree
## Real paired battle rendering at every yaw and the user camera limits.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(240).timeout.connect(func(): printerr("ROUTES_ORBIT_PREVIEW_TIMEOUT"); quit(2))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_arena = "auto"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	assert(not output.is_empty() and not settings.battle_3d_catalog_path.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["route_1", "route_1_water", "route_22", "route_22_water"])
	for id in ids:
		assert(id in ["route_1", "route_1_water", "route_22", "route_22_water", "route_2", "route_2_water", "route_4", "route_4_water"])
		var host := Node.new()
		root.add_child(host)
		current_scene = host
		var stage := Renderer.new()
		stage.environment_id = StringName(id)
		host.add_child(stage)
		stage.size = Vector2(1280, 720)
		stage.setup()
		stage.set_combatant(0, "dragonite")
		stage.set_combatant(1, "roaring-moon")
		while not stage.active or not stage._actors_resolved():
			assert(not stage.preparation_failed, stage.reason)
			await process_frame
		await stage.await_prepared(true, 30000)
		assert(not stage.preparation_failed and stage.arena_id == id, stage.reason)
		for mode in ["day", "night", "low", "high"]:
			root.get_node("WorldTimeService").set_debug_time(23 if mode == "night" else 12)
			stage.user_camera_pitch = -0.12 if mode == "low" else (0.65 if mode == "high" else 0.0)
			stage.user_camera_zoom = stage.USER_CAMERA_ZOOM_MAX if mode in ["low", "high"] else 1.0
			var sheet := Image.create(2048, 576, false, Image.FORMAT_RGB8)
			for i in 8:
				stage.user_camera_yaw = deg_to_rad(i * 45)
				await create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				var capture := stage.viewport.get_texture().get_image()
				assert(capture.save_png(output.path_join("%s-%s-%03d.png" % [id, mode, i * 45])) == OK)
				capture.convert(Image.FORMAT_RGB8)
				capture.resize(512, 288, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(capture, Rect2i(0, 0, 512, 288), Vector2i(i % 4 * 512, i / 4 * 288))
			assert(sheet.save_png(output.path_join("%s-%s-sheet.png" % [id, mode])) == OK)
		host.queue_free()
		await process_frame
		await process_frame
		print("ROUTES_ORBIT_PREVIEW_OK: ", id)
	root.get_node("WorldTimeService").clear_debug_time()
	quit()
