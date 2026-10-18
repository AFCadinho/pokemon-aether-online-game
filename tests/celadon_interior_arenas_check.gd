extends SceneTree
## Actual map/NPC selection plus full camera orbit clearance of both indoor halls.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const MAPS := {
	"celadon_game_corner": ["celadon_city/game_corner"],
	"celadon_gym": ["celadon_city/celadon_gym"],
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(90).timeout.connect(func(): printerr("CELADON_INTERIOR_ARENAS_TIMEOUT"); quit(2))
	for id: String in MAPS:
		assert(Profiles.get_profile(StringName(id)).is_valid())
		assert(Arenas.resolve("auto", StringName(id), "wild") == id)
		assert(Arenas.resolve("auto", StringName(id), "trainer") == id)
		assert(Arenas.resolve("cave", StringName(id), "wild") == "cave")
		assert(not Arenas.uses_forest_assets(id) and not Arenas.uses_outdoor_lighting(id))
		for path: String in MAPS[id]:
			var map: Node = load("res://scenes/overworld/kanto/towns/%s.tscn" % path).instantiate()
			var map_id: String = map.get("map_id")
			for kind in ["trainer", "wild"]:
				var context := {"map_id": map_id, "battle_kind": kind, "map_environment_id": map.get("battle_environment_id")}
				assert(Resolver.resolve(context) == StringName(id), path)
				assert(Arenas.resolve("auto", Resolver.resolve(context), kind) == id)
				context.explicit_environment_id = "water"
				assert(Resolver.resolve(context) == &"water", "Explicit override remains authoritative")
			assert(Resolver.resolve({"map_id": map_id, "battle_kind": "pvp"}) == &"pvp_stadium")
			for npc in map.find_children("*", "Node", true, false):
				if npc.has_method("build_battle_trainer_metadata"):
					if npc.has_method("_apply_npc_profile"):
						npc._apply_npc_profile()
					var metadata: Dictionary = npc.build_battle_trainer_metadata({})
					assert(Resolver.resolve({"map_id": map_id, "battle_kind": "trainer", "explicit_environment_id": metadata.get("battleEnvironmentId", "")}) == StringName(id), str(npc.name))
			map.free()
		var world := Node3D.new()
		root.add_child(world)
		var arena := Arenas.build(id, world)
		world.add_child(arena)
		assert(arena.get_meta("source_map") == Arenas.definition(id).map_id)
		assert(is_zero_approx(float(arena.get_meta("surface_height"))))
		assert(arena.has_node("EnclosedHall") and not arena.has_node("OutdoorLighting"))
		assert(arena.has_node("ErikaScreen/RainbowBadge") if id == "celadon_gym" else arena.has_node("SlotMachines"))
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
		# The material-response pass must get its own arena and release independently.
		var response_world := Node3D.new()
		root.add_child(response_world)
		var response_arena := Arenas.build(id, response_world)
		response_world.add_child(response_arena)
		assert(response_arena != arena and response_arena.get_child_count() == arena.get_child_count())
		var response_ref: WeakRef = weakref(response_arena)
		response_world.free()
		assert(response_ref.get_ref() == null and is_instance_valid(arena))
		world.free()
		print("CELADON_INTERIOR_ARENA_OK: ", id, " meshes=", meshes.size(), " camera samples=648")
	assert(Resolver.resolve({"map_id": "kanto_pewter_city", "battle_kind": "trainer"}) == &"pewter_city")
	assert(Resolver.resolve({"map_id": "kanto_cerulean_city", "battle_kind": "trainer"}) == &"cerulean_city")
	print("CELADON_INTERIOR_ARENAS_CHECK_OK")
	quit()

func _collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect(child, result)
