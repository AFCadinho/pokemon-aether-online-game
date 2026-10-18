extends SceneTree
## Reproducible art review with the same neutral lighting as the battle presenter.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")


func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "PokeAether — interior arena review"
	root.size = Vector2i(1440, 900)
	root.msaa_3d = Viewport.MSAA_4X
	var ids := OS.get_environment("POKEAETHER_TEST_ARENAS")
	if ids.is_empty():
		ids = "pokemon_tower,rocket_hideout"
	for id in ids.split(","):
		assert(id in ["pokemon_tower", "rocket_hideout", "celadon_game_corner", "celadon_gym"])
		var world := Node3D.new()
		root.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("272536")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.add_child(environment)
		Lighting.apply_neutral_lighting(world)
		var camera := Camera3D.new()
		world.add_child(camera)
		world.add_child(Arenas.build(id, world, camera))
		camera.fov = Arenas.CAMERA_FOV
		camera.current = true
		var target := Arenas.camera_target(id)
		for yaw in [0, 90, 180, 270]:
			var offset := (Arenas.camera_home(id) - target).rotated(Vector3.UP, deg_to_rad(yaw))
			camera.position = target + offset
			camera.look_at(target)
			await create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output.path_join("%s-angle-%d.png" % [id, yaw])) == OK)
		var offset := (Arenas.camera_home(id) - target).rotated(Vector3.UP, -0.16425)
		camera.position = target + offset.rotated(offset.cross(Vector3.UP).normalized(), -0.0156437) * 0.7
		camera.look_at(target)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(id + "-default.png")) == OK)
		world.free()
	print("DUNGEON_ARENAS_PREVIEW_OK")
	quit()
