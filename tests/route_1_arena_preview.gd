extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not manifest.is_empty() and not output.is_empty())
	assert(Arenas.prepare_forest(manifest).is_empty())
	while not Arenas.forest_ready():
		await process_frame
	root.title = "PokeAether — Route 1 arena review"
	root.size = Vector2i(1440, 900)
	root.msaa_3d = Viewport.MSAA_4X
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
	var arena := Arenas.build("route_1", world, camera)
	world.add_child(arena)
	camera.fov = Arenas.CAMERA_FOV
	camera.position = Arenas.camera_home("route_1")
	camera.look_at(Arenas.camera_target("route_1"))
	camera.current = true
	for hour in [6, 12, 19, 23]:
		root.get_node("WorldTimeService").set_debug_time(hour)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		root.get_texture().get_image().save_png(output.path_join("route-1-hour-%02d.png" % hour))
	root.get_node("WorldTimeService").set_debug_time(12)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("route-1-battle.png"))
	camera.position = Vector3(18, 18, 30)
	camera.look_at(Vector3(0, 0.5, -5))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("route-1-overview.png"))
	camera.position = Vector3(-5, 7, -13)
	camera.look_at(Vector3(-5, 0, 20))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("route-1-south.png"))
	arena.free()
	arena = Arenas.build("route_1_water", world, camera)
	world.add_child(arena)
	camera.position = Arenas.camera_home("route_1_water")
	camera.look_at(Arenas.camera_target("route_1_water"))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("route-1-water.png"))
	root.get_node("WorldTimeService").set_debug_time(23)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("route-1-water-night.png"))
	root.get_node("WorldTimeService").clear_debug_time()
	print("ROUTE_1_PREVIEW_OK")
	quit()
