extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Profiles = preload("res://scripts/battle/battle_environment_catalog.gd")
const Resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	assert(Profiles.get_profile(&"ss_anne").is_valid())
	for floor_name in ["b1f", "1f", "2f", "3f"]:
		var map_id: String = "kanto_ss_anne_" + floor_name
		for kind in ["trainer", "wild"]:
			var context := {"map_id": map_id, "battle_kind": kind, "player_on_water": true}
			assert(Resolver.resolve(context) == &"ss_anne")
			assert(Arenas.resolve("auto", Resolver.resolve(context), kind) == "ss_anne")
			context.explicit_environment_id = "cave"
			assert(Resolver.resolve(context) == &"cave")
		assert(Resolver.resolve({"map_id": map_id, "battle_kind": "pvp"}) == &"pvp_stadium")
		var scene: PackedScene = load("res://scenes/overworld/kanto/towns/ss_anne/ss_anne_" + floor_name + ".tscn")
		var map := scene.instantiate()
		root.add_child(map)
		await process_frame
		assert(map.map_id == map_id)
		for npc in map.get_node("Entities/NPCs").get_children():
			if npc.has_method("build_battle_trainer_metadata"):
				var metadata: Dictionary = npc.build_battle_trainer_metadata({})
				assert(Resolver.resolve({"map_id": map.map_id, "battle_kind": "trainer", "explicit_environment_id": metadata.get("battleEnvironmentId", "")}) == &"ss_anne", str(npc.name))
		map.free()
	assert(not Arenas.uses_forest_assets("ss_anne"))
	assert(Arenas.resolve("sea", &"ss_anne", "trainer") == "sea")
	var id := "ss_anne"
	for pass_index in 2:
		var world := Node3D.new()
		root.add_child(world)
		var arena := Arenas.build(id, world)
		world.add_child(arena)
		assert(arena.has_node("ShipSuperstructure/ShipName"))
		assert(arena.has_node("Ocean") and arena.has_node("OutdoorLighting"))
		var meshes: Array[MeshInstance3D] = []
		_collect(arena, meshes)
		assert(meshes.size() < 300)
		for side in 2:
			var supported := false
			for mesh in meshes:
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				if bounds.grow(0.002).has_point(Arenas.spawn(side)) and absf(bounds.end.y) < 0.002:
					supported = true
			assert(supported)
		for yaw in range(0, 360, 5):
			for pitch in [-0.12, 0.0, 0.65]:
				for zoom in [Renderer.USER_CAMERA_ZOOM_MIN, 1.0, Renderer.USER_CAMERA_ZOOM_MAX]:
					var target := Arenas.camera_target(id)
					var offset := (Arenas.camera_home(id) - target).rotated(Vector3.UP, deg_to_rad(yaw))
					var camera: Vector3 = target + offset.rotated(offset.cross(Vector3.UP).normalized(), pitch) * zoom
					for mesh in meshes:
						var inverse := mesh.global_transform.affine_inverse()
						var bounds := mesh.get_aabb()
						assert(not bounds.grow(0.12).has_point(inverse * camera), "Camera intersects " + str(mesh.get_path()))
						for side in 2:
							for height in [0.5, 2.0, 4.0]:
								var aim := Arenas.spawn(side) + Vector3(0, height, 0)
								assert(not bounds.intersects_segment(inverse * camera, inverse * aim), "Scenery hides combatant: " + str(mesh.get_path()))
		world.free()
	print("SS_ANNE_ARENA_CHECK_OK: four floors, both passes, ground contact and full camera orbit")
	quit()
func _collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect(child, result)
