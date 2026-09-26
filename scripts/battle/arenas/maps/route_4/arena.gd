extends "res://scripts/battle/arenas/shared/waterside_route.gd"
## Mt. Moon's eastern valley, with a river towards Cerulean and a timber crossing.
const Framing = preload("res://scripts/battle/arenas/shared/framing.gd")
const Landmarks = preload("res://scripts/battle/arenas/shared/route_landmarks.gd")
const RIVER := Vector2(54, -8)
const RADII := Vector2(42, 9)
const WATER_ORIGIN := Vector2(Framing.ROUTE_4_RIVER_ORIGIN.x, Framing.ROUTE_4_RIVER_ORIGIN.z)
const ROAD := [Vector2(-28, -32), Vector2(-28, -12), Vector2(-14, -10), Vector2(-10, 9), Vector2(15, 12), Vector2(43, 12), Vector2(64, 12), Vector2(64, -25), Vector2(92, -25)]
var rock_materials := {}

func _cache_key() -> String:
	return "route_4_water" if water_battle else "route_4"
func _grass_key() -> String:
	return "route_4"
func _grid_rect() -> Rect2i:
	return Rect2i(-75, -75, 196, 151)
func _grass_rect() -> Rect2i:
	return Rect2i(-5, -5, 15, 10)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, WATER_ORIGIN]

func build(_camera: Camera3D = null) -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 404262
	_start_scene("Route4RiverCrossing" if water_battle else "Route4MountainValley")
	route_scene.set_meta("source_map", "kanto_route_4")
	var scenery := Node3D.new()
	scenery.name = "Route4Scenery"
	route_scene.add_child(scenery)
	_ridges(scenery)
	_trees(scenery)
	_landmarks(scenery)
	_details(scenery)
	_pond(scenery, "CeruleanRiver", RIVER, RADII, water_battle)
	_grass(scenery)
	_finish_surface()
	return route_scene

func _height(x: float, z: float) -> float:
	var north := lerpf(4.2 * clampf((-z - 32) / 6.0, 0, 1),
		4.2 * smoothstep(35, 38, -z), smoothstep(2.3, 3.7, absf(x + 14)))
	north += 4.8 * smoothstep(47, 51, -z)
	var south := 3.5 * smoothstep(30, 34, z) + 4.0 * smoothstep(44, 49, z)
	var sides := 4.2 * smoothstep(35, 39, -x) + 5.5 * smoothstep(49, 55, -x)
	sides += 5.0 * smoothstep(103, 109, x)
	return BASE_HEIGHT + north + south + sides - _basin(Vector2(x, z), RIVER, RADII, water_battle)

func _path_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var distance := 100.0
	for i in ROAD.size() - 1:
		distance = minf(distance, _segment_distance(p, ROAD[i], ROAD[i + 1]))
	for line in [[Vector2(-14, -10), Vector2(-14, -41)], [Vector2(-28, -41), Vector2(73, -41)],
		[Vector2(-10, 9), Vector2(-22, 22)], [Vector2(-22, 22), Vector2(39, 22)]]:
		distance = minf(distance, _segment_distance(p, line[0], line[1]))
	return distance

func _dirt(x: float, z: float) -> float:
	var mountain := maxf(smoothstep(32, 39, -z), maxf(smoothstep(28, 36, z), smoothstep(31, 38, -x)))
	var clearing := 0.17 * (1 - smoothstep(3, 6, Vector2(x, z).length())) * (0.5 + 0.5 * sin(x * 1.2 + z))
	return maxf(maxf(mountain, clearing), 1 - smoothstep(1.3, 2.3, _path_distance(x, z)))

func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.length() < 6 or _path_distance(x, z) < 2.5 or ((p - RIVER) / RADII).length() < 1.24:
		return false
	if z < -33 or z > 30 or x < -33 or x > 102:
		return false
	for rect in [Rect2(-21, -6, 12, 12), Rect2(-6, -13, 14, 6), Rect2(-5, 12, 17, 7), Rect2(17, 16, 22, 9), Rect2(40, -29, 17, 7)]:
		if rect.has_point(p):
			return true
	return p.length() > 20 and sin(x * 0.47) + cos(z * 0.51) > 0.65

func _rock(parent: Node3D, p: Vector2, size: Vector3, index: int) -> void:
	var rock := _sized_asset(parent, "rocks/rock_object_" + ["a", "c", "e"][index % 3], _point(p) - Vector3.UP * 0.12, size, rng.randf() * TAU)
	_tint_rock(rock)

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("a88662"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _ridges(parent: Node3D) -> void:
	var rocks := Node3D.new()
	rocks.name = "MountainRidges"
	parent.add_child(rocks)
	_ledge(rocks, "NorthLowerLedge", -34.75, -38.1, 4.2, -14, 0, 115)
	_ledge(rocks, "NorthUpperLedge", -46.75, -51.1, 4.8, 1000, 0, 115)
	for spec in [[PI, -29.75, -34.1, 3.5], [PI, -43.75, -49.1, 4.0],
		[PI / 2, -34.75, -39.1, 4.2], [PI / 2, -48.75, -55.1, 5.5], [-PI / 2, -102.75, -109.1, 5.0]]:
		_ledge(rocks, "ValleyLedge%d" % rocks.get_child_count(), spec[1], spec[2], spec[3], 1000, spec[0], 115 if spec[0] == PI else 60)
	for i in 110:
		var p := Vector2(rng.randf_range(-58, 111), rng.randf_range(-60, 58))
		if p.y > -39 and p.y < 36 and p.x > -40 and p.x < 103:
			continue
		if _path_distance(p.x, p.y) < 3.5:
			continue
		var size := rng.randf_range(1.1, 3.8)
		_rock(rocks, p, Vector3(size, size * 0.8, size), i)
	# Irregular summits break the silhouette above the map's layered brown cliffs.
	for i in 24:
		var p := Vector2(-48 + i * 7, -57 if i % 2 else 54)
		_rock(rocks, p, Vector3(12, rng.randf_range(5, 9), 9), i)
		rocks.get_child(-1).position.y -= 2.8
	for p in [Vector2(-8, -5), Vector2(8, -8), Vector2(-19, 10), Vector2(9, 17), Vector2(44, 15)]:
		_rock(rocks, p, Vector3(1.4, 0.7, 1.1), rocks.get_child_count())

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "ValleyConifers"
	parent.add_child(trees)
	for row in [[-32.0, -25.0, 14, 0, 4.2], [-39.0, -27.0, 15, 0, 4.5],
		[-29.0, 27.0, 22, 4.5, 0], [-25.0, 34.0, 23, 4.5, 0],
		[-33.0, -32.0, 27, 4.5, 0], [-35.0, -43.0, 27, 4.8, 0],
		[99.0, -30.0, 15, 0, 4.5], [112.0, -30.0, 15, 0, 4.5], [83.0, 14.0, 5, 4.5, 0], [85.0, -26.0, 5, 4.5, 0]]:
		for i in int(row[2]):
			var p := Vector2(row[0] + i * row[3], row[1] + i * row[4])
			if _path_distance(p.x, p.y) < 4 or ((p - RIVER) / RADII).length() < 1.2 or p.distance_to(Vector2(-28, -32)) < 6:
				continue
			_plant_tree(trees, p, i)

func _landmarks(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "ValleyLandmarks"
	parent.add_child(props)
	var kit := Landmarks.new(route_scene)
	kit.cave(props, _point(Vector2(-28, -32)))
	kit.signpost(props, _point(Vector2(-24, -27)))
	kit.stairs(props, Vector3(-14, BASE_HEIGHT, -32), 4.2, "MountainStairs")
	kit.footbridge(props, Vector3(64, BASE_HEIGHT + 0.12, -8), 22)
	for segment in [[-20, -8, 22], [14, 28, 4], [41, 54, 4], [73, 83, 4]]:
		kit.fence(props, _point(Vector2(segment[0], segment[2])), segment[1] - segment[0])

func _details(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "ValleyDetails"
	parent.add_child(details)
	_plant_beds(details, [Vector2(-7, 4), Vector2(6, 7), Vector2(-8, -8), Vector2(8, -14), Vector2(-19, 16),
		Vector2(17, 5), Vector2(27, 18), Vector2(40, 7), Vector2(50, -23), Vector2(61, 7), Vector2(-21, -26)])
	for p in [Vector2(-23, 18), Vector2(48, 15)]:
		_detail(details, "log", _point(p), Vector3(3.6, 0.8, 1), -0.5)
	_detail(details, "stump", _point(Vector2(-22, -19)), Vector3(1.3, 0.8, 1.3))
	for p in [Vector2(44, -13), Vector2(47, -14), Vector2(54, -2)]:
		_detail(details, "lily", Vector3(p.x, BASE_HEIGHT + WATER_LEVEL + 0.035, p.y), Vector3(1.1, 0.15, 1.1), rng.randf() * TAU)
