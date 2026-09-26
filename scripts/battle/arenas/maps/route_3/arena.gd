extends "res://scripts/battle/arenas/shared/mesh_grassland.gd"
## Route 3: an east-west mountain road between Pewter and Mt. Moon.
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
const BASE_HEIGHT := 0.037750244140625
var rock_materials: Dictionary = {}

func _cache_key() -> String:
	return "route_3"

func build(_camera: Camera3D = null) -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 30050
	_start_scene("Route3MountainRoad")
	route_scene.set_meta("source_map", "kanto_route_3")
	route_scene.set_meta("surface_height", ground_height)
	var scenery := Node3D.new()
	scenery.name = "Route3Scenery"
	route_scene.add_child(scenery)
	_rock_ridges(scenery)
	_conifers(scenery)
	_road_landmarks(scenery)
	_flowers(scenery)
	_grass(scenery)
	return route_scene

func _road_z(x: float) -> float:
	return 9.0 + 2.0 * sin(x * 0.10) - 1.5 * sin(x * 0.23)

func _path_distance(x: float, z: float) -> float:
	return absf(z - _road_z(x))

func _height(x: float, z: float) -> float:
	# Keep the battle clearing flat. The north and south ridges frame the road.
	var north := 3.2 * smoothstep(16.0, 23.0, -z)
	var south := 1.6 * smoothstep(25.0, 33.0, z)
	return BASE_HEIGHT + north + south

func _dirt(x: float, z: float) -> float:
	return maxf(1.0 - smoothstep(2.8, 4.6, _path_distance(x, z)),
		0.45 * (1.0 - smoothstep(0.0, 3.0, absf(z + 20.0))))

func _has_grass(x: float, z: float) -> bool:
	return (Vector2(x, z).length() > 6.2 and _path_distance(x, z) > 4.3
		and not (absf(z + 20.0) < 2.0))

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("aa8967"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2.0)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _rock_ridges(parent: Node3D) -> void:
	var ridges := Node3D.new()
	ridges.name = "RockRidges"
	parent.add_child(ridges)
	for row in 3:
		var z: float = [-21.0, -29.0, 34.0][row]
		for i in 19:
			var x: float = -47.0 + i * 5.2 + rng.randf_range(-0.4, 0.4)
			var rock := _asset(ridges, "rocks/rock_object_" + ["a", "c", "e"][i % 3], Vector3.ZERO, Vector3.ONE)
			var boxes: Array = []
			_bounds(rock, Transform3D.IDENTITY, boxes)
			var bounds: AABB = boxes[0]
			for box: AABB in boxes:
				bounds = bounds.merge(box)
			rock.scale = Vector3(5.7, 3.8 if row == 0 else 2.8, 4.3) / bounds.size
			rock.position = Vector3(x, _height(x, z) - 0.5 - bounds.position.y * rock.scale.y, z)
			rock.rotation.y = rng.randf_range(-0.2, 0.2)
			_tint_rock(rock)
	# Break up the long road with scattered boulders, outside the battle stage.
	for point in [Vector2(-18, -11), Vector2(-29, 19), Vector2(24, -13), Vector2(35, 18)]:
		var rock := _asset(ridges, "rocks/rock_object_a",
			Vector3(point.x, _height(point.x, point.y), point.y), Vector3(0.9, 0.7, 0.85), rng.randf() * TAU)
		_tint_rock(rock)

func _conifers(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "MountainConifers"
	parent.add_child(trees)
	for side in [-1, 1]:
		for row in 2:
			for i in 13:
				var x: float = -45.0 + i * 7.3 + rng.randf_range(-1.1, 1.1)
				var z: float = side * (16.0 + row * 9.0) + rng.randf_range(-1.2, 1.2)
				if _path_distance(x, z) < 5.5 or absf(z + 20.0) < 2.5:
					continue
				var tree := _asset(trees, "trees/" + ["fir_tree_a", "spruce_tree_b", "fir_tree_c"][i % 3],
					Vector3(x, _height(x, z), z), Vector3.ONE * rng.randf_range(0.26, 0.37), rng.randf() * TAU)
				if _shades_battle(tree):
					tree.position.z += side * 7.0
					tree.position.y = _height(tree.position.x, tree.position.z)

func _road_landmarks(parent: Node3D) -> void:
	var landmarks := Node3D.new()
	landmarks.name = "RoadLandmarks"
	parent.add_child(landmarks)
	var geo := Geometry.new(route_scene)
	var box := BoxMesh.new()
	var timber = geo._stone(Color("75543d"))
	var pale = geo._stone(Color("d2d2ba"))
	# Short fence runs recall the route's guarded ledges without blocking the road.
	for segment in [[-34.0, -22.0, -11.0], [19.0, 34.0, -11.0], [-34.0, -23.0, 24.0]]:
		var left: float = segment[0]
		var right: float = segment[1]
		var z: float = segment[2]
		for x in range(int(left), int(right) + 1, 3):
			geo._put(landmarks, box, timber, Vector3(x, _height(x, z) + 0.45, z), Vector3(0.15, 0.9, 0.15))
		for y in [0.30, 0.63]:
			geo._put(landmarks, box, pale, Vector3((left + right) * 0.5, _height((left + right) * 0.5, z) + y, z),
				Vector3(right - left, 0.10, 0.10))

func _flowers(parent: Node3D) -> void:
	var flowers := Node3D.new()
	flowers.name = "RoadsideFlowers"
	parent.add_child(flowers)
	for center in [Vector2(-10, -9), Vector2(15, -10), Vector2(-18, 20), Vector2(28, 21)]:
		for i in 10:
			var x: float = center.x + rng.randf_range(-1.2, 1.2)
			var z: float = center.y + rng.randf_range(-0.8, 0.8)
			_asset(flowers, "flowers/" + ("lupine_flower" if i % 3 else "anemone_flower"),
				Vector3(x, _height(x, z), z), Vector3.ONE * rng.randf_range(0.55, 0.85), rng.randf() * TAU)
