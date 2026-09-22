extends "res://scripts/battle/arenas/shared/mesh_grassland.gd"
## Map-specific Route 1 arena: a forest corridor across stepped grassy terraces.
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
const BASE_HEIGHT := 0.037750244140625
const POND_CENTER := Vector2(-13.5, -26.0)
const POND_RADII := Vector2(10.0, 5.5)
const POND_LEVEL := 2.72
var rock_materials: Dictionary = {}

func _cache_key() -> String:
	return "route_1"

func _grass_key() -> String:
	return "route_1"

func build(_camera: Camera3D = null) -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 101075
	_start_scene("Route1ForestTerraces")
	route_scene.set_meta("source_map", "kanto_route_1")
	var scenery := Node3D.new()
	scenery.name = "Route1Scenery"
	route_scene.add_child(scenery)
	_cliff_terraces(scenery)
	_stairs_and_fences(scenery)
	_trees(scenery)
	_flowers(scenery)
	_pond(scenery)
	_grass(scenery)
	route_scene.set_meta("surface_height", ground_height)
	return route_scene

func _upper_terrace(z: float) -> float:
	return 3.0 * smoothstep(18.0, 21.0, -z)

func _lower_terrace(z: float) -> float:
	return -2.3 * smoothstep(18.0, 22.0, z)

func _pond_distance(x: float, z: float) -> float:
	return ((Vector2(x, z) - POND_CENTER) / POND_RADII).length()

func _height(x: float, z: float) -> float:
	var upper := _upper_terrace(z)
	# Cut the upper ledge under the authored stairs so the steps remain visible
	# instead of being swallowed by the smooth terrain transition.
	if z < -16.5 and z > -25.5:
		upper *= smoothstep(2.1, 3.0, absf(x - 8.5))
	var height := BASE_HEIGHT + upper + _lower_terrace(z)
	var basin := 1.15 * (1.0 - smoothstep(0.82, 1.12, _pond_distance(x, z)))
	return height - basin

func _main_path_x(z: float) -> float:
	return 7.0 + 3.2 * sin((z + 5.0) * 0.095) + (1.0 if z < -18.0 else 0.0)

func _path_distance(x: float, z: float) -> float:
	var vertical := absf(x - _main_path_x(z))
	var upper_branch := absf(z + 12.0) if x < 7.0 and x > -25.0 else 100.0
	return minf(vertical, upper_branch)

func _dirt(x: float, z: float) -> float:
	return maxf(1.0 - smoothstep(1.5, 2.8, _path_distance(x, z)),
		1.0 - smoothstep(0.98, 1.15, _pond_distance(x, z)))

func _has_grass(x: float, z: float) -> bool:
	return (Vector2(x, z).length() > 6.0
		and _path_distance(x, z) > 2.7
		and _pond_distance(x, z) > 1.18
		and not (absf(z + 19.5) < 2.5 and x > 4.0 and x < 13.0)
		and not (absf(z - 19.5) < 2.5 and x > -15.0 and x < -6.0))

func _cliff_terraces(parent: Node3D) -> void:
	var cliffs := Node3D.new()
	cliffs.name = "Route1RockTerraces"
	parent.add_child(cliffs)
	for row in 2:
		var z := -20.2 if row == 0 else 20.2
		var stair_x := 8.5 if row == 0 else -10.5
		for i in 24:
			var x := -44.0 + i * 3.9
			if absf(x - stair_x) < 3.8:
				continue
			var rock := _asset(cliffs, "rocks/rock_object_" + ["a", "c", "e"][i % 3],
				Vector3.ZERO, Vector3.ONE)
			var boxes: Array = []
			_bounds(rock, Transform3D.IDENTITY, boxes)
			var bounds: AABB = boxes[0]
			for box: AABB in boxes:
				bounds = bounds.merge(box)
			rock.scale = Vector3(4.3, 2.15, 3.3) / bounds.size
			var ledge_y := BASE_HEIGHT + (1.05 if row == 0 else -1.15)
			rock.position = Vector3(x, ledge_y - bounds.position.y * rock.scale.y,
				z + rng.randf_range(-0.25, 0.25))
			rock.rotation.y = rng.randf_range(-0.18, 0.18)
			_tint_rock(rock)

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("9b7657"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2.0)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _stairs_and_fences(parent: Node3D) -> void:
	var landmarks := Node3D.new()
	landmarks.name = "Route1Landmarks"
	parent.add_child(landmarks)
	var geo := Geometry.new(route_scene)
	var box := BoxMesh.new()
	var stone := geo._stone(Color("aaa393"))
	var timber := geo._stone(Color("79543a"))
	var fence := geo._stone(Color("d1d4bb"))
	_build_stair(geo, landmarks, box, stone, timber, Vector3(8.5, BASE_HEIGHT, -18.2), -1.0)
	_build_stair(geo, landmarks, box, stone, timber, Vector3(-10.5, BASE_HEIGHT, 18.2), 1.0)
	for segment in [[-27.0, -13.0, -11.2], [15.0, 27.0, -11.2], [-24.0, -13.0, 10.5]]:
		var start_x: float = segment[0]
		var end_x: float = segment[1]
		var z: float = segment[2]
		var length := end_x - start_x
		geo._put(landmarks, box, fence,
			Vector3((start_x + end_x) * 0.5, _height((start_x + end_x) * 0.5, z) + 0.26, z),
			Vector3(length, 0.09, 0.09))
		for x in range(ceili(start_x), floori(end_x) + 1, 3):
			geo._put(landmarks, box, fence, Vector3(x, _height(x, z) + 0.35, z), Vector3(0.10, 0.7, 0.10))

func _build_stair(geo, parent: Node3D, box: BoxMesh, stone: Material, timber: Material,
	base: Vector3, direction: float) -> void:
	for i in 10:
		var height := (i + 1) * 0.30
		var z := base.z + direction * i * 0.62
		geo._put(parent, box, stone, Vector3(base.x, base.y + height * 0.5, z),
			Vector3(4.3, height, 0.64))
		for side in [-1, 1]:
			geo._put(parent, box, timber,
				Vector3(base.x + side * 2.27, base.y + height + 0.14, z), Vector3(0.18, 0.28, 0.64))

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "Route1TreeCorridor"
	parent.add_child(trees)
	for side in [-1, 1]:
		for row in 2:
			for i in 13:
				var z: float = -38.0 + i * 6.2 + rng.randf_range(-0.8, 0.8)
				var x: float = side * (15.5 + row * 7.0) + rng.randf_range(-1.0, 1.0)
				if _pond_distance(x, z) < 1.25:
					x += side * 8.0
				var size := rng.randf_range(0.28, 0.39)
				var tree := _asset(trees, "trees/" + ["fir_tree_a", "spruce_tree_b", "fir_tree_c"][i % 3],
					Vector3(x, _height(x, z), z), Vector3.ONE * size, rng.randf() * TAU)
				if _shades_battle(tree):
					tree.position.x += side * 6.0
	for i in 16:
		var x: float = -42.0 + i * 5.5
		for z in [-42.0, 39.0]:
			_asset(trees, "trees/fir_tree_b", Vector3(x, _height(x, z), z),
				Vector3.ONE * rng.randf_range(0.25, 0.34), rng.randf() * TAU)

func _flowers(parent: Node3D) -> void:
	var flowers := Node3D.new()
	flowers.name = "Route1Flowers"
	parent.add_child(flowers)
	for center in [Vector2(-8, -9), Vector2(11, -12), Vector2(-11, 11), Vector2(9, 12), Vector2(-26, -25)]:
		for i in 12:
			var point: Vector2 = center + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.8, 0.8))
			if _pond_distance(point.x, point.y) < 1.15:
				continue
			_asset(flowers, "flowers/" + ("lupine_flower" if i % 3 else "anemone_flower"),
				Vector3(point.x, _height(point.x, point.y), point.y),
				Vector3.ONE * rng.randf_range(0.65, 0.95), rng.randf() * TAU)

func _pond(parent: Node3D) -> void:
	var pond := Node3D.new()
	pond.name = "NorthernPond"
	parent.add_child(pond)
	var plane := PlaneMesh.new()
	plane.size = POND_RADII * 2.45
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/maps/route_1/water.gdshader")
	material.set_shader_parameter("pond_center", POND_CENTER)
	material.set_shader_parameter("pond_radii", POND_RADII)
	var geo := Geometry.new(route_scene)
	var surface: MeshInstance3D = geo._put(pond, plane, material,
		Vector3(POND_CENTER.x, POND_LEVEL, POND_CENTER.y), Vector3.ONE)
	surface.name = "WaterSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 20:
		var angle := TAU * i / 20.0
		var point := POND_CENTER + Vector2(cos(angle), sin(angle)) * POND_RADII * 1.12
		var rock := _asset(pond, "rocks/rock_object_a",
			Vector3(point.x, _height(point.x, point.y) - 0.04, point.y),
			Vector3(0.42, 0.28, 0.38) * rng.randf_range(0.75, 1.25), angle)
		_tint_rock(rock)
