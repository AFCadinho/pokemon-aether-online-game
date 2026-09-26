extends SceneTree
## Actual map/NPC selection plus full camera orbit clearance of both indoor halls.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const MAPS := {
	"pewter_city_gym": ["pewter_city/pewter_gym", ["GymLeaderBrock", "HikerFlint", "YoungsterStone"]],
	"cerulean_city_gym": ["cerulean_city/cerulean_gym", ["GymLeaderMisty", "SwimmerLuis", "PicnickerDiana", "SwimmerBriana"]],
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(90).timeout.connect(func(): printerr("GYM_ARENAS_TIMEOUT"); quit(2))
	for id: String in MAPS:
		var map_id := "kanto_" + id
		assert(Profiles.get_profile(StringName(id)).is_valid())
		assert(Arenas.resolve("auto", StringName(id)) == id)
		assert(Arenas.resolve("cave", StringName(id)) == "cave")
		assert(not Arenas.uses_forest_assets(id) and not Arenas.uses_outdoor_lighting(id))
		for kind in ["trainer", "wild"]:
			for water in [false, true]:
				var context := {"map_id": map_id, "battle_kind": kind, "player_on_water": water, "map_environment_id": "grass"}
				assert(Resolver.resolve(context) == StringName(id))
				context.explicit_environment_id = "water"
				assert(Resolver.resolve(context) == &"water")
		assert(Resolver.resolve({"map_id": map_id, "battle_kind": "pvp"}) == &"pvp_stadium")
		var map: Node = load("res://scenes/overworld/kanto/towns/%s.tscn" % MAPS[id][0]).instantiate()
		root.add_child(map)
		await process_frame
		for npc_name: String in MAPS[id][1]:
			var npc: Node = map.get_node("Entities/NPCs/" + npc_name)
			var metadata: Dictionary = npc.build_battle_trainer_metadata({})
			assert(Resolver.resolve({"map_id": map_id, "battle_kind": "trainer", "explicit_environment_id": metadata.get("battleEnvironmentId", "")}) == StringName(id), npc_name)
		map.free()
		var world := Node3D.new()
		root.add_child(world)
		var arena := Arenas.build(id, world)
		world.add_child(arena)
		assert(arena.get_meta("source_map") == map_id)
		assert(is_zero_approx(float(arena.get_meta("surface_height"))))
		assert(arena.has_node("EnclosedHall") and not arena.has_node("OutdoorLighting"))
		assert(arena.has_node("BrockDais") if id == "pewter_city_gym" else arena.has_node("MistyDais/MistyParasol"))
		var meshes: Array[MeshInstance3D] = []
		_collect(arena, meshes)
		assert(meshes.size() < 650, "Keep standalone arena passes modest")
		for side in 2:
			var contact := Arenas.spawn(side)
			var supported := false
			for mesh in meshes:
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				if bounds.grow(0.002).has_point(contact) and absf(bounds.end.y) < 0.002:
					supported = true
			assert(supported, "Combatant must contact the y=0 floor")
		for yaw in range(0, 360, 5):
			for pitch in [-0.12, 0.0, 0.65]:
				for zoom in [Renderer.USER_CAMERA_ZOOM_MIN, 1.0, Renderer.USER_CAMERA_ZOOM_MAX]:
					var target := Arenas.camera_target(id)
					var offset := (Arenas.camera_home(id) - target).rotated(Vector3.UP, deg_to_rad(yaw))
					var camera: Vector3 = target + offset.rotated(offset.cross(Vector3.UP).normalized(), pitch) * zoom
					assert(absf(camera.x) < 25 and absf(camera.z) < 30 and camera.y < 19, "Camera stays inside the hall")
					for mesh in meshes:
						var inverse := mesh.global_transform.affine_inverse()
						var bounds := mesh.get_aabb()
						assert(not bounds.grow(0.12).has_point(inverse * camera), "Camera intersects " + str(mesh.get_path()))
						for side in 2:
							for height in [0.5, 2.0, 4.0]:
								var aim := Arenas.spawn(side) + Vector3(0, height, 0)
								assert(not bounds.intersects_segment(inverse * camera, inverse * aim), "Scenery hides combatant: " + str(mesh.get_path()))
		world.free()
		print("GYM_ARENA_OK: ", id, " meshes=", meshes.size(), " camera samples=648")
	assert(Resolver.resolve({"map_id": "kanto_pewter_city", "battle_kind": "trainer"}) == &"grass")
	assert(Resolver.resolve({"map_id": "kanto_cerulean_city", "battle_kind": "trainer"}) == &"cerulean_city")
	print("GYM_ARENAS_CHECK_OK")
	quit()

func _collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect(child, result)
