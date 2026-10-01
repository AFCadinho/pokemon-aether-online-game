extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	root.title = "PokeAether — PvP stadium arena review"
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
	var arena := Arenas.build("stadium", world, camera)
	world.add_child(arena)
	camera.fov = Arenas.CAMERA_FOV
	camera.position = Arenas.camera_home("stadium")
	camera.look_at(Arenas.camera_target("stadium"))
	camera.current = true
	root.get_node("WorldTimeService").set_debug_time(12)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("stadium-battle.png"))
	for yaw in [90, 180, 270]:
		var target := Arenas.camera_target("stadium")
		camera.position = target + (Arenas.camera_home("stadium") - target).rotated(Vector3.UP, deg_to_rad(yaw))
		camera.look_at(target)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("stadium-angle-%d.png" % yaw))
	camera.position = Vector3(14, 6.3, -20)
	camera.look_at(Vector3(12, 5.5, -24.2))
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("stadium-supporters.png"))
	root.get_node("WorldTimeService").clear_debug_time()
	print("STADIUM_PREVIEW_OK")
	quit()
