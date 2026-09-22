extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for kind in ["trainer", "wild"]:
		var context := {"battle_kind": kind, "map_id": "kanto_route_1", "map_environment_id": "grass"}
		assert(Resolver.resolve(context) == &"route_1")
		assert(Arenas.resolve("auto", Resolver.resolve(context)) == "route_1")
		context.explicit_environment_id = "cave"
		assert(Resolver.resolve(context) == &"cave")
	assert(Resolver.resolve({"battle_kind": "pvp", "map_id": "kanto_route_1"}) == &"pvp_stadium")
	for encounter in Resolver.WATER_ENCOUNTER_TYPES:
		assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_1", "encounter_type": encounter}) == &"route_1_water")
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_1", "player_on_water": true}) == &"route_1_water")
	assert(Profiles.get_profile(&"route_1_water").is_valid())
	assert(Arenas.resolve("auto", &"route_1_water") == "route_1_water")
	var profile = Profiles.get_profile(&"route_1")
	assert(profile.is_valid() and profile.arena_3d_id == "route_1")
	assert(profile.background_texture == Profiles.get_profile(&"grass").background_texture)
	assert(Arenas.definition("route_1").map_id == "kanto_route_1")
	assert(Arenas.uses_forest_assets("route_1"))
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	if manifest.is_empty():
		print("ROUTE_1_RESOLUTION_OK")
		quit()
		return
	var owner := Node.new()
	root.add_child(owner)
	var pool := Pool.prepare(owner, manifest, Vector2i(960, 540), "route_1")
	var deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle:
		assert(not pool.failed and Time.get_ticks_msec() < deadline)
		await process_frame
	assert(Pool.prepare(owner, manifest, Vector2i(960, 540), "route_1") == pool)
	for pass_data in pool.passes:
		var arena: Node3D = pass_data.arena
		assert(arena.name == "Route1ForestTerraces")
		assert(arena.get_meta("source_map") == "kanto_route_1")
		assert(arena.get_meta("terrain_backend") == "mesh")
		for path in ["Route1RockTerraces", "Route1Landmarks", "Route1TreeCorridor",
			"Route1Flowers", "NorthernPond/WaterSurface", "SharedForestGrass"]:
			assert(arena.has_node("Route1Scenery/" + path))
		assert(not arena.has_node("Terrain3D"))
		var floor_y: float = arena.get_meta("surface_height")
		var vertices: PackedVector3Array = arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var grid: Rect2i = arena.get_meta("mesh_grid")
		for point in [Arenas.spawn(0), Arenas.spawn(1), Vector3.ZERO]:
			assert(absf(_height(vertices, grid, point) - floor_y) < 0.001)
		assert(_height(vertices, grid, Vector3(0, 0, -28)) > floor_y + 2.8)
		assert(_height(vertices, grid, Vector3(0, 0, 28)) < floor_y - 2.1)
		var water: MeshInstance3D = arena.get_node("Route1Scenery/NorthernPond/WaterSurface")
		assert(is_equal_approx(water.position.y - _height(vertices, grid, water.position), 0.18))
		_check_connections(arena, vertices, grid)
	var settings = root.get_node("SettingsManager")
	settings.battle_3d_arena = "auto"
	settings.battle_3d_forest_manifest = manifest
	var stage := Renderer.new()
	owner.add_child(stage)
	stage.setup()
	stage.set_process(false)
	stage.environment_id = &"route_1"
	stage._build_world()
	assert(stage.arena_id == "route_1")
	assert(stage.viewport == pool.passes[0].viewport)
	assert(pool.borrower.get_ref() == stage)
	stage.material_response._build()
	assert(stage.material_response.viewport == pool.passes[1].viewport)
	for index in 2:
		assert(is_equal_approx(stage._position(index).y, float(stage.arena_root.get_meta("surface_height"))))
	stage.free()
	await process_frame
	assert(pool.borrower == null)
	var view: WeakRef = weakref(pool.passes[0].viewport)
	pool = Pool.prepare(owner, manifest, Vector2i(960, 540), "route_1_water")
	while not pool.ready_for_battle:
		assert(not pool.failed and Time.get_ticks_msec() < deadline)
		await process_frame
	assert(view.get_ref() == null)
	for pass_data in pool.passes:
		var arena: Node3D = pass_data.arena
		assert(arena.name == "Route1ForestTerraces")
		var water: MeshInstance3D = arena.get_node("Route1Scenery/NorthernPond/WaterSurface")
		var floor_y: float = arena.get_meta("surface_height")
		assert(is_equal_approx(water.position.y - floor_y, 0.18))
		var vertices: PackedVector3Array = arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var grid: Rect2i = arena.get_meta("mesh_grid")
		for index in 2:
			assert(is_equal_approx(_height(vertices, grid, Arenas.spawn(index) + Arenas.battle_origin("route_1_water")), floor_y))
	stage = Renderer.new()
	owner.add_child(stage)
	stage.setup()
	stage.set_process(false)
	stage.environment_id = &"route_1_water"
	stage._build_world()
	assert(stage.arena_id == "route_1_water" and stage.viewport == pool.passes[0].viewport)
	for index in 2:
		assert(stage._position(index).is_equal_approx(Arenas.spawn(index) + Arenas.battle_origin("route_1_water")))
	stage.free()
	await process_frame
	view = weakref(pool.passes[0].viewport)
	owner.queue_free()
	await process_frame
	await process_frame
	assert(view.get_ref() == null and Pool.get_current() == null)
	assert(not ClassDB.class_exists("Terrain3D"))
	print("ROUTE_1_ARENA_OK: resolution, terrain, paths, grass, pond, terraces, pooled passes, cleanup")
	quit()

func _check_connections(arena: Node3D, vertices: PackedVector3Array, grid: Rect2i) -> void:
	for stair_name in ["NorthStair", "SouthStair"]:
		var stairs := arena.get_node("Route1Scenery/Route1Landmarks/" + stair_name)
		var first: MeshInstance3D = stairs.get_node("Step0")
		var last: MeshInstance3D = stairs.get_node("Step9")
		var bottom := first.position - Vector3(0, first.scale.y * 0.5, -0.3)
		var top := last.position + Vector3(0, last.scale.y * 0.5, -0.3)
		assert(absf(_height(vertices, grid, bottom) - bottom.y) < 0.001, "Lower stair landing must meet terrain")
		assert(absf(_height(vertices, grid, top) - top.y) < 0.001, "Upper stair landing must meet terrain")
		for rock: Node3D in arena.get_node("Route1Scenery/Route1RockTerraces").get_children():
			var boxes: Array = []
			preload("res://scripts/battle/arenas/maps/route_1/arena.gd").new()._bounds(rock, Transform3D.IDENTITY, boxes)
			for bounds: AABB in boxes:
				if bounds.position.z < bottom.z and bounds.end.z > top.z:
					assert(bounds.end.x < bottom.x - 2.7 or bounds.position.x > bottom.x + 2.7, "Rocks must leave the full path clear")

func _height(vertices: PackedVector3Array, grid: Rect2i, point: Vector3) -> float:
	var x := clampi(roundi(point.x) - grid.position.x, 0, grid.size.x - 1)
	var z := clampi(roundi(point.z) - grid.position.y, 0, grid.size.y - 1)
	return vertices[z * grid.size.x + x].y
