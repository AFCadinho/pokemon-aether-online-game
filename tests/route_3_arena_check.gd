extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")

func _init() -> void:
	create_timer(90).timeout.connect(func(): printerr("ROUTE_3_CHECK_TIMEOUT"); quit(2))
	_run.call_deferred()

func _run() -> void:
	for kind in ["wild", "trainer"]:
		var context := {"battle_kind": kind, "map_id": "kanto_route_3", "map_environment_id": "grass", "player_on_tall_grass": true}
		assert(Resolver.resolve(context) == &"route_3")
		assert(Arenas.resolve("auto", Resolver.resolve(context)) == "route_3")
		context.explicit_environment_id = "cave"
		assert(Resolver.resolve(context) == &"cave")
	assert(Resolver.resolve({"battle_kind": "pvp", "map_id": "kanto_route_3"}) == &"pvp_stadium")
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_3", "encounter_type": "surf"}) == &"water")
	assert(Profiles.get_profile(&"route_3").is_valid())
	assert(Arenas.definition("route_3").map_id == "kanto_route_3")
	assert(Arenas.uses_forest_assets("route_3"))
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	if manifest.is_empty():
		print("ROUTE_3_RESOLUTION_OK")
		quit()
		return
	var owner := Node.new()
	root.add_child(owner)
	var pool: Node = Pool.prepare(owner, manifest, Vector2i(960, 540), "route_3")
	assert(pool != null)
	var deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle:
		assert(not pool.failed and Time.get_ticks_msec() < deadline)
		await process_frame
	for pass_data in pool.passes:
		var arena: Node3D = pass_data.arena
		assert(arena.name == "Route3MountainRoad")
		assert(arena.get_meta("source_map") == "kanto_route_3")
		assert(arena.has_node("Route3Scenery/RockRidges"))
		assert(arena.has_node("Route3Scenery/MountainConifers"))
		var landmarks: Node3D = arena.get_node("Route3Scenery/RoadLandmarks")
		for landmark in ["PokemonCenter", "MtMoonEntrance/TunnelOpening", "MtMoonSign", "LowerStairs", "MoonStairs"]:
			assert(landmarks.has_node(landmark))
		assert(arena.has_node("Route3Scenery/ShrubBanks"))
		assert(arena.has_node("Route3Scenery/SharedForestGrass"))
		assert(arena.has_node("OutdoorLighting"))
		assert(arena.get_meta("terrain_backend") == "mesh")
		var mesh: ArrayMesh = arena.get_node("MeshTerrain").mesh
		var grid: Rect2i = arena.get_meta("mesh_grid")
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in [Arenas.spawn(0), Arenas.spawn(1), Vector3.ZERO]:
			var index := (int(point.z) - grid.position.y) * grid.size.x + int(point.x) - grid.position.x
			assert(is_equal_approx(vertices[index].y, float(arena.get_meta("surface_height"))))
		for x in range(-5, 6):
			for z in range(-3, 4):
				assert(is_equal_approx(_terrain_height(arena, Vector3(x, 0, z)), float(arena.get_meta("surface_height"))))
		_check_stairs(arena, landmarks.get_node("LowerStairs"), 2.4)
		_check_stairs(arena, landmarks.get_node("MoonStairs"), 3.2)
		_check_stairs(arena, landmarks.get_node("SouthStairs"), 2.4)
		_check_orbit(arena)
		# Regress the green terrain protrusions found during the visual review.
		for cliff: Node in arena.get_node("Route3Scenery/RockRidges").get_children():
			if not str(cliff.name).begins_with("CliffFace"):
				continue
			for point: Vector3 in cliff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				assert(point.y >= _terrain_height(arena, point) - 0.05, "Cliff faces must cover the terrain ramp")
		var north_index := (-28 - grid.position.y) * grid.size.x - grid.position.x
		assert(vertices[north_index].y > float(arena.get_meta("surface_height")) + 3.0)
	assert(pool.passes[0].arena.get_node("MeshTerrain").mesh == pool.passes[1].arena.get_node("MeshTerrain").mesh)
	owner.queue_free()
	await process_frame
	await process_frame
	assert(Pool.get_current() == null)
	print("ROUTE_3_ARENA_OK")
	quit()

func _check_stairs(arena: Node3D, stairs: Node3D, rise: float) -> void:
	var base := stairs.position
	assert(is_equal_approx(_terrain_height(arena, base), base.y))
	assert(is_equal_approx(_terrain_height(arena, stairs.transform * Vector3(0, 0, -6)), base.y + rise))
	for i in 10:
		var step: MeshInstance3D = stairs.get_node("Step%d" % i)
		var point := stairs.transform * step.position
		assert(_terrain_height(arena, point) <= point.y + step.scale.y * 0.5)

func _check_orbit(arena: Node3D) -> void:
	var target := Arenas.camera_target("route_3")
	for degrees in range(0, 360, 15):
		var yaw := deg_to_rad(degrees)
		for pitch in [-0.12, 0.0, 0.65]:
			for zoom in [0.72, 1.45]:
				var offset: Vector3 = (Arenas.camera_home("route_3") - target).rotated(Vector3.UP, yaw)
				offset = offset.rotated(offset.cross(Vector3.UP).normalized(), pitch) * zoom
				var position := target + offset
				assert(position.y > _terrain_height(arena, position) + 0.5, "Terrain must remain below the full camera orbit")
		# A raised mountain backdrop must enclose all compass directions, including
		# diagonal views between the former front-only scenery and the new shelves.
		var horizon := Vector3(sin(yaw), 0, cos(yaw)) * 54.0
		assert(_terrain_height(arena, horizon) > 6.0, "Missing mountain backdrop at %d degrees" % degrees)

func _terrain_height(arena: Node3D, point: Vector3) -> float:
	var grid: Rect2i = arena.get_meta("mesh_grid")
	var mesh: ArrayMesh = arena.get_node("MeshTerrain").mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var x := clampf(point.x - grid.position.x, 0, grid.size.x - 1.00001)
	var z := clampf(point.z - grid.position.y, 0, grid.size.y - 1.00001)
	var index := int(z) * grid.size.x + int(x)
	return lerpf(lerpf(vertices[index].y, vertices[index + 1].y, x - floorf(x)),
		lerpf(vertices[index + grid.size.x].y, vertices[index + grid.size.x + 1].y, x - floorf(x)), z - floorf(z))
