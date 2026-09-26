extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const ArtBounds = preload("res://scripts/battle/arenas/shared/wooded_route.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(90).timeout.connect(func(): printerr("ROUTES_ORBIT_CHECK_TIMEOUT"); quit(2))
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	assert(not manifest.is_empty())
	assert(Arenas.prepare_forest(manifest).is_empty())
	while not Arenas.forest_ready():
		await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["route_1", "route_1_water", "route_22", "route_22_water"])
	for id in ids:
		assert(id in ["route_1", "route_1_water", "route_22", "route_22_water", "route_2", "route_2_water", "route_4", "route_4_water", "cerulean_city", "cerulean_city_water", "route_24", "route_24_water", "route_25", "route_25_water"])
		var arena: Node3D = Arenas.build(id, world, camera)
		world.add_child(arena)
		var grid: Rect2i = arena.get_meta("mesh_grid")
		var vertices: PackedVector3Array = arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var base_id := id.trim_suffix("_water")
		var tree_path: String = {"route_1": "Route1Scenery/Route1TreeCorridor", "route_22": "Route22Scenery/RouteConifers", "route_2": "Route2Scenery/WoodlandConifers", "route_4": "Route4Scenery/ValleyConifers", "cerulean_city": "RegionScenery/RegionConifers", "route_24": "RegionScenery/RegionConifers", "route_25": "RegionScenery/RegionConifers"}[base_id]
		var trees := arena.get_node(tree_path)
		var boxes: Array = []
		ArtBounds.new()._bounds(trees, Transform3D.IDENTITY, boxes)
		var props: Array = []
		var landmark_path: String = {"route_1": "Route1Scenery/Route1Landmarks", "route_22": "Route22Scenery/Route22Landmarks", "route_2": "Route2Scenery/WoodlandLandmarks", "route_4": "Route4Scenery/ValleyLandmarks", "cerulean_city": "RegionScenery/RegionLandmarks", "route_24": "RegionScenery/RegionLandmarks", "route_25": "RegionScenery/RegionLandmarks"}[base_id]
		var landmarks := arena.get_node(landmark_path)
		ArtBounds.new()._bounds(landmarks, Transform3D.IDENTITY, props)
		var target := Arenas.camera_target(id)
		for degrees in range(0, 360, 5):
			for pitch in [-0.12, 0.0, 0.65]:
				for zoom in [Renderer.USER_CAMERA_ZOOM_MIN, Renderer.USER_CAMERA_ZOOM_MAX]:
					var offset := (Arenas.camera_home(id) - target).rotated(Vector3.UP, deg_to_rad(degrees))
					offset = offset.rotated(offset.cross(Vector3.UP).normalized(), pitch) * zoom
					var position := target + offset
					assert(position.y > _height(vertices, grid, position) + 0.5, "%s camera meets terrain at %d" % [id, degrees])
					for side in 2:
						var fighter := Arenas.spawn(side) + Arenas.battle_origin(id)
						fighter.y = float(arena.get_meta("surface_height")) + 0.5
						for sample in range(1, 40):
							var sightline := position.lerp(fighter, sample / 40.0)
							assert(sightline.y > _height(vertices, grid, sightline) + 0.1, "%s terrain hides fighter %d at %d" % [id, side, degrees])
					for bounds: AABB in boxes:
						assert(not bounds.grow(0.3).has_point(position), "%s camera enters a tree at %d" % [id, degrees])
					for bounds: AABB in props:
						assert(not bounds.intersects_segment(position, target), "%s landmark obstructs the camera at %d" % [id, degrees])
		# Backdrops must occupy the whole horizon, including the separate pond origin.
		for degrees in range(0, 360, 15):
			var direction := Vector3(sin(deg_to_rad(degrees)), 0, cos(deg_to_rad(degrees)))
			var reached_trees := false
			for bounds: AABB in boxes:
				var footprint := bounds.grow(1.0)
				footprint.position.y = -100
				footprint.size.y = 200
				if footprint.intersects_segment(target + direction * 20, target + direction * (130 if base_id in ["route_4", "route_24", "cerulean_city", "route_25"] else 85)):
					reached_trees = true
					break
			# Route 22 also has continuous high rock shelves behind its forest.
			var backdrop := target + direction * 55
			# The cape deliberately opens onto the ocean. Its shader must cover that horizon.
			var open_sea := base_id == "route_25" and backdrop.x + backdrop.z - 24 + 2 * sin(backdrop.z * 0.12) > 3
			if open_sea:
				assert(arena.has_node("RegionScenery/CeruleanCapeOcean/WaterSurface"))
			assert(open_sea or reached_trees or _height(vertices, grid, backdrop) > target.y + 3, "%s empty horizon at %d" % [id, degrees])
		arena.free()
		print("ROUTES_ORBIT_CHECK_OK: ", id)
	world.queue_free()
	await process_frame
	quit()
func _height(vertices: PackedVector3Array, grid: Rect2i, point: Vector3) -> float:
	var x := clampf(point.x - grid.position.x, 0, grid.size.x - 1.00001)
	var z := clampf(point.z - grid.position.y, 0, grid.size.y - 1.00001)
	var index := int(z) * grid.size.x + int(x)
	return lerpf(lerpf(vertices[index].y, vertices[index + 1].y, x - floorf(x)),
		lerpf(vertices[index + grid.size.x].y, vertices[index + grid.size.x + 1].y, x - floorf(x)), z - floorf(z))
