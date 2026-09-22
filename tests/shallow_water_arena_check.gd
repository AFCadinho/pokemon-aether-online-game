extends SceneTree
## Focused render/grounding check. No server, model catalog or settings writes.
const Arena = preload("res://scripts/battle/arenas/sea_arena.gd")
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	for encounter in ["surf", "fish", "old_rod", "good_rod", "super_rod"]:
		assert(Catalog.resolve("auto", Resolver.resolve({"battle_kind":"wild", "map_id":"kanto_route_21", "encounter_type":encounter})) == "sea")
	var views: Array[SubViewport] = []
	for response_pass in [false, true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1440, 900)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.transparent_bg = response_pass
		viewport.use_hdr_2d = response_pass
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		views.append(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.add_child(environment)
		Lighting.apply_neutral_lighting(world)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Catalog.camera_home("sea")
		camera.fov = Catalog.CAMERA_FOV
		camera.look_at(Catalog.camera_target("sea"))
		camera.current = true
		var arena := Catalog.build("sea", world, camera)
		world.add_child(arena)
		var water: MeshInstance3D = arena.get_node("ShallowWater")
		assert(arena.get_meta("surface_height") == 0.0)
		assert(water.position.y > 0 and water.position.y <= 0.03)
		assert(water.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var floor_mesh: MeshInstance3D = arena.get_node("SubmergedSandbank")
		var vertices: PackedVector3Array = floor_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			assert(v.y < water.position.y, "The entire sandbank must be below the water")
			if Vector2(v.x, v.z).length() < 7.5:
				assert(is_zero_approx(v.y), "Existing combat ground calibration stays valid")
		for i in 2:
			assert(Vector2(Catalog.spawn(i).x, Catalog.spawn(i).z).length() < 7.5)
	await create_timer(2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		if not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			views[0].get_texture().get_image().save_png(output.path_join("shallow-water-battle.png"))
	var first: WeakRef = weakref(views[0])
	var second: WeakRef = weakref(views[1])
	for view in views:
		view.queue_free()
	await process_frame
	await process_frame
	assert(first.get_ref() == null and second.get_ref() == null)
	print("SHALLOW_WATER_ARENA_OK: surf/fishing, submerged floor, unchanged grounding, both passes, cleanup")
	quit()
