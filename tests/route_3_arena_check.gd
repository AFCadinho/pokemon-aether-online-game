extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")

func _init() -> void:
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
		assert(arena.has_node("Route3Scenery/RoadLandmarks"))
		assert(arena.has_node("Route3Scenery/SharedForestGrass"))
		assert(arena.has_node("OutdoorLighting"))
		assert(arena.get_meta("terrain_backend") == "mesh")
		var mesh: ArrayMesh = arena.get_node("MeshTerrain").mesh
		var grid: Rect2i = arena.get_meta("mesh_grid")
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in [Arenas.spawn(0), Arenas.spawn(1), Vector3.ZERO]:
			var index := (int(point.z) - grid.position.y) * grid.size.x + int(point.x) - grid.position.x
			assert(is_equal_approx(vertices[index].y, float(arena.get_meta("surface_height"))))
		var north_index := (-28 - grid.position.y) * grid.size.x - grid.position.x
		assert(vertices[north_index].y > float(arena.get_meta("surface_height")) + 3.0)
	assert(pool.passes[0].arena.get_node("MeshTerrain").mesh == pool.passes[1].arena.get_node("MeshTerrain").mesh)
	owner.queue_free()
	await process_frame
	await process_frame
	assert(Pool.get_current() == null)
	print("ROUTE_3_ARENA_OK")
	quit()
