extends SceneTree
## Offline arena review, using the client's camera and neutral lighting.
## --capture writes the battle angle and a wider composition view, then exits.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	assert(not manifest.is_empty())
	assert(Arenas.prepare_forest(manifest).is_empty())
	while not Arenas.forest_ready():
		await process_frame
	var arena_id := "forest" if "--forest" in OS.get_cmdline_user_args() else "route_22"
	root.title = "PokeAether — Route 22 arena review"
	root.size = Vector2i(1440, 900)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	Lighting.apply_neutral_lighting(world)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	root.msaa_3d = Viewport.MSAA_4X
	var camera := Camera3D.new()
	world.add_child(camera)
	world.add_child(Arenas.build(arena_id, world, camera))
	camera.fov = Arenas.CAMERA_FOV
	camera.position = Arenas.camera_home("route_22")
	camera.look_at(Arenas.camera_target("route_22"))
	camera.current = true
	if "--capture" in OS.get_cmdline_user_args():
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		assert(not output.is_empty())
		DirAccess.make_dir_recursive_absolute(output)
		await create_timer(3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("route-22-battle.png"))
		camera.position = Vector3(15, 15, 27)
		camera.look_at(Vector3(0, 1, -7))
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("route-22-overview.png"))
		print("ROUTE_22_PREVIEW_OK")
		quit()
