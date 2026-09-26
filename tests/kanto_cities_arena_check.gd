extends SceneTree
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")

func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(240).timeout.connect(func(): printerr("KANTO_CITIES_TIMEOUT"); quit(2))
	for id in ["pallet_town", "viridian_city", "pewter_city"]:
		for kind in ["wild", "trainer"]:
			var context := {"battle_kind": kind, "map_id": "kanto_" + id, "map_environment_id": "grass", "player_on_tall_grass": true}
			assert(Resolver.resolve(context) == StringName(id))
			assert(Arenas.resolve("auto", Resolver.resolve(context)) == id)
			context.explicit_environment_id = "cave"
			assert(Resolver.resolve(context) == &"cave")
		for encounter in ([] if id == "pewter_city" else ["surf", "fish", "fishing", "old_rod", "good_rod", "super_rod"]):
			assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_" + id, "encounter_type": encounter}) == StringName(id + "_water"))
		assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_" + id, "player_on_water": true}) == (&"water" if id == "pewter_city" else StringName(id + "_water")))
		assert(Resolver.resolve({"battle_kind": "pvp", "map_id": "kanto_" + id}) == &"pvp_stadium")
		for suffix in ([""] if id == "pewter_city" else ["", "_water"]):
			var profile = Profiles.get_profile(StringName(id + suffix))
			assert(profile.is_valid() and profile.arena_3d_id == id + suffix)
			assert(profile.background_texture == Profiles.get_profile(&"grass" if suffix.is_empty() else &"water").background_texture)
			assert(Arenas.uses_forest_assets(id + suffix))
			assert(Arenas.resolve("cave", StringName(id + suffix)) == "cave")
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_5"}) == &"grass")
	for map_id in ["kanto_players_house", "kanto_oaks_lab", "kanto_viridian_city_trainer_school", "kanto_pewter_city_house_1"]:
		assert(Resolver.resolve({"battle_kind": "trainer", "map_id": map_id, "map_environment_id": "cave"}) == &"cave")
	print("KANTO_CITIES_RESOLUTION_OK")
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	if manifest.is_empty():
		quit()
		return
	var owner_node := Node.new()
	root.add_child(owner_node)
	var previous: WeakRef
	for id in ["pallet_town", "pallet_town_water", "viridian_city", "viridian_city_water", "pewter_city", "pallet_town"]:
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
			var scenery := "RegionScenery"
			assert(arena.has_node(scenery + "/SharedForestGrass"))
			assert(arena.has_node(scenery + "/TownTerraces/MountainPeaks"))
			var landmarks := scenery + "/RegionLandmarks"
			var base_id: String = id.trim_suffix("_water")
			var required: Array = {"pallet_town": ["PlayersHouse", "RivalsHouse", "OaksLab", "NorthTownStairs"], "viridian_city": ["ViridianGym", "TrainerSchool", "PokemonCenter", "GymTerraceStairs", "EVTrainingField"], "pewter_city": ["PewterMuseum", "PewterGym", "PokemonCenter", "TownFountain", "TreeGarden", "ExcavationGarden"]}[base_id]
			for landmark in required:
				assert(arena.has_node(landmarks + "/" + landmark))
			# The dummy headless renderer does not retain MultiMesh transforms.
			if base_id == "viridian_city" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var field: Rect2 = arena.get_meta("ev_training_field")
				var blades := 0
				for batch: MultiMeshInstance3D in arena.get_node(scenery + "/SharedForestGrass").get_children():
					for i in batch.multimesh.instance_count:
						var p := batch.multimesh.get_instance_transform(i).origin
						if field.has_point(Vector2(p.x, p.z)):
							blades += 1
				assert(blades > 500, "EV training strip must contain dense rendered tall grass")
			for side in 2:
				var p := Arenas.spawn(side) + Arenas.battle_origin(id)
				assert(absf(_height(arena, p) - float(arena.get_meta("surface_height"))) < 0.001)
			if base_id != "pewter_city":
				var water_name: String = "PalletOcean" if base_id == "pallet_town" else "ViridianPond"
				var water: MeshInstance3D = arena.get_node(scenery + "/" + water_name + "/WaterSurface")
				if id.ends_with("_water"):
					assert(is_equal_approx(water.position.y - float(arena.get_meta("surface_height")), 0.22))
					assert(water.material_override.get_shader_parameter("battle_shallows"))
				else:
					assert(_height(arena, Arenas.battle_origin(id + "_water")) < water.position.y - 0.5)
					assert(_height(arena, Vector3.ZERO) > water.position.y)
			var stair_name: String = {"pallet_town": "NorthTownStairs", "viridian_city": "GymTerraceStairs", "pewter_city": "MuseumTerraceStairs"}[base_id]
			var stair: Node3D = arena.get_node(landmarks + "/" + stair_name)
			assert(is_equal_approx(_height(arena, stair.position), stair.position.y))
			assert(is_equal_approx(_height(arena, stair.position + Vector3(0, 0, -6)), stair.position.y + (3.2 if base_id == "pewter_city" else 3.0)))
		assert(pool.passes[0].arena.get_node("MeshTerrain").mesh == pool.passes[1].arena.get_node("MeshTerrain").mesh)
		previous = weakref(pool.passes[0].arena)
		print("KANTO_CITIES_ARENA_OK: ", id)
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
