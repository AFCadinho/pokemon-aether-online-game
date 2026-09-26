extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not manifest.is_empty() and not output.is_empty())
	create_timer(90).timeout.connect(func(): printerr("ROUTE_3_PREVIEW_TIMEOUT"); quit(2))
	if "--pokemon" in OS.get_cmdline_user_args():
		await _pokemon_preview(manifest, output)
		return
	assert(Arenas.prepare_forest(manifest).is_empty())
	while not Arenas.forest_ready():
		await process_frame
	root.title = "PokeAether — Route 3 arena review"
	root.size = Vector2i(1440, 900)
	root.msaa_3d = Viewport.MSAA_4X
	root.get_node("WorldTimeService").set_debug_time(12)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b4cad6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	Lighting.apply_neutral_lighting(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var arena := Arenas.build("route_3", world, camera)
	assert(arena != null)
	world.add_child(arena)
	camera.fov = Arenas.CAMERA_FOV
	camera.position = Arenas.camera_home("route_3")
	camera.look_at(Arenas.camera_target("route_3"))
	camera.current = true
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("route-3-battle.png"))
	camera.position = Vector3(18, 18, 30)
	camera.look_at(Vector3(0, 0.5, -5))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("route-3-overview.png"))
	root.get_node("WorldTimeService").clear_debug_time()
	print("ROUTE_3_PREVIEW_OK")
	quit()

func _pokemon_preview(manifest: String, output: String) -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_arena = "auto"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	settings.battle_3d_forest_manifest = manifest
	assert(not settings.battle_3d_catalog_path.is_empty())
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var stage := preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd").new()
	stage.environment_id = &"route_3"
	host.add_child(stage)
	stage.size = Vector2(1280, 720)
	stage.setup()
	stage.set_combatant(0, "dragonite")
	stage.set_combatant(1, "roaring-moon")
	while not stage.active or not stage._actors_resolved():
		await process_frame
	await stage.await_prepared(true, 30000)
	assert(not stage.preparation_failed and stage.arena_id == "route_3", stage.reason)
	DirAccess.make_dir_recursive_absolute(output)
	for hour in [12, 23]:
		root.get_node("WorldTimeService").set_debug_time(hour)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		assert(stage.viewport.get_texture().get_image().save_png(output.path_join("route-3-pokemon-%02d.png" % hour)) == OK)
	if "--orbit" in OS.get_cmdline_user_args():
		for hour in [12, 23]:
			root.get_node("WorldTimeService").set_debug_time(hour)
			for degrees in range(0, 360, 45):
				stage.user_camera_yaw = deg_to_rad(degrees)
				stage.user_camera_pitch = 0.0
				stage.user_camera_zoom = 1.0
				await _capture_orbit(stage, output, "orbit-%02d-%03d" % [hour, degrees])
		# Both pitch limits at maximum zoom, including all diagonal joins.
		root.get_node("WorldTimeService").set_debug_time(12)
		for pitch in [-0.12, 0.65]:
			for degrees in range(0, 360, 45):
				stage.user_camera_yaw = deg_to_rad(degrees)
				stage.user_camera_pitch = pitch
				stage.user_camera_zoom = stage.USER_CAMERA_ZOOM_MAX
				await _capture_orbit(stage, output, "orbit-limit-%s-%03d" % ["low" if pitch < 0 else "high", degrees])
	root.get_node("WorldTimeService").clear_debug_time()
	host.queue_free()
	await process_frame
	await process_frame
	print("ROUTE_3_POKEMON_PREVIEW_OK")
	quit()

func _capture_orbit(stage: Control, output: String, label: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	assert(stage.active and stage.arena_id == "route_3")
	assert(stage.viewport.get_texture().get_image().save_png(output.path_join("route-3-%s.png" % label)) == OK)
