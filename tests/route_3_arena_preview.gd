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
	root.title = "PokeAether — Route 3 arena review"
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
	world.add_child(Arenas.build("route_3", world, camera))
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
	print("ROUTE_3_PREVIEW_OK")
	quit()
