extends "res://tools/sprite_factory/forest_battle_review.gd"
## Paid assets stay in the isolated local project, never in the repository.
const CLEAR_RADIUS := 5.0
const BLEND_RADIUS := 9.0
const PATCH_RADIUS := 6.0
var ground_height := 0.0
var battle_terrain: Node3D

func _surface_height(pos: Vector3) -> float:
	return battle_terrain.data.get_height(pos)

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

func _route_z(x: float) -> float:
	return -18.0 + 2.3 * sin(x * 0.12)

func _paint_route(terrain) -> void:
	# Reuse the purchased ground detail with a warm dirt tint, no new bitmap.
	var dirt = terrain.assets.get_texture(0).duplicate()
	dirt.name = "Review route dirt"
	dirt.albedo_color = Color("b59b70")
	terrain.assets.set_texture(1, dirt)
	for x in range(-45, 46):
		for z in range(-23, -12):
			var pos := Vector3(x, 0, z)
			var route_distance := absf(z - _route_z(x))
			var blend := 1.0 - smoothstep(0.8, 1.8, route_distance)
			if blend <= 0.0 or not is_finite(terrain.data.get_height(pos)):
				continue
			terrain.data.set_control_base_id(pos, 0)
			terrain.data.set_control_overlay_id(pos, 1)
			terrain.data.set_control_blend(pos, blend)
			terrain.data.set_control_auto(pos, false)
	for step in range(-90, 91):
		var x := step * 0.5
		_clear_grass(terrain, Vector3(x, 0, _route_z(x)), 1.65)
	terrain.data.update_maps()
	assert(terrain.data.get_control_overlay_id(Vector3(0, 0, -18)) == 1)
	print("TEMPERATE_ROUTE_OK")

func _clear_grass(terrain, pos: Vector3, radius: float) -> void:
	terrain.instancer.remove_instances(pos, {
		"asset_id": 0, "modifier_shift": true, "modifier_alt": false,
		"size": radius / 0.4,
		"strength": 100.0, "slope": Vector2(0, 90)})

func _credit_text() -> String:
	return "FancifulCrow · Temperate Forest · isolated battle review\nFlat clearing · neutral Pokémon lighting · no gameplay changes"

func _ground_position(pos: Vector3) -> Vector3:
	pos.y = ground_height
	return pos

func _make_forest() -> Node3D:
	# Isolated desktop review quality, shared by both rendering passes. High
	# filtering multiplies blur by 1.5; compensate to keep effective radius 1.
	# Do not change the approved rig's energy, direction, colors or materials.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in stage.world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0 / 3.0
	# Terrain3D expects a current scene even in this SceneTree-script harness.
	current_scene = stage
	var scene: Node3D = load("res://scenes/world/test_world.res").instantiate()
	for node_name in ["Rendering", "Player", "WorldBarrier", "GrassPlacer"]:
		var node := scene.get_node_or_null(NodePath(node_name))
		if node != null:
			scene.remove_child(node)
			node.free()
	var terrain = scene.get_node("Terrain3D")
	if battle_terrain == null:
		battle_terrain = terrain
	terrain.set_camera(stage.camera)
	# Hide only objects occupying the battle space or casting shade across it.
	# Preserve Terrain3D-owned runtime nodes and retain scene ownership until
	# normal teardown; do not free terrain children during construction.
	scene.ready.connect(func(): _flatten(terrain))
	return scene

func _bounds(node: Node, accumulated: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(accumulated * node.get_aabb())
	for child in node.get_children():
		_bounds(child, accumulated, boxes)

func _shades_battle(node: Node3D) -> bool:
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var sun_ray := Basis.from_euler(Vector3(-45, -30, 0) * PI / 180.0) * Vector3.FORWARD
	for box: AABB in boxes:
		var shadow := Rect2()
		for corner in 8:
			var p := box.get_endpoint(corner)
			p += sun_ray * maxf(0.0, (ground_height - p.y) / sun_ray.y)
			var projected := Vector2(p.x, p.z)
			shadow = Rect2(projected, Vector2.ZERO) if corner == 0 else shadow.expand(projected)
		if shadow.intersects(Rect2(-6, -4, 12, 8)):
			return true
	return false

func _flatten(terrain) -> void:
	# Runtime-only edits: original purchased terrain resources are never saved.
	ground_height = terrain.data.get_height(Vector3.ZERO)
	target.y = ground_height + 1.3
	_camera()
	for child in terrain.get_children():
		# Never hide Terrain3D's generated Instancer container at the origin:
		# that hides every grass/flower instance across the entire environment.
		if child is Node3D and not child.scene_file_path.is_empty() and (Vector2(child.position.x, child.position.z).length() < 9.0 or _shades_battle(child)):
			child.visible = false
		if child is Node3D and child.scene_file_path.is_empty():
			assert(child.visible, "Generated terrain vegetation must remain visible")
	for z in range(-9, 10):
		for x in range(-9, 10):
			var pos := Vector3(x, 0, z)
			var radius := Vector2(x, z).length()
			if radius >= BLEND_RADIUS:
				continue
			var height: float = terrain.data.get_height(pos)
			assert(is_finite(height))
			var blend := smoothstep(CLEAR_RADIUS, BLEND_RADIUS, radius)
			terrain.data.set_height(pos, lerpf(ground_height, height, blend))
	terrain.data.update_maps()
	# Terrain3D 1.0.1 uses 0.4 * size as removal radius, not size / 2.
	# One shared circular arena: retain all grass outside its boundary.
	_clear_grass(terrain, Vector3.ZERO, PATCH_RADIUS)
	_paint_route(terrain)
	terrain.instancer.update_transforms(AABB(Vector3(-9, -100, -9), Vector3(18, 200, 18)))
	for pos in [Vector3.ZERO, Vector3(-2.8, 0, 1.5), Vector3(2.8, 0, -1.5)]:
		assert(absf(terrain.data.get_height(pos) - ground_height) < 0.001)
	print("TEMPERATE_CLEARING_OK radius=", CLEAR_RADIUS)
