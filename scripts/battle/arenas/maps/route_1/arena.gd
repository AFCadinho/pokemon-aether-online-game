extends "res://scripts/battle/arenas/shared/wooded_route.gd"
## Map-specific Route 1 arena: a forest corridor across stepped grassy terraces.
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
const BASE_HEIGHT := 0.037750244140625
const POND_CENTER := Vector2(-13.5, -29.0)
const POND_RADII := Vector2(10.0, 5.5)
const POND_LEVEL := 2.72
const POND_FLOOR := POND_LEVEL - 0.18
var water_battle := false
var rock_materials: Dictionary = {}

func _cache_key() -> String:
	return "route_1"

func _grass_key() -> String:
	return "route_1"

func _grid_rect() -> Rect2i:
	return Rect2i(-80, -80, 161, 161)

func _grass_rect() -> Rect2i:
	return Rect2i(-5, -6, 10, 12)

func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, POND_CENTER]

func _wooded_banks(x: float, z: float) -> float:
	return (2.8 * smoothstep(34, 41, z) + 2.5 * smoothstep(48, 55, z)
		+ 2.5 * smoothstep(55, 64, -z) + 2.0 * smoothstep(35, 43, absf(x)))

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
	route_scene.set_meta("surface_height", POND_FLOOR if water_battle else ground_height)
	return route_scene

func _upper_terrace(z: float) -> float:
	return 3.0 * smoothstep(18.0, 21.0, -z)

func _lower_terrace(z: float) -> float:
	return -2.3 * smoothstep(18.0, 22.0, z)

func _pond_distance(x: float, z: float) -> float:
	return ((Vector2(x, z) - POND_CENTER) / POND_RADII).length()

func _height(x: float, z: float) -> float:
	var upper := _upper_terrace(z)
	# Continuous ramps support the stairs and meet both landings exactly.
	upper = lerpf(3.0 * clampf((-z - 17.0) / 6.0, 0.0, 1.0), upper,
		smoothstep(2.2, 3.5, absf(x - 8.5)))
	var lower := lerpf(-2.3 * clampf((z - 18.0) / 6.0, 0.0, 1.0), _lower_terrace(z),
		smoothstep(2.2, 3.5, absf(x + 10.5)))
	var height := BASE_HEIGHT + upper + lower + _wooded_banks(x, z)
	var basin := (BASE_HEIGHT + 3.0 - POND_FLOOR) * (1.0 - smoothstep(0.82, 1.12, _pond_distance(x, z)))
	return height - basin

func _main_path_x(z: float) -> float:
	var corridor := lerpf(8.5, -10.5, smoothstep(8.0, 17.0, z))
	corridor = lerpf(corridor, 22.0, smoothstep(36, 48, -z))
	return lerpf(corridor, 12.0, smoothstep(29, 43, z))

func _path_distance(x: float, z: float) -> float:
	var vertical := absf(x - _main_path_x(z)) if z > -56 and z < 50 else 100.0
	var upper_branch := absf(z + 12.0) if x < 7.0 and x > -25.0 else 100.0
	return minf(vertical, upper_branch)

func _dirt(x: float, z: float) -> float:
	return maxf(1.0 - smoothstep(1.5, 2.8, _path_distance(x, z)),
		1.0 - smoothstep(0.98, 1.15, _pond_distance(x, z)))

func _has_grass(x: float, z: float) -> bool:
	if Vector2(x, z).length() < 6 or _path_distance(x, z) < 2.7 or _pond_distance(x, z) < 1.18:
		return false
	if absf(z + 19.5) < 2.5 or absf(z - 19.5) < 2.5:
		return false
	# Rectangular plots and short-grass lanes follow the pixel map's forest route.
	for patch in [Rect2(-17, -9, 10, 14), Rect2(12, -10, 8, 17), Rect2(-6, -15, 10, 6),
		Rect2(-6, 8, 13, 7), Rect2(-25, 25, 9, 8), Rect2(-4, 28, 14, 9), Rect2(12, -34, 10, 10)]:
		if patch.has_point(Vector2(x, z)):
			return true
	return Vector2(x, z).length() > 23 and sin(x * 0.48) + cos(z * 0.41) > 0.3

func _cliff_terraces(parent: Node3D) -> void:
	var cliffs := Node3D.new()
	cliffs.name = "Route1RockTerraces"
	parent.add_child(cliffs)
	_ledge(cliffs, "NorthLedge", -17.75, -21.1, 3.0, 8.5)
	_ledge(cliffs, "SouthLedge", 22.25, 17.9, 2.3, -10.5)
	# Small boulders at the feet of the ledges, outside both stair passages.
	for z in [-16.5, 23.5]:
		for i in 13:
			var x := -37.0 + i * 6.0
			if absf(x - (8.5 if z < 0 else -10.5)) < 6.0:
				continue
			var rock := _sized_asset(cliffs, "rocks/rock_object_" + ["a", "c", "e"][i % 3],
				Vector3(x, _height(x, z) - 0.06, z), Vector3(1.4, 0.8, 1.1), rng.randf() * TAU)
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
	_build_stair(geo, landmarks, box, stone, timber, Vector3(8.5, BASE_HEIGHT, -17.0), 3.0, "NorthStair")
	_build_stair(geo, landmarks, box, stone, timber, Vector3(-10.5, BASE_HEIGHT - 2.3, 24.0), 2.3, "SouthStair")
	for segment in [[-27.0, -13.0, -11.2], [15.0, 27.0, -11.2], [-24.0, -13.0, 10.5],
		[-4.0, 7.0, 17.0], [-25.0, -17.0, 26.0], [-5.0, 7.0, 32.0]]:
		var start_x: float = segment[0]
		var end_x: float = segment[1]
		var z: float = segment[2]
		var length := end_x - start_x
		for y in [0.3, 0.65]:
			geo._put(landmarks, box, fence,
				Vector3((start_x + end_x) * 0.5, _height((start_x + end_x) * 0.5, z) + y, z),
				Vector3(length, 0.11, 0.12))
		for i in int(length / 1.5) + 1:
			var x := start_x + i * 1.5
			geo._put(landmarks, box, fence, Vector3(x, _height(x, z) + 0.45, z), Vector3(0.14, 0.9, 0.14))

func _build_stair(geo, parent: Node3D, box: BoxMesh, stone: Material, timber: Material,
	base: Vector3, rise: float, label: String) -> void:
	var stairs := Node3D.new()
	stairs.name = label
	parent.add_child(stairs)
	for i in 10:
		var height := (i + 1) * rise / 10.0
		var z := base.z - (i + 0.5) * 0.6
		var step: MeshInstance3D = geo._put(stairs, box, stone, Vector3(base.x, base.y + height * 0.5, z),
			Vector3(4.3, height, 0.6))
		step.name = "Step%d" % i
		for side in [-1, 1]:
			geo._put(stairs, box, timber,
				Vector3(base.x + side * 2.27, base.y + height + 0.14, z), Vector3(0.18, 0.28, 0.6))

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "Route1TreeCorridor"
	parent.add_child(trees)
	# Broad overlapping crowns form a forest on all sides of both battle origins.
	for side in [-1, 1]:
		for row in 3:
			for i in 24:
				var p := Vector2(side * (25.5 + row * 6.0) + rng.randf_range(-0.6, 0.6),
					-66.0 + i * 4.8 + rng.randf_range(-0.5, 0.5))
				_plant_tree(trees, p, i + row)
	for z in [-67.0, -61.0, -54.0, 34.0, 40.0, 47.0, 55.0, 61.0]:
		for i in 18:
			var x := -44.0 + i * 5.0
			if _path_distance(x, z) < 4.0:
				continue
			_plant_tree(trees, Vector2(x, z + rng.randf_range(-0.5, 0.5)), i)

func _flowers(parent: Node3D) -> void:
	var flowers := Node3D.new()
	flowers.name = "Route1Flowers"
	parent.add_child(flowers)
	_plant_beds(flowers, [Vector2(-7, -6), Vector2(5, -9), Vector2(-8, 5), Vector2(6, 7),
		Vector2(-17, 13), Vector2(14, 15), Vector2(-17, -14), Vector2(14, -15),
		Vector2(-5, 29), Vector2(-22, 30), Vector2(-25, -25), Vector2(-2, -28), Vector2(-15, -37)])

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
	material.set_shader_parameter("battle_shallows", true)
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
