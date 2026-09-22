extends "res://scripts/battle/arenas/forest_arena.gd"
## Route 22 / Gary's meadow, authored from the actual (1488, 464) map location.
## Uses the SAME mounted forest terrain, foliage, bark, rock and flower assets.
## Only layout and in-memory terrain controls differ; no duplicated art pack.
const Geometry = preload("res://scripts/battle/arenas/arena_geometry.gd")
var route_scene: Node3D
var rng := RandomNumberGenerator.new()
var terrain_node: Node3D
var rock_materials := {}

func build(camera: Camera3D, scene_path := "res://pokeaether_forest.tscn") -> Node3D:
	route_scene = super.build(camera, scene_path)
	route_scene.name = "Route22RivalMeadow"
	route_scene.set_meta("source_map", "kanto_route_22")
	return route_scene

func _flatten(terrain) -> void:
	rng.seed = 220464
	terrain_node = terrain
	ground_height = terrain.data.get_height(Vector3.ZERO)
	# Hide authored static scenery only, never Terrain3D's generated containers.
	# Its grass/flowers remain alive and are conformed to our edited heights.
	for child in terrain.get_children():
		if child is Node3D and not child.scene_file_path.is_empty():
			child.visible = false
	for z in range(-55, 41):
		for x in range(-60, 61):
			var pos := Vector3(x, 0, z)
			var original: float = terrain.data.get_height(pos)
			if not is_finite(original):
				continue
			var north := 4.2 * smoothstep(18.0, 20.0, -float(z)) + 3.5 * smoothstep(28.0, 31.0, -float(z))
			var edge := smoothstep(34.0, 54.0, maxf(absf(x), absf(z)))
			terrain.data.set_height(pos, lerpf(ground_height + north, original, edge))
	terrain.data.update_maps()
	_paint_route(terrain)
	_clear_grass(terrain, Vector3.ZERO, 6.0)
	terrain.instancer.update_transforms(AABB(Vector3(-60, -100, -55), Vector3(120, 200, 96)))
	var scenery := Node3D.new()
	scenery.name = "Route22Scenery"
	route_scene.add_child(scenery)
	_terraces(scenery)
	_trees(scenery)
	_landmarks(scenery)
	_flowers(scenery)
	for point in [Vector3.ZERO, Vector3(-2.8, 0, 1.5), Vector3(2.8, 0, -1.5)]:
		assert(absf(terrain.data.get_height(point) - ground_height) < 0.001)
	print("ROUTE_22_TERRAIN_OK")

func _route_z(x: float) -> float:
	return -11.0 + 1.2 * sin(x * 0.12)

func _paint_route(terrain) -> void:
	var dirt = terrain.assets.get_texture(0).duplicate()
	dirt.name = "Route 22 shared ground detail"
	dirt.albedo_color = Color("b59b70")
	terrain.assets.set_texture(1, dirt)
	for z in range(-32, 6):
		for x in range(-40, 41):
			var pos := Vector3(x, 0, z)
			var horizontal := absf(z - _route_z(x))
			var staircase := absf(x - 5.0) if z < -11 else 100.0
			var distance := minf(horizontal, staircase)
			var blend := 1.0 - smoothstep(1.0, 2.0, distance)
			if blend <= 0.0 or not is_finite(terrain.data.get_height(pos)):
				continue
			terrain.data.set_control_base_id(pos, 0)
			terrain.data.set_control_overlay_id(pos, 1)
			terrain.data.set_control_blend(pos, blend)
			terrain.data.set_control_auto(pos, false)
	terrain.data.update_maps()
	for step in range(-80, 81):
		var x: float = step * 0.5
		_clear_grass(terrain, Vector3(x, 0, _route_z(x)), 1.8)
	for step in range(-64, -21):
		_clear_grass(terrain, Vector3(5, 0, step * 0.5), 1.9)

func _asset(parent: Node3D, path: String, point: Vector3, size: Vector3, angle := 0.0) -> Node3D:
	var node: Node3D = load("res://entities/nature/" + path + ".tscn").instantiate()
	_strip_runtime_helpers(node)
	node.position = point
	node.scale = size
	node.rotation.y = angle
	parent.add_child(node)
	return node

func _strip_runtime_helpers(node: Node) -> void:
	# Placement/collision helpers have no role in a battle presentation scene.
	node.set_script(null)
	for child in node.get_children():
		if child is CollisionObject3D:
			node.remove_child(child)
			child.free()
		else:
			_strip_runtime_helpers(child)

func _height(x: float, z: float) -> float:
	return terrain_node.data.get_height(Vector3(x, 0, z))

func _terraces(parent: Node3D) -> void:
	var cliffs := Node3D.new()
	cliffs.name = "NorthernRockTerraces"
	parent.add_child(cliffs)
	# Normalize different source rock sizes before arranging overlapping strata.
	# Keep the meadow open; the north wall is a backdrop, not giant foreground rocks.
	for row in 3:
		for i in 20:
			var x: float = -38.0 + i * 4.0
			if row < 2 and x > 1.0 and x < 9.0:
				continue
			var z: float = [-18.8, -20.0, -29.0][row] + rng.randf_range(-0.3, 0.3)
			var y: float = [0.0, 2.0, 4.1][row]
			var rock := _asset(cliffs, "rocks/rock_object_" + ["a", "c", "e"][i % 3], Vector3.ZERO, Vector3.ONE)
			var boxes: Array = []
			_bounds(rock, Transform3D.IDENTITY, boxes)
			var bounds: AABB = boxes[0]
			for box: AABB in boxes:
				bounds = bounds.merge(box)
			rock.scale = Vector3(5.3, 2.8 if row < 2 else 3.8, 4.5) / bounds.size
			rock.position = Vector3(x, ground_height + y - bounds.position.y * rock.scale.y - 0.25, z)
			rock.rotation.y = rng.randf_range(-0.20, 0.20)
			_tint_rock(rock)

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("a88b6a"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2.0)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "RouteConifers"
	parent.add_child(trees)
	# Real textured firs/spruces from the forest kit, with varied silhouettes.
	for side in [-1, 1]:
		for row in 2:
			for i in 7:
				var x: float = side * (13.5 + row * 6.0) + rng.randf_range(-1.0, 1.0)
				var z: float = 3.0 - i * 3.4 + rng.randf_range(-0.6, 0.6)
				if side == -1 and row == 1:
					x -= 5.0 # reveal the paved League approach between the rows
				var size := rng.randf_range(0.28, 0.40)
				var tree := _asset(trees, "trees/" + ["fir_tree_a", "spruce_tree_b", "fir_tree_c"][i % 3],
					Vector3(x, _height(x, z), z), Vector3.ONE * size, rng.randf() * TAU)
				# Leave the Pokémon clearing sunlit, as in the existing forest.
				if _shades_battle(tree):
					tree.position.x += side * 6.0
	for i in 14:
		var x: float = -36.0 + i * 5.0
		if x > 0 and x < 10:
			continue
		var z: float = -24.0
		_asset(trees, "trees/fir_tree_b", Vector3(x, _height(x, z), z), Vector3.ONE * rng.randf_range(0.25, 0.34), rng.randf() * TAU)

func _landmarks(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Route22Landmarks"
	parent.add_child(props)
	var geo = Geometry.new(route_scene)
	var box := BoxMesh.new()
	var steps = geo._stone(Color("aaa393"))
	var timber = geo._stone(Color("79543a"))
	var rails = geo._stone(Color("d1d4bb"))
	for i in 14:
		var height := (i + 1) * 0.30
		var z: float = -11.6 - i * 0.60
		geo._put(props, box, steps, Vector3(5, ground_height + height * 0.5 + 0.03, z), Vector3(3.2, height, 0.61))
		for side in [-1, 1]:
			geo._put(props, box, timber, Vector3(5 + side * 1.73, ground_height + height + 0.13, z), Vector3(0.18, 0.26, 0.61))
	for side in [-1, 1]:
		for i in [0, 6, 13]:
			geo._put(props, box, timber, Vector3(5 + side * 1.73, ground_height + (i + 1) * 0.30 + 0.45, -11.6 - i * 0.60), Vector3(0.22, 0.95, 0.22))
	for x in [-9.5, 9.5]:
		for i in 5:
			geo._put(props, box, rails, Vector3(x, ground_height + 0.36, -4.0 + i * 0.65), Vector3(0.12, 0.72, 0.12))
		for y in [0.25, 0.55]:
			geo._put(props, box, rails, Vector3(x, ground_height + y, -2.7), Vector3(0.10, 0.10, 2.9))
	var paving = geo._stone(Color("7a7c76"), true)
	geo._put(props, box, paving, Vector3(-19.0, ground_height + 0.035, -6), Vector3(4.5, 0.07, 22))
	for side in [-1, 1]:
		geo._put(props, box, steps, Vector3(-19.0 + side * 2.35, ground_height + 0.08, -6), Vector3(0.20, 0.16, 22))
	for step in range(-32, 11):
		_clear_grass(terrain_node, Vector3(-19, 0, step * 0.5), 2.3)

func _flowers(parent: Node3D) -> void:
	var flowers := Node3D.new()
	flowers.name = "RouteFlowers"
	parent.add_child(flowers)
	for center in [Vector2(-7.8, -5.5), Vector2(8.1, -6.4), Vector2(9.2, -12), Vector2(-7.5, 4.2)]:
		for i in 14:
			var x: float = center.x + rng.randf_range(-1.1, 1.1)
			var z: float = center.y + rng.randf_range(-0.7, 0.7)
			_asset(flowers, "flowers/" + ("lupine_flower" if i % 3 != 0 else "anemone_flower"),
				Vector3(x, _height(x, z), z), Vector3.ONE * rng.randf_range(0.65, 0.95), rng.randf() * TAU)
