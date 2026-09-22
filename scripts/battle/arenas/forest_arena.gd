extends RefCounted
## Terrain3D-backed approved forest, mounted from the user's purchased local pack.
const CLEAR_RADIUS := 5.0
const BLEND_RADIUS := 9.0
const PATCH_RADIUS := 6.0
var ground_height := 0.0

func build(camera: Camera3D, scene_path := "res://pokeaether_forest.tscn") -> Node3D:
	var scene: Node3D = load(scene_path).instantiate()
	for node_name in ["Rendering","Player","WorldBarrier","GrassPlacer"]:
		var node := scene.get_node_or_null(NodePath(node_name))
		if node != null:
			scene.remove_child(node)
			node.free()
	var terrain = scene.get_node("Terrain3D")
	for property in terrain.get_property_list():
		if property.name == "free_editor_textures":
			terrain.set("free_editor_textures",false)
	terrain.set_camera(camera)
	# The outdoor pack supplies terrain/vegetation rather than a battle-grade
	# fill light. A soft skylight keeps dark SCVI materials readable under the
	# forest canopy without changing individual Pokémon materials or shadows.
	var skylight := DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-72.0, 150.0, 0.0)
	skylight.light_color = Color("c9e6ff")
	skylight.light_energy = 0.52
	skylight.shadow_enabled = false
	scene.add_child(skylight)
	scene.ready.connect(func():
		_flatten(terrain)
		scene.set_meta("surface_height", ground_height))
	return scene

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
