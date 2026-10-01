extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	root.title = "PokeAether — S.S. Anne arena review"
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
	var arena := Arenas.build("ss_anne", world, camera)
	world.add_child(arena)
	camera.fov = Arenas.CAMERA_FOV
	camera.position = Arenas.camera_home("ss_anne")
	camera.look_at(Arenas.camera_target("ss_anne"))
	camera.current = true
	root.get_node("WorldTimeService").set_debug_time(12)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("ss-anne-battle.png"))
	camera.position = Vector3(32, 25, 40)
	camera.look_at(Vector3(0, 2, -7))
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("ss-anne-overview.png"))
	root.get_node("WorldTimeService").clear_debug_time()
	print("SS_ANNE_PREVIEW_OK")
	quit()
