extends "res://scripts/battle/arenas/shared/mesh_grassland.gd"
## The pixel map's stepped foothills, grass plots and Mt. Moon approach.
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
const Landmarks = preload("res://scripts/battle/arenas/maps/route_3/landmarks.gd")
const BASE_HEIGHT := 0.037750244140625
const CENTER := Vector2(7.5, -19.5)
const CAVE := Vector2(-0.5, -32.0)
const ROAD := [Vector2(-55, 3), Vector2(-19, 3), Vector2(-10, -7), Vector2(2, -7), Vector2(15, -10), Vector2(18, -17), Vector2(18, -20)]
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
	_undergrowth(scenery)
	_grass(scenery)
	return route_scene

func _height(x: float, z: float) -> float:
	var first := lerpf(2.4 * clampf((-z - 10.0) / 6.0, 0, 1),
		2.4 * smoothstep(12.5, 15.0, -z), smoothstep(2.2, 3.6, absf(x + 10.0)))
	var second := lerpf(3.2 * clampf((-z - 22.0) / 6.0, 0, 1),
		3.2 * smoothstep(25.0, 28.0, -z), smoothstep(2.2, 3.6, absf(x - CAVE.x)))
	return BASE_HEIGHT + first + second + 4.3 * smoothstep(37.0, 41.0, -z) + 1.8 * smoothstep(23, 28, z)

func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(a + (b - a) * clampf((point - a).dot(b - a) / a.distance_squared_to(b), 0, 1))

func _path_distance(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var distance := 100.0
	for i in ROAD.size() - 1:
		distance = minf(distance, _segment_distance(point, ROAD[i], ROAD[i + 1]))
	# Landings and paths connect both flights of stairs to the center and cave.
	for segment in [[Vector2(-10, -7), Vector2(-10, -19)],
		[Vector2(-29, -19), Vector2(18, -19)],
		[Vector2(CAVE.x, -19), Vector2(CAVE.x, -32)]]:
		distance = minf(distance, _segment_distance(point, segment[0], segment[1]))
	return distance

func _dirt(x: float, z: float) -> float:
	var road := 1.0 - smoothstep(1.3, 2.1, _path_distance(x, z))
	var forecourt := 1.0 - smoothstep(3.8, 5.3, (Vector2(x, z) - CENTER).length())
	var mountain := smoothstep(32, 38, -z)
	var clearing := 1.0 - smoothstep(3.0, 6.0, Vector2(x, z).length())
	var wear := clearing * 0.18 * (0.5 + 0.5 * sin(x * 1.4 + cos(z * 1.1)))
	return maxf(maxf(maxf(road, forecourt), mountain), wear)

func _has_grass(x: float, z: float) -> bool:
	if Vector2(x, z).length() < 5.8 or _path_distance(x, z) < 2.0 or z < -33:
		return false
	if (Vector2(x, z) - CENTER).length() < 5.4 or absf(z + 13.7) < 1.6 or absf(z + 26.5) < 1.5:
		return false
	# The map uses separate tall-grass plots with short-grass walkways between.
	for patch in [Rect2(-18, -5, 10, 7), Rect2(8, -5, 10, 7), Rect2(-7, -12, 12, 3),
		Rect2(-27, -24, 12, 3), Rect2(-29, 8, 15, 9), Rect2(15, 6, 13, 12)]:
		if patch.has_point(Vector2(x, z)):
			return true
	return Vector2(x, z).length() > 12.0 and sin(x * 0.73) + cos(z * 0.57) > 0.65

func _sized_asset(parent: Node3D, path: String, point: Vector3, size: Vector3, angle := 0.0) -> Node3D:
	var node := _asset(parent, path, Vector3.ZERO, Vector3.ONE)
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var bounds: AABB = boxes[0]
	for box: AABB in boxes:
		bounds = bounds.merge(box)
	node.scale = size / bounds.size
	node.rotation.y = angle
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	node.position = point - node.basis * pivot
	return node

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("9e7855"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2.0)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _rock(parent: Node3D, point: Vector3, size: Vector3, index: int) -> Node3D:
	var rock := _sized_asset(parent, "rocks/rock_object_" + ["a", "c", "e"][index % 3], point, size, rng.randf_range(-0.2, 0.2))
	_tint_rock(rock)
	return rock

func _rock_ridges(parent: Node3D) -> void:
	var ridges := Node3D.new()
	ridges.name = "RockRidges"
	parent.add_child(ridges)
	var geo := Geometry.new(route_scene)
	var cliff_material: StandardMaterial3D = geo._stone(Color("98714f"))
	cliff_material.vertex_color_use_as_albedo = true
	for row in 3:
		var z: float = [-11.75, -24.75, -36.75][row]
		var base_y: float = [BASE_HEIGHT, BASE_HEIGHT + 2.4, BASE_HEIGHT + 5.6][row]
		var rise: float = [2.4, 3.2, 4.3][row]
		var gap_x: float = [-10.0, CAVE.x, 1000.0][row]
		var back_z: float = [-15.1, -28.1, -41.1][row]
		var face: MeshInstance3D = geo._put(ridges, _cliff_mesh(z, back_z, base_y, rise, gap_x), cliff_material, Vector3.ZERO, Vector3.ONE)
		face.name = "CliffFace%d" % row
		for i in 15:
			var x := -45.0 + i * 6.0 + rng.randf_range(-1, 1)
			if absf(x - gap_x) < 5.0:
				continue
			_rock(ridges, Vector3(x, base_y - 0.08, z + 0.7), Vector3(1.4, 0.8, 1.1), i)
	# Scattered mountain debris from the pixel map, varied in scale.
	for i in 44:
		var x := rng.randf_range(-43, 36)
		var z := rng.randf_range(-48, -34)
		if Vector2(x - CAVE.x, z - CAVE.y).length() < 5:
			continue
		var size := rng.randf_range(0.45, 2.0)
		_rock(ridges, Vector3(x, _height(x, z) - 0.08, z), Vector3(size, size * 1.2, size), i)
	for point in [Vector2(-7.4, -3.5), Vector2(7.6, -4.5), Vector2(-14, 5), Vector2(19, -12), Vector2(-19, -10)]:
		_rock(ridges, Vector3(point.x, _height(point.x, point.y) - 0.05, point.y), Vector3(1.3, 0.9, 1.1), ridges.get_child_count())

func _cliff_mesh(z: float, back_z: float, base_y: float, rise: float, gap_x: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-55, 51):
		if x < gap_x + 3.8 and x + 1 > gap_x - 3.8:
			continue
		for band in 4:
			var vertices: Array[Vector3] = []
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var px: float = x + corner.x
				var level: float = (band + corner.y) / 4.0
				var jitter := sin(px * 1.7) * 0.13 + cos(px * 0.83) * 0.10
				vertices.append(Vector3(px, base_y + rise * level, z - level * 1.5 + jitter))
			st.set_color(Color(0.88, 0.85, 0.82) if band % 2 == 0 else Color(1, 0.98, 0.93))
			for i in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(vertices[i])
		# Close the ledge against the plateau; the face sits ahead of the terrain
		# ramp so green terrain cannot poke through its rock strata.
		var left_z := z - 1.5 + sin(x * 1.7) * 0.13 + cos(x * 0.83) * 0.10
		var right_z := z - 1.5 + sin((x + 1) * 1.7) * 0.13 + cos((x + 1) * 0.83) * 0.10
		var top := base_y + rise
		st.set_color(Color(0.9, 0.88, 0.84))
		for v in [Vector3(x, top, left_z), Vector3(x, top, back_z), Vector3(x + 1, top, right_z),
			Vector3(x + 1, top, right_z), Vector3(x, top, back_z), Vector3(x + 1, top, back_z)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _conifers(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "MountainConifers"
	parent.add_child(trees)
	# Dense groups and straight borders echo the tree blocks on the tilemap.
	for row in [[-29.0, -22.0, 5], [-26.0, -9.5, 5], [-27.0, -32.0, 6], [15.0, -27.5, 6]]:
		for i in int(row[2]):
			var x: float = row[0] + i * 3.0
			var z: float = row[1] + rng.randf_range(-0.3, 0.3)
			_tree(trees, x, z, i)
	for side in [-1, 1]:
		for i in 5:
			_tree(trees, side * (21.0 + rng.randf_range(-1, 1)), 2.0 + i * 5.0, i)

func _tree(parent: Node3D, x: float, z: float, index: int) -> void:
	_sized_asset(parent, "trees/" + ["fir_tree_a", "spruce_tree_b", "fir_tree_c"][index % 3],
		Vector3(x, _height(x, z), z), Vector3(4.0, rng.randf_range(6.0, 8.3), 4.0), rng.randf() * TAU)

func _road_landmarks(parent: Node3D) -> void:
	var landmarks := Node3D.new()
	landmarks.name = "RoadLandmarks"
	parent.add_child(landmarks)
	var kit := Landmarks.new(route_scene)
	kit.stairs(landmarks, Vector3(-10, BASE_HEIGHT, -10), 2.4, "LowerStairs")
	kit.stairs(landmarks, Vector3(CAVE.x, BASE_HEIGHT + 2.4, -22), 3.2, "MoonStairs")
	kit.pokemon_center(landmarks, Vector3(CENTER.x, _height(CENTER.x, CENTER.y), CENTER.y))
	kit.cave(landmarks, Vector3(CAVE.x, _height(CAVE.x, CAVE.y), CAVE.y))
	kit.signpost(landmarks, Vector3(3.5, _height(3.5, -15.5), -15.5))
	for segment in [[-26.0, -16.0, -11.5], [3.0, 14.0, -12.0], [-21.0, -15.0, 4.5]]:
		kit.fence(landmarks, Vector3(segment[0], _height(segment[0], segment[2]), segment[2]), segment[1] - segment[0])

func _undergrowth(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "RoadsideFlowers"
	parent.add_child(details)
	for center in [Vector2(-6.7, 1.6), Vector2(6.8, -2.0), Vector2(-7.5, -8.5), Vector2(4.5, -10.6), Vector2(-15, -19), Vector2(12, -24)]:
		for i in 14:
			var point: Vector2 = center + Vector2(rng.randf_range(-1.1, 1.1), rng.randf_range(-0.65, 0.65))
			if Vector2(point).length() < 5.6 or _path_distance(point.x, point.y) < 1.8:
				continue
			_sized_asset(details, "flowers/" + ("aster_flower" if i % 4 == 0 else "trillium_flower"),
				Vector3(point.x, _height(point.x, point.y), point.y), Vector3.ONE * rng.randf_range(0.28, 0.50), rng.randf() * TAU)
	var shrubs := Node3D.new()
	shrubs.name = "ShrubBanks"
	parent.add_child(shrubs)
	for point in [Vector2(-7.1, 3.2), Vector2(8.0, -1.5), Vector2(-8.6, -5), Vector2(7, -10.8), Vector2(-15, -11), Vector2(-18, -24), Vector2(13, -24)]:
		for i in 3:
			var p: Vector2 = point + Vector2(i * 0.8, rng.randf_range(-0.3, 0.3))
			_sized_asset(shrubs, "shrubs/" + ("boxwood_shrub" if i % 2 else "juniper_shrub"),
				Vector3(p.x, _height(p.x, p.y) - 0.05, p.y), Vector3(1.25, rng.randf_range(0.6, 0.95), 1.2), rng.randf() * TAU)
	# Small stones mark the road edges while keeping the combatants' ground clear.
	for i in 55:
		var x := rng.randf_range(-30, 24)
		var z := rng.randf_range(-22, 14)
		if Vector2(x, z).length() < 6.2 or _path_distance(x, z) < 1.5 or _path_distance(x, z) > 3.5:
			continue
		var size := rng.randf_range(0.12, 0.40)
		_rock(details, Vector3(x, _height(x, z) - 0.03, z), Vector3(size, size * 0.7, size), i)
