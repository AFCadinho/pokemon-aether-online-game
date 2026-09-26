extends "res://scripts/battle/arenas/shared/cerulean_region.gd"
## Northern Nugget Bridge landing between the river, grass banks and mountain steps.
const RIVER := Vector2(0, 44)
const RADII := Vector2(66, 19)
const WATER_ORIGIN := Vector2(32, 43)
const ROADS := [[Vector2(0, 98), Vector2(0, -15)], [Vector2(-21, -15), Vector2(53, -15)],
	[Vector2(-21, -15), Vector2(-21, -38)], [Vector2(47, -15), Vector2(47, 14)],
	[Vector2(-34, 68), Vector2(34, 68)], [Vector2(-34, 85), Vector2(34, 85)]]
func _cache_key() -> String:
	return "route_24_water" if water_battle else "route_24"
func _grass_key() -> String:
	return "route_24"
func _grid_rect() -> Rect2i:
	return Rect2i(-100, -85, 211, 201)
func _grass_rect() -> Rect2i:
	return Rect2i(-7, -6, 16, 15)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, WATER_ORIGIN]
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _city_footprint(p: Vector2) -> bool:
	return Rect2(-39, 64, 78, 35).has_point(p)
func _tree_clearance(p: Vector2) -> float:
	return 0.0 if _city_footprint(p) else _road(p)
func _wet(p: Vector2) -> bool:
	return ((p - RIVER) / RADII).length() < 1.2
func _height(x: float, z: float) -> float:
	var north := lerpf(4.5 * clampf((-z - 30) / 6.0, 0, 1), 4.5 * smoothstep(31, 36, -z), smoothstep(2.3, 3.7, absf(x + 21)))
	north += 5.5 * smoothstep(48, 54, -z)
	var west := 5.5 * smoothstep(36, 42, -x) + 4.0 * smoothstep(55, 60, -x)
	var east := 5.0 * smoothstep(72, 78, x)
	var south := lerpf(4.0 * clampf((z - 78) / 6.0, 0, 1), 4.0 * smoothstep(78, 84, z), smoothstep(2.3, 3.7, absf(x)))
	return BASE_HEIGHT + north + west + east + south - _basin(Vector2(x, z), RIVER, RADII, water_battle)
func _dirt(x: float, z: float) -> float:
	return maxf(1 - smoothstep(1.5, 2.5, _road(Vector2(x, z))), smoothstep(2, 4, _height(x, z) - BASE_HEIGHT))
func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if _city_footprint(p) or p.length() < 7 or _wet(p) or _road(p) < 3 or _height(x, z) > BASE_HEIGHT + 1:
		return false
	return Rect2(-25, -8, 17, 22).has_point(p) or Rect2(8, -25, 28, 11).has_point(p) or Rect2(42, 2, 20, 19).has_point(p) or p.length() > 30
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 242526
	var scenery := _begin_region("NuggetBridgeNorth", "route_24")
	var mountains := _group(scenery, "MountainTerraces")
	_ledge(mountains, "NorthLowerCliff", -30.75, -36.1, 4.5, -21, 0, 100)
	_ledge(mountains, "NorthUpperCliff", -47.75, -54.1, 5.5, 1000, 0, 100)
	_ledge(mountains, "WestLowerCliff", -35.75, -42.1, 5.5, 1000, PI / 2, 100)
	_ledge(mountains, "WestUpperCliff", -54.75, -60.1, 4, 1000, PI / 2, 100)
	_ledge(mountains, "EastCliff", -71.75, -78.1, 5, 1000, -PI / 2, 100)
	_ledge(mountains, "SouthCliff", -77.75, -84.1, 4, 0, PI, 100)
	_mountain_peaks(mountains, [Vector2(-49, -65), Vector2(-31, -65), Vector2(-13, -66), Vector2(6, -65), Vector2(27, -64), Vector2(50, -63), Vector2(81, -43), Vector2(84, -19), Vector2(85, 8), Vector2(86, 42), Vector2(-70, -20), Vector2(-71, 9), Vector2(-70, 39), Vector2(-65, 81), Vector2(74, 89)])
	_tree_rows(scenery, [[-30, -28, 22, 4.4, 0], [-36, -43, 27, 4.5, 0], [-29, -25, 12, 0, 4],
		[61, -22, 22, 0, 4.5], [73, -25, 22, 0, 4.5], [85, -25, 28, 0, 4.5], [-84, -25, 28, 0, 4.5], [-45, 71, 29, 4.5, 0],
		[-52, 79, 32, 4.5, 0], [-65, 8, 18, 0, 4.5], [-87, 100, 40, 4.5, 0], [-36, 107, 17, 4.5, 0]], _wet, _tree_clearance)
	var props := _group(scenery, "RegionLandmarks")
	kit.nugget_bridge(props, Vector3(0, BASE_HEIGHT + 0.12, 44), 42)
	_city_view(props)
	kit.stairs(props, Vector3(-21, BASE_HEIGHT, -30), 4.5, "MountainStairs")
	kit.signpost(props, _point(Vector2(8, 17)))
	props.get_child(-1).name = "NuggetBridgeSign"
	for spec in [[-26, -8, 16], [9, 28, -11], [40, 59, 18]]:
		kit.fence(props, _point(Vector2(spec[0], spec[2])), spec[1] - spec[0])
	_rocks_and_flowers(scenery, [Vector2(-8, 5), Vector2(8, -7), Vector2(-9, -10), Vector2(8, 12), Vector2(28, -10), Vector2(-26, 19), Vector2(44, 17), Vector2(52, 70)], [Vector2(-28, 14), Vector2(11, 18), Vector2(38, -22), Vector2(54, 18), Vector2(57, 69)])
	_detail(scenery, "log", _point(Vector2(-26, -18)), Vector3(3.4, 0.8, 1), 0.4)
	_detail(scenery, "mushrooms", _point(Vector2(-27, -16)), Vector3(0.8, 0.45, 0.7))
	_pond(scenery, "NuggetRiver", RIVER, RADII, water_battle)
	_grass(scenery)
	_finish_surface()
	return route_scene

func _city_view(parent: Node3D) -> void:
	# The far bridge landing continues into Cerulean's blue-roofed riverfront.
	var city := _group(parent, "CeruleanCityView")
	for x in [-14, 14]:
		kit.cottage(city, _point(Vector2(x, 74)), "RiverfrontHouseWest" if x < 0 else "RiverfrontHouseEast", PI)
		city.get_child(-1).scale = Vector3.ONE * 1.5
	for x in [-28, 28]:
		kit.cottage(city, _point(Vector2(x, 90)), "UpperHouseWest" if x < 0 else "UpperHouseEast", PI)
		city.get_child(-1).scale = Vector3.ONE * 1.3
	kit.pokemon_center(city, _point(Vector2(-11, 90)))
	city.get_child(-1).rotation.y = PI
	city.get_child(-1).scale = Vector3.ONE * 1.6
	kit.city_gym(city, _point(Vector2(11, 90)), PI)
	city.get_child(-1).scale = Vector3.ONE * 1.5
	kit.stairs(city, Vector3(0, BASE_HEIGHT, 78), 4.0, "CityApproachStairs")
	city.get_child(-1).rotation.y = PI
	var paving := _group(city, "RiverfrontPromenade")
	for z in [68, 85]:
		for x in range(-34, 34, 2):
			kit._box(paving, "paving", _point(Vector2(x + 1, z)) - Vector3.UP * 0.025, Vector3(1.96, 0.1, 3.8))
	for z in range(65, 99, 2):
		if z >= 77 and z < 85:
			continue
		kit._box(paving, "paving", _point(Vector2(0, z)) - Vector3.UP * 0.015, Vector3(4.2, 0.1, 1.96))
	for x in [-32, -22, -5, 5, 22, 32]:
		kit.lamp(city, _point(Vector2(x, 66)))
	for x in [-34, 6]:
		kit.fence(city, _point(Vector2(x, 65)), 28)
	_plant_beds(city, [Vector2(-24, 71), Vector2(24, 71), Vector2(-6, 73), Vector2(6, 73)])
