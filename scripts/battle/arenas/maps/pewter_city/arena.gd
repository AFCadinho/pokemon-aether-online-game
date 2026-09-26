extends "res://scripts/battle/arenas/shared/kanto_town.gd"
## Rocky town plaza: clock-front museum, fountain, Gym terrace and excavation garden.
const ROADS := [[Vector2(0, -43), Vector2(0, 44)], [Vector2(-38, 12), Vector2(42, 12)],
	[Vector2(-30, -24), Vector2(34, -24)], [Vector2(18, -24), Vector2(18, 28)]]
func _cache_key() -> String:
	return "pewter_city"
func _grid_rect() -> Rect2i:
	return Rect2i(-90, -90, 181, 181)
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _wet(_p: Vector2) -> bool:
	return false
func _height(x: float, z: float) -> float:
	var quarry := (1 - smoothstep(4, 6, absf(x + 31))) * (1 - smoothstep(6, 8, absf(z + 2)))
	return BASE_HEIGHT + 3.2 * smoothstep(26, 32, -z) + 5 * smoothstep(43, 49, -z) + 6 * smoothstep(43, 49, -x) + 5 * smoothstep(47, 53, x) + 3 * smoothstep(47, 53, z) - quarry * 0.8
func _dirt(x: float, z: float) -> float:
	return maxf(1 - smoothstep(19, 24, Vector2(x, z).length()), maxf(1 - smoothstep(2.1, 3.1, _road(Vector2(x, z))), smoothstep(2, 4, _height(x, z) - BASE_HEIGHT)))
func _has_grass(x: float, z: float) -> bool:
	return Vector2(x, z).length() > 25 and _road(Vector2(x, z)) > 3.5 and (absf(x) > 38 or z > 35 or z < -43)
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 2609273
	var scenery := _begin_town("PewterMuseumPlaza", "pewter_city", true)
	var terraces := _group(scenery, "TownTerraces")
	_ledge(terraces, "MuseumTerrace", -25.75, -32.1, 3.2, 0, 0, 43)
	_ledge(terraces, "NorthMountains", -42.75, -49.1, 5, 1000, 0, 80)
	_ledge(terraces, "WestMountains", -42.75, -49.1, 6, 1000, PI / 2, 80)
	_ledge(terraces, "EastMountains", -46.75, -53.1, 5, 12, -PI / 2, 80)
	_ledge(terraces, "SouthernBank", -46.75, -53.1, 3, 0, PI, 80)
	_mountain_peaks(terraces, [Vector2(-58, -56), Vector2(-38, -56), Vector2(-17, -55), Vector2(5, -56), Vector2(28, -55), Vector2(53, -56), Vector2(-57, -34), Vector2(-57, -12), Vector2(-56, 10), Vector2(-57, 32), Vector2(61, -33), Vector2(61, -12), Vector2(60, 30)])
	_tree_rows(scenery, [[-41, 36, 20, 4.5, 0], [-48, 45, 24, 4.5, 0], [-48, 60, 24, 4.5, 0], [-37, -46, 19, 4.5, 0], [-39, -35, 15, 0, 4.5], [42, -36, 16, 0, 4.5]], _wet, _road)
	var props := _group(scenery, "RegionLandmarks")
	kit.museum(props, _point(Vector2(24, -35)))
	kit.gym(props, _point(Vector2(-23, -35)), "PewterGym")
	kit.stairs(props, _point(Vector2(0, -26)), 3.2, "MuseumTerraceStairs")
	kit.fountain(props, _point(Vector2(0, -22)))
	kit.town_house(props, _point(Vector2(30, -9)), "EastBlueHouse", Color("328fcb"), -PI / 2)
	kit.town_house(props, _point(Vector2(-26, 24)), "WestBlueHouse", Color("328fcb"), PI / 2)
	_center(props, Vector2(26, 23), PI)
	kit.plaza_tree(props, _point(Vector2(0, 30)))
	_town_lamps(props, [Vector2(-11, -21), Vector2(11, -21), Vector2(-15, 10), Vector2(15, 10), Vector2(-7, 27), Vector2(7, 27), Vector2(37, -27)])
	kit.bench(props, _point(Vector2(-8, 29)), PI / 2)
	kit.bench(props, _point(Vector2(8, 29)), -PI / 2)
	var dig := _group(props, "ExcavationGarden")
	for p in [Vector2(-33, -5), Vector2(-29, 1), Vector2(-33, 5)]:
		kit.geo._put(dig, kit.geo._rock_mesh(int(p.y) + 510), rock_material, _point(p), Vector3(1.5, 1.2, 1.3))
	for z in [-11, 8]:
		kit.fence(dig, _point(Vector2(-37, z)), 12)
	kit._box(dig, "timber", _point(Vector2(-35, -7)) + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.4))
	kit._box(dig, "timber", _point(Vector2(-28, 4)) + Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 1.0))
	_flower_planters(props, [Vector2(-10, -8), Vector2(10, -8), Vector2(-10, 7), Vector2(10, 7), Vector2(-3, 28), Vector2(3, 28), Vector2(34, -5)])
	_rocks_and_flowers(scenery, [Vector2(-10, -8), Vector2(10, -8), Vector2(-10, 7), Vector2(10, 7), Vector2(-3, 28), Vector2(3, 28), Vector2(34, -5)], [Vector2(-22, -10), Vector2(38, 26), Vector2(-38, 25)])
	_grass(scenery)
	_finish_surface()
	return route_scene
