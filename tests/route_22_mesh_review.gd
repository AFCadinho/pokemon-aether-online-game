extends SceneTree
## Current runtime mesh review. --forest selects generic grassfield; --water the
## Route 22 pond. Historical Terrain3D comparisons are in commit 0bc5fd6e8.
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Art = preload("res://scripts/battle/arenas/shared/forest_art_pack.gd")
const MeshArena = preload("res://scripts/battle/arenas/maps/route_22/arena.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")
var views: Array[SubViewport] = []
var scenes: Array[Node3D] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(not "--terrain" in args, "Terrain3D baseline is historical; use commit 0bc5fd6e8")
	var generic := "--forest" in args
	var water := "--water" in args
	var arena_id := "forest" if generic else ("route_22_water" if water else "route_22")
	var label := "generic-grassfield" if generic else ("mesh-water" if water else "mesh-land")
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not manifest.is_empty() and not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	assert(not ClassDB.class_exists("Terrain3D"), "Start each comparison in a fresh process")
	var started := Time.get_ticks_usec()
	var memory_before := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	assert(Catalog.prepare_forest(manifest).is_empty())
	while not Catalog.forest_ready():
		assert(Catalog.forest_error.is_empty())
		await process_frame
	assert(not ClassDB.class_exists("Terrain3D"))
	var mount_ms := (Time.get_ticks_usec() - started) / 1000.0
	var build_started := Time.get_ticks_usec()
	var build_ms: Array[float] = []
	for response in [false, true]:
		var pass_started := Time.get_ticks_usec()
		var view := SubViewport.new()
		view.size = Vector2i(1152, 648)
		view.own_world_3d = true
		view.msaa_3d = Viewport.MSAA_4X
		view.use_hdr_2d = response
		view.transparent_bg = response
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var world := Node3D.new()
		view.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("b4cad6")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.add_child(environment)
		Lighting.apply_neutral_lighting(world)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		for child in world.get_children():
			if child is DirectionalLight3D:
				child.shadow_blur = 2.0 / 3.0
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Catalog.camera_home(arena_id)
		camera.fov = Catalog.CAMERA_FOV
		camera.look_at(Catalog.camera_target(arena_id))
		camera.current = true
		var arena: Node3D = Catalog.build(arena_id, world, camera)
		world.add_child(arena)
		scenes.append(arena)
		build_ms.append((Time.get_ticks_usec() - pass_started) / 1000.0)
		_check(arena, generic, water)
		await process_frame
	var assembly_ms := (Time.get_ticks_usec() - build_started) / 1000.0
	var quiet := 0
	var last: Array = []
	while quiet < 8:
		assert(Time.get_ticks_usec() - started < 120000000, "Arena preparation timed out")
		await process_frame
		var sample := [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]
		quiet = quiet + 1 if sample == last else 0
		last = sample
	var ready_ms := (Time.get_ticks_usec() - started) / 1000.0
	# Settle transient allocations equally for both backends before measuring.
	await create_timer(1.0).timeout
	var evidence := {"backend": label, "dimensions": "1152x648", "passes": 2,
		"mount_and_baseline_resource_ms": mount_ms, "build_pass_ms": build_ms,
		"assembly_elapsed_ms": assembly_ms, "ready_ms": ready_ms,
		"settled_render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"settled_render_delta_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - memory_before,
		"terrain3d_loaded": ClassDB.class_exists("Terrain3D")}
	assert(not ClassDB.class_exists("Terrain3D"), "No native module may load through art dependencies")
	assert(scenes[0].get_node("MeshTerrain").mesh == scenes[1].get_node("MeshTerrain").mesh)
	var scenery_name := "GrassfieldScenery" if generic else "Route22Scenery"
	assert(scenes[0].get_node(scenery_name + "/SharedForestGrass").get_child(0).multimesh == scenes[1].get_node(scenery_name + "/SharedForestGrass").get_child(0).multimesh)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		views[0].get_texture().get_image().save_png(output.path_join(label + ".png"))
	# Timings above exclude review-only height markers. Capture waterline separately.
	if water and not generic and DisplayServer.get_name() != "headless":
		for i in 2:
			var marker := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.height = 1.8 if i == 0 else 0.8
			shape.top_radius = 0.22
			shape.bottom_radius = 0.22
			marker.mesh = shape
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("ee819c")
			marker.material_override = material
			scenes[0].add_child(marker)
			marker.position = Catalog.spawn(i) + Catalog.battle_origin(arena_id)
			marker.position.y = float(scenes[0].get_meta("surface_height")) + shape.height * 0.5
		await process_frame
		await RenderingServer.frame_post_draw
		views[0].get_texture().get_image().save_png(output.path_join(label + "-depth-markers.png"))
	FileAccess.open(output.path_join(label + ".json"), FileAccess.WRITE).store_string(JSON.stringify(evidence, "\t"))
	if "--interactive" in args:
		root.title = "Route 22 — " + label + " (arena review)"
		root.size = Vector2i(1152, 648)
		var display := TextureRect.new()
		display.texture = views[0].get_texture()
		display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(display)
		print("ROUTE_22_INTERACTIVE_REVIEW ", JSON.stringify(evidence))
		return
	var first: WeakRef = weakref(views[0])
	var second: WeakRef = weakref(views[1])
	for view in views:
		view.queue_free()
	await process_frame
	await process_frame
	assert(first.get_ref() == null and second.get_ref() == null)
	print("ROUTE_22_MESH_REVIEW_OK ", JSON.stringify(evidence))
	quit()

func _check(arena: Node3D, generic: bool, water: bool) -> void:
	assert(not arena.has_node("Terrain3D"))
	if generic:
		assert(arena.name == "GenericGrassfield")
		assert(arena.has_node("GrassfieldScenery/SharedForestGrass"))
		assert(not arena.has_meta("source_map"))
		var layout = preload("res://scripts/battle/arenas/generic/grassfield_layout.gd")
		for group in layout.data().foliage:
			for transform in group.transforms:
				assert(Vector2(transform[9], transform[11]).length() > 6, "Foliage cannot obstruct combatants")
		return
	assert(arena.get_meta("source_map") == "kanto_route_22")
	for path in ["NorthernRockTerraces", "RouteConifers", "Route22Landmarks", "RouteFlowers", "EasternPond/WaterSurface"]:
		assert(arena.has_node("Route22Scenery/" + path))
	var floor_y: float = arena.get_meta("surface_height")
	var surface: MeshInstance3D = arena.get_node("Route22Scenery/EasternPond/WaterSurface")
	assert(absf(floor_y - (MeshArena.BASE_HEIGHT - 0.44 if water else MeshArena.BASE_HEIGHT)) < 0.001)
	assert(absf(surface.position.y - (MeshArena.BASE_HEIGHT - 0.22)) < 0.001)
	assert(not arena.has_node("Terrain3D"))
	var mesh: Mesh = arena.get_node("MeshTerrain").mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in vertices:
		if water and point.x >= 8 and point.x <= 14 and point.z >= -6 and point.z <= -3:
			assert(absf(point.y - floor_y) < 0.001)
		if not water and Vector2(point.x, point.z).length() < 5:
			assert(absf(point.y - floor_y) < 0.001)
	for batch in arena.get_node("Route22Scenery/SharedForestGrass").get_children():
		for i in batch.multimesh.instance_count:
			var point: Vector3 = batch.multimesh.get_instance_transform(i).origin
			assert(Vector2(point.x, point.z).length() > 6)
			assert(((Vector2(point.x, point.z) - MeshArena.POND_CENTER) / MeshArena.POND_RADII).length() > 1.2)
