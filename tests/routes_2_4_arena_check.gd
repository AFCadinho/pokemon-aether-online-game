extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")

func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(100).timeout.connect(func(): printerr("ROUTES_2_4_TIMEOUT"); quit(2))
	for id in ["route_2", "route_4"]:
		for kind in ["wild", "trainer"]:
			var context := {"battle_kind": kind, "map_id": "kanto_" + id, "map_environment_id": "grass", "player_on_tall_grass": true}
			assert(Resolver.resolve(context) == StringName(id))
			assert(Arenas.resolve("auto", Resolver.resolve(context)) == id)
			context.explicit_environment_id = "cave"
			assert(Resolver.resolve(context) == &"cave")
		for encounter in ["surf", "fish", "fishing", "old_rod", "good_rod", "super_rod"]:
			assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_" + id, "encounter_type": encounter}) == StringName(id + "_water"))
		assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_" + id, "player_on_water": true}) == StringName(id + "_water"))
		assert(Resolver.resolve({"battle_kind": "pvp", "map_id": "kanto_" + id}) == &"pvp_stadium")
		for suffix in ["", "_water"]:
			var profile = Profiles.get_profile(StringName(id + suffix))
			assert(profile.is_valid() and profile.arena_3d_id == id + suffix)
			assert(profile.background_texture == Profiles.get_profile(&"grass" if suffix.is_empty() else &"water").background_texture)
			assert(Arenas.uses_forest_assets(id + suffix))
			assert(Arenas.resolve("cave", StringName(id + suffix)) == "cave")
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_5"}) == &"grass")
	print("ROUTES_2_4_RESOLUTION_OK")
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	if manifest.is_empty():
		quit()
		return
	var owner_node := Node.new()
	root.add_child(owner_node)
	var previous: WeakRef
	for id in ["route_2", "route_2_water", "route_4", "route_4_water", "route_2"]:
		var pool: Node = Pool.prepare(owner_node, manifest, Vector2i(960, 540), id)
		assert(pool != null)
		while not pool.ready_for_battle:
			assert(not pool.failed)
			await process_frame
		if previous != null:
			assert(previous.get_ref() == null, "Switching routes must retire the old arena pair")
		for pass_data in pool.passes:
			var arena: Node3D = pass_data.arena
			assert(arena.get_meta("source_map") == "kanto_" + id.trim_suffix("_water"))
			assert(arena.has_node("OutdoorLighting"))
			var scenery := "Route2Scenery" if id.begins_with("route_2") else "Route4Scenery"
			assert(arena.has_node(scenery + "/SharedForestGrass"))
			var landmarks := scenery + ("/WoodlandLandmarks" if id.begins_with("route_2") else "/ValleyLandmarks")
			var required := ["BlueRoofHouse", "ForestGate", "DiglettCaveEntrance", "CaveStairs"] if id.begins_with("route_2") else ["MtMoonEntrance", "MountainStairs", "RiverFootbridge"]
			for landmark in required:
				assert(arena.has_node(landmarks + "/" + landmark))
			var water: MeshInstance3D = arena.get_node(scenery + ("/WoodlandPond/WaterSurface" if id.begins_with("route_2") else "/CeruleanRiver/WaterSurface"))
			for side in 2:
				var p := Arenas.spawn(side) + Arenas.battle_origin(id)
				assert(absf(_height(arena, p) - float(arena.get_meta("surface_height"))) < 0.001)
			if id.ends_with("_water"):
				assert(is_equal_approx(water.position.y - float(arena.get_meta("surface_height")), 0.22))
				assert(water.material_override.get_shader_parameter("battle_shallows"))
			else:
				assert(_height(arena, water.position) < water.position.y - 0.5)
				assert(_height(arena, Vector3.ZERO) > water.position.y)
			var stair: Node3D = arena.get_node(landmarks + ("/CaveStairs" if id.begins_with("route_2") else "/MountainStairs"))
			var rise := 3.0 if id.begins_with("route_2") else 4.2
			assert(is_equal_approx(_height(arena, stair.position), stair.position.y))
			assert(is_equal_approx(_height(arena, stair.position + Vector3(0, 0, -6)), stair.position.y + rise))
		assert(pool.passes[0].arena.get_node("MeshTerrain").mesh == pool.passes[1].arena.get_node("MeshTerrain").mesh)
		previous = weakref(pool.passes[0].arena)
		print("ROUTES_2_4_ARENA_OK: ", id)
	owner_node.queue_free()
	await process_frame
	await process_frame
	assert(Pool.get_current() == null and previous.get_ref() == null)
	quit()

func _height(arena: Node3D, p: Vector3) -> float:
	var grid: Rect2i = arena.get_meta("mesh_grid")
	var v: PackedVector3Array = arena.get_node("MeshTerrain").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var x := clampf(p.x - grid.position.x, 0, grid.size.x - 1.00001)
	var z := clampf(p.z - grid.position.y, 0, grid.size.y - 1.00001)
	var i := int(z) * grid.size.x + int(x)
	return lerpf(lerpf(v[i].y, v[i + 1].y, x - floorf(x)), lerpf(v[i + grid.size.x].y, v[i + grid.size.x + 1].y, x - floorf(x)), z - floorf(z))
