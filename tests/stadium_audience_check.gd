extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	assert(Arenas.resolve("auto", &"pvp_stadium", "pvp") == "stadium")
	var world := Node3D.new()
	root.add_child(world)
	var arena := Arenas.build("stadium", world)
	world.add_child(arena)
	var audience := arena.get_node("StadiumAudience")
	assert(audience.get_child_count() == 160)
	var sides := [0, 0, 0, 0]
	var meshes: Array[MeshInstance3D] = []
	for spectator in audience.get_children():
		var position: Vector3 = spectator.position
		var side := 0 if position.z < -19 else (2 if position.z > 19 else (1 if position.x < 0 else 3))
		sides[side] += 1
		assert((spectator.basis * Vector3.BACK).dot(Vector3(-position.x, 0, -position.z).normalized()) > 0.99)
		assert(spectator.has_node("Character/CharacterArmature/Skeleton3D"))
		assert(spectator.get_node("Character").find_children("Pistol", "MeshInstance3D", true, false).is_empty())
		for mesh in spectator.find_children("*", "MeshInstance3D", true, false):
			assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			meshes.append(mesh)
		spectator.elapsed = 0.0
		spectator._process(0.5)
		assert(spectator.animation_player.current_animation == "Wave")
		spectator._process(4.0)
		assert(spectator.animation_player.current_animation == "Idle_Neutral")
	assert(sides == [40, 40, 40, 40])
	# Audience must remain outside the camera orbit and both combatants' sightlines.
	for yaw in range(0, 360, 10):
		for pitch in [-0.12, 0.0, 0.65]:
			for zoom in [Renderer.USER_CAMERA_ZOOM_MIN, 1.0, Renderer.USER_CAMERA_ZOOM_MAX]:
				var target := Arenas.camera_target("stadium")
				var offset := (Arenas.camera_home("stadium") - target).rotated(Vector3.UP, deg_to_rad(yaw))
				var camera: Vector3 = target + offset.rotated(offset.cross(Vector3.UP).normalized(), pitch) * zoom
				for mesh in meshes:
					var inverse := mesh.global_transform.affine_inverse()
					var bounds := mesh.get_aabb()
					assert(not bounds.grow(0.12).has_point(inverse * camera))
					for side in 2:
						for height in [0.5, 2.0, 4.0]:
							assert(not bounds.intersects_segment(inverse * camera, inverse * (Arenas.spawn(side) + Vector3(0, height, 0))), "Audience occludes combatant at yaw=%s pitch=%s zoom=%s: %s" % [yaw, pitch, zoom, mesh.get_path()])
	world.free()
	print("STADIUM_AUDIENCE_CHECK_OK: 160 supporters, four sides, animations and camera orbit")
	quit()
