extends "res://tools/sprite_factory/forest_battle_review.gd"
## Paid assets stay in the isolated local project, never in the repository.
const CLEAR_RADIUS := 5.0
const BLEND_RADIUS := 9.0
const PATCH_RADIUS := 6.0
var ground_height := 0.0

func _surface_height(pos: Vector3) -> float:
	return preload("res://scripts/battle/arenas/generic/grassfield_layout.gd").height_at(pos.x, pos.z)

func _posed_clearance(meshes: Array) -> float:
	var minimum := INF
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var world_vertex: Vector3 = mesh.global_transform * vertex
				var surface_height: float = _surface_height(world_vertex)
				assert(is_finite(surface_height))
				minimum = minf(minimum, world_vertex.y - surface_height)
	return minimum

func _smoke() -> void:
	for frame in 30:
		await process_frame
	assert(response.world != null and response.sync_count > 0)
	for world in [stage.world, response.world]:
		var light_count := 0
		var shadow_count := 0
		for child in world.get_children():
			if child is DirectionalLight3D:
				light_count += 1
				shadow_count += int(child.shadow_enabled)
				assert(is_equal_approx(child.shadow_blur, 2.0 / 3.0))
				assert(child.light_color == Color.WHITE)
				assert(is_zero_approx(child.light_angular_distance))
				if child.shadow_enabled:
					assert(is_equal_approx(child.light_energy, 1.15))
		assert(light_count == 3 and shadow_count == 1)
	# Independently remeasure the corrected actors at half-frame offsets, after
	# the lighting pass exists. This would fail with the old stale-pose bake.
	for index in 2:
		var player: AnimationPlayer = players[index]
		var duration := player.get_animation("idle").length
		var meshes: Array = stage.actors[index].find_children("*", "MeshInstance3D", true, false)
		player.play("idle")
		player.pause()
		var minimum := INF
		for frame in ceili(duration * 60.0):
			player.seek(minf((frame + 0.5) / 60.0, duration), true)
			await RenderingServer.frame_post_draw
			minimum = minf(minimum, _posed_clearance(meshes))
		assert(minimum >= 0.015, "Rendered idle geometry intersects terrain")
		print("TEMPERATE_GROUND_VERIFIED actor=", stage.identities[index], " clearance=", minimum)
		player.play("idle")
	await super._smoke()

func _place_actor(actor: Node3D, animation_player: AnimationPlayer) -> void:
	# Review-only calibration. Sample posed geometry once, not the bind-pose
	# AABB or model origin. Production should cache this during asset preparation.
	assert(animation_player.has_animation("idle"))
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	var duration := animation_player.get_animation("idle").length
	var frames := maxi(1, ceili(duration * 60.0))
	var minimum := INF
	animation_player.play("idle")
	animation_player.pause()
	for frame in range(frames + 1):
		animation_player.seek(minf(frame / 60.0, duration), true)
		for skeleton: Skeleton3D in skeletons:
			skeleton.force_update_all_bone_transforms()
		# Baking reads RenderingServer skin transforms, not just CPU bone poses.
		await RenderingServer.frame_post_draw
		minimum = minf(minimum, _posed_clearance(meshes))
	assert(is_finite(minimum))
	var lift := maxf(0.0, 0.025 - minimum)
	actor.position.y += lift
	animation_player.seek(0.0, true)
	assert(minimum + lift >= 0.024)
	print("TEMPERATE_GROUND_OK actor=", actor.name, " idle_clearance=", minimum, " lift=", lift)

func _credit_text() -> String:
	return "FancifulCrow · Temperate Forest · isolated battle review\nFlat clearing · neutral Pokémon lighting · no gameplay changes"

func _ground_position(pos: Vector3) -> Vector3:
	pos.y = ground_height
	return pos


func _make_forest() -> Node3D:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in stage.world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0 / 3.0
	current_scene = stage
	var scene: Node3D = load("res://scripts/battle/arenas/generic/grassfield_arena.gd").new().build(stage.camera)
	scene.ready.connect(func():
		ground_height = float(scene.get_meta("surface_height",0.0))
		target.y = ground_height + 1.3
		_camera())
	return scene
