extends "res://scripts/battle/arenas/shared/cerulean_region.gd"
## Cerulean's riverside park, southern Nugget Bridge approach and blue-roofed city.
const RIVER := Vector2(-16, -35)
const RADII := Vector2(54, 15)
const WATER_ORIGIN := Vector2(-24, -34)
const ROADS := [[Vector2(-32, 14), Vector2(36, 14)], [Vector2(-29, -11), Vector2(37, -11)],
	[Vector2(-16, -11), Vector2(-16, 36)], [Vector2(16, 36), Vector2(16, -60)]]
func _cache_key() -> String:
	return "cerulean_city_water" if water_battle else "cerulean_city"
func _grass_key() -> String:
	return "cerulean_city"
func _grid_rect() -> Rect2i:
	return Rect2i(-100, -100, 201, 191)
func _grass_rect() -> Rect2i:
	return Rect2i(-7, -7, 14, 14)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, WATER_ORIGIN]
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _wet(p: Vector2) -> bool:
	return ((p - RIVER) / RADII).length() < 1.2
func _height(x: float, z: float) -> float:
	var north := 5.0 * smoothstep(60, 65, -z) + 5.0 * smoothstep(75, 80, -z)
	var sides := 5.5 * smoothstep(56, 61, -x) + 5.0 * smoothstep(51, 56, x)
	var south := 4.0 * smoothstep(44, 49, z)
	return BASE_HEIGHT + north + sides + south - _basin(Vector2(x, z), RIVER, RADII, water_battle)
func _dirt(x: float, z: float) -> float:
	return maxf(1 - smoothstep(1.8, 2.6, _road(Vector2(x, z))), smoothstep(2, 4, _height(x, z) - BASE_HEIGHT))
func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return p.length() > 9 and not _wet(p) and _road(p) > 3.0 and (absf(x) > 40 or z < -52 or z > 37)
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 240925
	var scenery := _begin_region("CeruleanRiverfront", "cerulean_city")
	var mountains := _group(scenery, "MountainTerraces")
	_ledge(mountains, "CaveLowerCliff", -59.75, -65.1, 5, 1000, 0, 88)
	_ledge(mountains, "CaveUpperCliff", -74.75, -80.1, 5, 1000, 0, 88)
	_ledge(mountains, "WestCliff", -55.75, -61.1, 5.5, 1000, PI / 2, 85)
	_ledge(mountains, "EastCliff", -50.75, -56.1, 5, 1000, -PI / 2, 85)
	_ledge(mountains, "SouthCliff", -43.75, -49.1, 4, 1000, PI, 88)
	_mountain_peaks(mountains, [Vector2(-70, -80), Vector2(-54, -81), Vector2(-38, -81), Vector2(-21, -81), Vector2(0, -80), Vector2(30, -79), Vector2(58, -70), Vector2(-72, -50), Vector2(-73, -27), Vector2(64, 20), Vector2(-52, 57), Vector2(-20, 58), Vector2(20, 59), Vector2(54, 58)])
	_tree_rows(scenery, [[-47, 32, 22, 4.5, 0], [-54, 40, 25, 4.5, 0],
		[-51, -54, 23, 4.5, 0], [-62, -68, 28, 4.5, 0], [-48, -22, 14, 0, 4.4],
		[44, -35, 18, 0, 4.5], [51, -42, 20, 0, 4.5], [-72, -49, 20, 0, 4.5]], _wet, _road)
	var props := _group(scenery, "RegionLandmarks")
	kit.nugget_bridge(props, Vector3(16, BASE_HEIGHT + 0.12, -35), 36)
	kit.cave(props, _point(Vector2(-39, -60)))
	props.get_child(-1).name = "CeruleanCaveEntrance"
	kit.cottage(props, _point(Vector2(-29, 24)), "WestTownhouse", 0.0)
	kit.cottage(props, _point(Vector2(29, 24)), "EastTownhouse", PI)
	kit.cottage(props, _point(Vector2(32, -3)), "RiversideHouse", -PI / 2)
	kit.city_gym(props, _point(Vector2(-30, 0)), PI / 2)
	kit.pokemon_center(props, _point(Vector2(0, 30)))
	props.get_child(-1).rotation.y = PI
	for p in [Vector2(-31, 11), Vector2(-17, 19), Vector2(17, 19), Vector2(30, 11), Vector2(11, -13), Vector2(21, -13)]:
		kit.lamp(props, _point(p))
	for p in [Vector2(-11, 11), Vector2(11, 11)]:
		kit.bench(props, _point(p))
	for segment in [[-42, -6, -16], [22, 38, -16], [-40, -22, 17], [22, 40, 17]]:
		kit.fence(props, _point(Vector2(segment[0], segment[2])), segment[1] - segment[0])
	_rocks_and_flowers(scenery, [Vector2(-9, -7), Vector2(8, -8), Vector2(-9, 7), Vector2(9, 7), Vector2(-21, 18), Vector2(22, 18), Vector2(-32, -12), Vector2(30, -12)], [Vector2(-45, -55), Vector2(-32, -54), Vector2(30, -52)])
	_pond(scenery, "CeruleanRiver", RIVER, RADII, water_battle)
	_promenades(props)
	_grass(scenery)
	_finish_surface()
	return route_scene
func _promenades(parent: Node3D) -> void:
	var roads := _group(parent, "PavedPromenades")
	for line in ROADS:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		for i in int(a.distance_to(b) / 2):
			var p := a.move_toward(b, i * 2 + 1)
			if _wet(p):
				continue
			kit._box(roads, "paving", _point(p) - Vector3.UP * 0.025, Vector3(3.8 if a.x == b.x else 1.96, 0.1, 1.96 if a.x == b.x else 3.8))
