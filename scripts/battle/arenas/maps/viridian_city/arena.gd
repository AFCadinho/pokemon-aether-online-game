extends "res://scripts/battle/arenas/shared/kanto_town.gd"
## Green-roofed garden city with Gym terrace, trainer school, Center and southwest pond.
const EV_FIELD := Rect2(-38, -22, 9, 28)
const POND := Vector2(-32, 27)
const RADII := Vector2(16, 15)
const ROADS := [[Vector2(0, -48), Vector2(0, 43)], [Vector2(-46, 12), Vector2(38, 12)],
	[Vector2(-26, -18), Vector2(35, -18)], [Vector2(18, -18), Vector2(18, -34)], [Vector2(35, -18), Vector2(35, 30)]]
func _cache_key() -> String:
	return "viridian_city_water" if water_battle else "viridian_city"
func _grass_key() -> String:
	return "viridian_city"
func _grid_rect() -> Rect2i:
	return Rect2i(-105, -95, 211, 201)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, POND]
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _wet(p: Vector2) -> bool:
	return ((p - POND) / RADII).length() < 1.2
func _height(x: float, z: float) -> float:
	return BASE_HEIGHT + 3 * smoothstep(25, 31, -z) + 4.5 * smoothstep(48, 54, -z) + 6 * smoothstep(61, 67, -x) + 4 * smoothstep(53, 59, x) + 3 * smoothstep(57, 63, z) - _basin(Vector2(x, z), POND, RADII, water_battle)
func _dirt(x: float, z: float) -> float:
	return maxf(1 - smoothstep(2.1, 3.0, _road(Vector2(x, z))), smoothstep(4, 6, _height(x, z) - BASE_HEIGHT))
func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if EV_FIELD.has_point(p):
		return true
	return p.length() > 9 and not _wet(p) and _road(p) > 3.6 and (absf(x) > 39 or z < -42 or z > 36)
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 2609272
	var scenery := _begin_town("ViridianGardenCity", "viridian_city", true)
	var terraces := _group(scenery, "TownTerraces")
	_ledge(terraces, "GymTerrace", -24.75, -31.1, 3, 18, 0, 48)
	_ledge(terraces, "NorthRidge", -47.75, -54.1, 4.5, 0, 0, 90)
	_ledge(terraces, "WestMountains", -60.75, -67.1, 6, 1000, PI / 2, 90)
	_ledge(terraces, "EastRidge", -52.75, -59.1, 4, 1000, -PI / 2, 90)
	_ledge(terraces, "SouthRidge", -56.75, -63.1, 3, 0, PI, 90)
	_mountain_peaks(terraces, [Vector2(-76, -48), Vector2(-76, -25), Vector2(-75, 0), Vector2(-76, 25), Vector2(-76, 48)])
	_tree_rows(scenery, [[-60, -43, 27, 4.5, 0], [-67, -62, 31, 4.5, 0], [-60, -33, 22, 0, 4.5], [-70, -44, 25, 0, 4.5], [47, -37, 24, 0, 4.5], [57, -48, 28, 0, 4.5], [-61, 53, 26, 4.5, 0], [-66, 67, 29, 4.5, 0]], _wet, _road)
	var close_trees: Node3D = scenery.get_node("RegionConifers")
	for p in [Vector2(-13, -31), Vector2(31, 1), Vector2(34, 5), Vector2(14, 32), Vector2(10, 35), Vector2(-8, 36)]:
		_plant_tree(close_trees, p, int(absf(p.x)))
	_plant_beds(scenery, [Vector2(-15, -11), Vector2(-16, -7), Vector2(20, 3), Vector2(23, 3), Vector2(8, 21), Vector2(10, 24)])
	var props := _group(scenery, "RegionLandmarks")
	kit.ev_training_field(props, Vector3(-33.5, BASE_HEIGHT, -8))
	route_scene.set_meta("ev_training_field", EV_FIELD)
	kit.gym(props, _point(Vector2(18, -36)), "ViridianGym")
	kit.stairs(props, _point(Vector2(18, -25)), 3, "GymTerraceStairs")
	kit.school(props, _point(Vector2(31, -9)), -PI / 2)
	kit.town_house(props, _point(Vector2(-20, -36)), "WestGreenHouse", Color("788c42"))
	kit.town_house(props, _point(Vector2(-5, -36)), "NorthGreenHouse", Color("788c42"))
	_center(props, Vector2(24, 23), PI)
	_town_lamps(props, [Vector2(-5, -15), Vector2(5, -15), Vector2(-13, 9), Vector2(13, 9), Vector2(30, 17), Vector2(5, 27), Vector2(-21, -23)])
	for row in [[-26, -14, -31], [9, 30, -23], [19, 33, 31], [-53, -47, 6]]:
		kit.fence(props, _point(Vector2(row[0], row[2])), row[1] - row[0])
	kit.bench(props, _point(Vector2(-20, 8)), PI)
	kit.bench(props, _point(Vector2(13, 24)), -PI / 2)
	_flower_planters(props, [Vector2(-9, -7), Vector2(9, -8), Vector2(-9, 6), Vector2(10, 7), Vector2(-26, -13), Vector2(25, -23), Vector2(30, 30), Vector2(-51, 5)])
	_rocks_and_flowers(scenery, [Vector2(-9, -7), Vector2(9, -8), Vector2(-9, 6), Vector2(10, 7), Vector2(-26, -13), Vector2(25, -23), Vector2(30, 30), Vector2(-51, 5)], [Vector2(-51, 16), Vector2(-18, 38), Vector2(40, -1)])
	_pond(scenery, "ViridianPond", POND, RADII, water_battle)
	for p in [Vector2(-40, 20), Vector2(-40, 35), Vector2(-22, 34)]:
		_detail(scenery, "lily", Vector3(p.x, BASE_HEIGHT + WATER_LEVEL + 0.025, p.y), Vector3(0.8, 0.15, 0.8))
	_grass(scenery)
	_finish_surface()
	return route_scene
