extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Catalog = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	for kind in ["trainer", "wild"]:
		var context := {"battle_kind": kind, "map_id": "kanto_route_22", "map_environment_id": "grass", "player_on_tall_grass": true}
		assert(Resolver.resolve(context) == &"route_22")
		assert(Arenas.resolve("auto", Resolver.resolve(context)) == "route_22")
		context.explicit_environment_id = "cave"
		assert(Resolver.resolve(context) == &"cave")
	for encounter in ["surf", "fish", "old_rod", "good_rod", "super_rod"]:
		assert(Resolver.resolve({"battle_kind":"wild", "map_id":"kanto_route_22", "encounter_type":encounter}) == &"route_22_water")
	assert(Resolver.resolve({"battle_kind":"wild", "map_id":"kanto_route_22", "player_on_water":true}) == &"route_22_water")
	assert(Resolver.resolve({"battle_kind":"pvp", "map_id":"kanto_route_22"}) == &"pvp_stadium")
	assert(Resolver.resolve({"battle_kind":"trainer", "map_id":"kanto_route_2"}) == &"grass")
	assert(Arenas.resolve("cave", &"route_22") == "cave")
	assert(Arenas.uses_forest_assets("route_22") and Arenas.uses_forest_assets("forest"))
	assert(not Arenas.uses_forest_assets("cave"))
	var profile = Catalog.get_profile(&"route_22")
	assert(profile.is_valid())
	assert(profile.background_texture == Catalog.get_profile(&"grass").background_texture)
	assert(profile.platform_texture == Catalog.get_profile(&"grass").platform_texture)
	print("ROUTE_22_RESOLUTION_OK")
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	if manifest.is_empty():
		quit()
		return
	var owner_node := Node.new()
	root.add_child(owner_node)
	var baseline: Node = Pool.prepare(owner_node, manifest, Vector2i(960, 540), "forest")
	await _ready_pool(baseline)
	var baseline_mesh: WeakRef = weakref(baseline.passes[0].arena.get_node("MeshTerrain").mesh)
	var baseline_height: float = _height(baseline.passes[0].arena, Vector3(0, 0, -24))
	var pool: Node = Pool.prepare(owner_node, manifest, Vector2i(960, 540), "route_22")
	assert(pool != null)
	await _ready_pool(pool)
	assert(baseline_mesh.get_ref() == null, "Retired arenas must release their ground mesh")
	assert(Pool.prepare(owner_node, manifest, Vector2i(960, 540), "route_22") == pool)
	var first_height: float = pool.passes[0].arena.get_meta("surface_height")
	for pass_data in pool.passes:
		var arena: Node3D = pass_data.arena
		assert(arena.name == "Route22RivalMeadow")
		assert(arena.get_meta("source_map") == "kanto_route_22")
		assert(arena.has_node("Route22Scenery/Route22Landmarks"))
		var terrain = arena
		var water: MeshInstance3D = arena.get_node("Route22Scenery/EasternPond/WaterSurface")
		assert(water.position.y < first_height)
		assert(_height(terrain, water.position) < water.position.y - 0.5, "Water needs a recessed basin")
		assert(_height(terrain, Vector3(0, 0, 0)) > water.position.y, "Battle clearing stays dry")
		assert(is_equal_approx(first_height, float(arena.get_meta("surface_height"))))
		for point in [Arenas.spawn(0), Arenas.spawn(1), Vector3.ZERO]:
			assert(absf(_height(terrain, point) - first_height) < 0.001)
		assert(_height(terrain, Vector3(0, 0, -24)) > first_height + 4.0)
		assert(arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][43 * 121 + 65].r > 0.95)
		assert(arena.has_node("Route22Scenery/SharedForestGrass"))
		assert(not ClassDB.class_exists("Terrain3D"))
	# Exercise real presenter leases, both material passes, and repeat teardown.
	var settings = root.get_node("SettingsManager")
	settings.battle_3d_arena = "auto"
	settings.battle_3d_forest_manifest = manifest
	for cycle in 2:
		var stage := Renderer.new()
		owner_node.add_child(stage)
		stage.setup()
		stage.set_process(false)
		stage.environment_id = &"route_22"
		stage._build_world()
		assert(stage.arena_id == "route_22")
		assert(stage.viewport == pool.passes[0].viewport)
		assert(pool.borrower.get_ref() == stage)
		stage.material_response._build()
		assert(stage.material_response.viewport == pool.passes[1].viewport)
		assert(Pool.prepare(owner_node, manifest, Vector2i(960,540), "forest") == null, "Do not retire a borrowed arena")
		stage.free()
		await process_frame
		assert(pool.borrower == null)
		for pass_data in pool.passes:
			assert(pass_data.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
		print("ROUTE_22_PRESENTER_OK cycle=",cycle)
	var old_main: WeakRef = weakref(pool.passes[0].viewport)
	var old_response: WeakRef = weakref(pool.passes[1].viewport)
	pool = Pool.prepare(owner_node, manifest, Vector2i(960, 540), "forest")
	await _ready_pool(pool)
	assert(old_main.get_ref() == null and old_response.get_ref() == null)
	assert(pool.arena_id == "forest")
	assert(is_equal_approx(_height(pool.passes[0].arena, Vector3(0, 0, -24)), baseline_height), "Route edits must not change the original forest terrain")
	assert(not pool.passes[0].arena.has_node("Route22Scenery"))
	# A ready forest pool must never lend its scenery to a Route 22 battle.
	var standalone := Renderer.new()
	owner_node.add_child(standalone)
	standalone.setup()
	standalone.set_process(false)
	standalone.environment_id = &"route_22"
	standalone._build_world()
	assert(standalone.arena_id == "route_22" and standalone.forest_lease.is_empty())
	assert(standalone.viewport != pool.passes[0].viewport)
	standalone.material_response._build()
	assert(standalone.material_response.world.has_node("Route22RivalMeadow"))
	assert(is_equal_approx(_height(pool.passes[0].arena, Vector3(0, 0, -24)), baseline_height), "Simultaneous variants need independent terrain data")
	var direct_main: WeakRef = weakref(standalone.viewport)
	var direct_response: WeakRef = weakref(standalone.material_response.viewport)
	standalone.free()
	await process_frame
	assert(direct_main.get_ref() == null and direct_response.get_ref() == null)
	assert(pool.borrower == null)
	# Existing uncalibrated-model fallback remains effective for this arena.
	var fallback := Renderer.new()
	owner_node.add_child(fallback)
	fallback.setup()
	fallback.set_process(false)
	fallback.environment_id = &"route_22"
	fallback.packed["unreviewed"] = PackedScene.new()
	fallback._build_world()
	assert(fallback.arena_id == "classic" and fallback.arena_problem.contains("calibration"))
	fallback.free()
	await process_frame
	print("ROUTE_22_STANDALONE_AND_FALLBACK_OK")
	# Returning to Route 22 replaces the single retained pair; no per-map cache.
	var forest_main: WeakRef = weakref(pool.passes[0].viewport)
	pool = Pool.prepare(owner_node, manifest, Vector2i(960, 540), "route_22")
	await _ready_pool(pool)
	assert(forest_main.get_ref() == null)
	assert(pool.passes[0].arena.name == "Route22RivalMeadow")
	# Water encounters fight in the actual eastern pond, not at the grass origin.
	pool = Pool.prepare(owner_node, manifest, Vector2i(960, 540), "route_22_water")
	await _ready_pool(pool)
	for pass_data in pool.passes:
		assert(pass_data.arena.name == "Route22ShallowWater")
		var water: MeshInstance3D = pass_data.arena.get_node("Route22Scenery/EasternPond/WaterSurface")
		var floor_y: float = pass_data.arena.get_meta("surface_height")
		assert(water.position.y - floor_y >= 0.20 and water.position.y - floor_y <= 0.25, "Water must cover feet without swallowing small combatants")
		assert(water.material_override.get_shader_parameter("battle_shallows"))
		assert(pass_data.arena.has_node("Route22Scenery/Route22Landmarks"))
	var swimmer := Renderer.new()
	owner_node.add_child(swimmer)
	swimmer.setup()
	swimmer.set_process(false)
	swimmer.environment_id = &"route_22_water"
	swimmer._build_world()
	assert(swimmer.arena_id == "route_22_water")
	assert(swimmer.viewport == pool.passes[0].viewport)
	var terrain = swimmer.arena_root
	for index in 2:
		var point: Vector3 = swimmer._position(index)
		assert(absf(_height(terrain, point) - point.y) < 0.001)
		assert(Vector2(point.x - 11.0, point.z + 4.5).length() < 4.0)
		assert(not swimmer.camera.is_position_behind(point + Vector3.UP))
	assert((swimmer._position(1) - swimmer._position(0)).is_equal_approx((Arenas.spawn(1) - Arenas.spawn(0))))
	settings.battle_3d_camera_motion = true
	swimmer._update_camera(1.0)
	var orbit_offset: Vector3 = swimmer.camera.position - Arenas.battle_origin("route_22_water")
	assert(is_equal_approx(orbit_offset.length(), Vector3(4, 5.5, 12).length()))
	swimmer.material_response._build()
	assert(swimmer.material_response.viewport == pool.passes[1].viewport)
	swimmer.free()
	await process_frame
	assert(pool.borrower == null)
	print("ROUTE_22_WATER_BATTLE_OK: pond placement, submerged feet, camera, both passes")
	var final_view: WeakRef = weakref(pool.passes[0].viewport)
	owner_node.queue_free()
	await process_frame
	await process_frame
	assert(final_view.get_ref() == null and Pool.get_current() == null)
	assert(not ClassDB.class_exists("Terrain3D"))
	print("ROUTE_22_POOL_SWITCH_OK")
	quit()
func _ready_pool(pool: Node) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not pool.ready_for_battle:
		assert(not pool.failed and Time.get_ticks_msec() < deadline)
		await process_frame

func _height(arena: Node3D, point: Vector3) -> float:
	var grid: Rect2i = arena.get_meta("mesh_grid")
	var gx := clampf(point.x - grid.position.x, 0, grid.size.x - 1.00001)
	var gz := clampf(point.z - grid.position.y, 0, grid.size.y - 1.00001)
	var dx := gx - floorf(gx)
	var dz := gz - floorf(gz)
	var at := floori(gz) * grid.size.x + floori(gx)
	var v: PackedVector3Array = arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if dx + dz <= 1:
		return v[at].y + dx * (v[at + 1].y - v[at].y) + dz * (v[at + grid.size.x].y - v[at].y)
	return v[at + grid.size.x + 1].y + (1 - dx) * (v[at + grid.size.x].y - v[at + grid.size.x + 1].y) + (1 - dz) * (v[at + 1].y - v[at + grid.size.x + 1].y)
