extends "res://scripts/battle/arenas/shared/waterside_route.gd"
## Woodland between Viridian and Pewter: gates, blue cottage, Diglett's Cave.
const Framing = preload("res://scripts/battle/arenas/shared/framing.gd")
const Landmarks = preload("res://scripts/battle/arenas/shared/route_landmarks.gd")
const POND := Vector2(Framing.ROUTE_2_POND_ORIGIN.x, Framing.ROUTE_2_POND_ORIGIN.z)
const RADII := Vector2(6, 8)
const SOUTH_POND := Vector2(-17, 24)
const SOUTH_RADII := Vector2(5, 3.5)
const ROAD := [Vector2(-10, 57), Vector2(-8, 34), Vector2(9, 21), Vector2(9, 8), Vector2(6, -14), Vector2(-8, -14), Vector2(-8, -38), Vector2(9, -54)]

func _cache_key() -> String:
	return "route_2_water" if water_battle else "route_2"
func _grass_key() -> String:
	return "route_2"
func _grid_rect() -> Rect2i:
	return Rect2i(-75, -75, 151, 151)
func _grass_rect() -> Rect2i:
	return Rect2i(-5, -5, 11, 10)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, POND]

func build(_camera: Camera3D = null) -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 202607
	_start_scene("Route2WoodlandPond" if water_battle else "Route2ForestCorridor")
	route_scene.set_meta("source_map", "kanto_route_2")
	var scenery := Node3D.new()
	scenery.name = "Route2Scenery"
	route_scene.add_child(scenery)
	_terraces(scenery)
	_trees(scenery)
	_landmarks(scenery)
	_details(scenery)
	_pond(scenery, "WoodlandPond", POND, RADII, water_battle)
	_pond(scenery, "SouthernPond", SOUTH_POND, SOUTH_RADII, false)
	_grass(scenery)
	_finish_surface()
	return route_scene

func _height(x: float, z: float) -> float:
	var north := lerpf(3.0 * clampf((-z - 28) / 6.0, 0, 1),
		3.0 * smoothstep(31, 34, -z), smoothstep(2.3, 3.7, absf(x + 8)))
	var banks := 2.4 * smoothstep(34, 38, z) + 2.5 * smoothstep(36, 41, -x) + 2.5 * smoothstep(47, 52, x)
	banks += 2.4 * smoothstep(48, 55, absf(z))
	return BASE_HEIGHT + north + banks - _basin(Vector2(x, z), POND, RADII, water_battle) - _basin(Vector2(x, z), SOUTH_POND, SOUTH_RADII, false)

func _path_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var distance := 100.0
	for i in ROAD.size() - 1:
		distance = minf(distance, _segment_distance(p, ROAD[i], ROAD[i + 1]))
	for line in [[Vector2(-31, 2), Vector2(-1, 2)], [Vector2(-18, -25), Vector2(-8, -25)],
		[Vector2(-8, -37), Vector2(0, -37)], [Vector2(9, 21), Vector2(29, 21)], [Vector2(29, 21), Vector2(29, -18)]]:
		distance = minf(distance, _segment_distance(p, line[0], line[1]))
	return distance

func _dirt(x: float, z: float) -> float:
	return maxf(1 - smoothstep(1.2, 2.1, _path_distance(x, z)), 0.75 * (1 - smoothstep(1, 1.16, ((Vector2(x, z) - POND) / RADII).length())))

func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.length() < 6 or _path_distance(x, z) < 2.4 or ((p - POND) / RADII).length() < 1.23 or ((p - SOUTH_POND) / SOUTH_RADII).length() < 1.2:
		return false
	if (p - Vector2(-18, -25)).length() < 5 or absf(z + 32) < 2:
		return false
	for rect in [Rect2(-18, -13, 10, 10), Rect2(-15, 7, 9, 11), Rect2(8, 6, 15, 9), Rect2(28, -21, 10, 17), Rect2(-31, 12, 9, 8)]:
		if rect.has_point(p):
			return true
	return p.length() > 28 and sin(x * 0.43) + cos(z * 0.39) > 0.35

func _terraces(parent: Node3D) -> void:
	var terraces := Node3D.new()
	terraces.name = "WoodlandTerraces"
	parent.add_child(terraces)
	_ledge(terraces, "CaveTerrace", -30.75, -34.1, 3, -8)
	_ledge(terraces, "SouthBank", -33.75, -38.1, 2.4, 1000, PI)
	_ledge(terraces, "WestBank", -35.75, -41.1, 2.5, 1000, PI / 2)
	_ledge(terraces, "EastBank", -46.75, -52.1, 2.5, 1000, -PI / 2)

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "WoodlandConifers"
	parent.add_child(trees)
	for row in 3:
		for i in 36:
			var angle := TAU * i / 36.0 + row * 0.045
			var p := Vector2(sin(angle), cos(angle)) * (28.0 + row * 7)
			if _path_distance(p.x, p.y) < 3.8 or p.distance_to(Vector2(-18, -25)) < 5 or p.distance_to(Vector2(0, -37)) < 6 or p.distance_to(Vector2(-29, 2)) < 5:
				continue
			_plant_tree(trees, p, i)
	# A second forest wall encloses the offset pond viewpoint.
	for x in [41.0, 47.0, 54.0]:
		for i in 16:
			_plant_tree(trees, Vector2(x, -48 + i * 5), i)
	for z in [-54.0, 52.0]:
		for i in 20:
			var p := Vector2(-48 + i * 5, z)
			if _path_distance(p.x, p.y) > 3.8:
				_plant_tree(trees, p, i)

func _landmarks(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "WoodlandLandmarks"
	parent.add_child(props)
	var kit := Landmarks.new(route_scene)
	kit.house(props, _point(Vector2(-18, -25)))
	kit.forest_gate(props, _point(Vector2(-29, 2)), PI / 2)
	kit.cave(props, _point(Vector2(0, -37)))
	props.get_node("MtMoonEntrance").name = "DiglettCaveEntrance"
	kit.stairs(props, Vector3(-8, BASE_HEIGHT, -28), 3, "CaveStairs")
	kit.signpost(props, _point(Vector2(-3.5, -35)))
	for segment in [[-21, -12, -17], [-19, -9, 19], [25, 33, 16], [-5, 4, 28]]:
		kit.fence(props, _point(Vector2(segment[0], segment[2])), segment[1] - segment[0])

func _details(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "WoodlandDetails"
	parent.add_child(details)
	_plant_beds(details, [Vector2(-7, -6), Vector2(5, 6), Vector2(-7, 6), Vector2(-20, 12), Vector2(-23, -19),
		Vector2(25, -19), Vector2(27, 9), Vector2(-12, 29), Vector2(6, -22), Vector2(22, 18)])
	for p in [Vector2(-19, 15), Vector2(25, 13), Vector2(-25, -14)]:
		_detail(details, "log", _point(p), Vector3(3.5, 0.8, 1), 0.4)
		_detail(details, "mushrooms", _point(p + Vector2(1, 1)), Vector3(0.9, 0.55, 0.7))
	_detail(details, "stump", _point(Vector2(-21, 10)), Vector3(1.4, 0.9, 1.2))
	for p in [Vector2(19, -13), Vector2(19.5, -10), Vector2(12, -13), Vector2(-18, 25)]:
		_detail(details, "lily", Vector3(p.x, BASE_HEIGHT + WATER_LEVEL + 0.035, p.y), Vector3(0.8, 0.15, 0.8), rng.randf() * TAU)
