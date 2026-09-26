extends "res://scripts/battle/arenas/shared/kanto_town.gd"
## Compact Pallet pixel map: teal homes, orange Oak lab, forest terraces and the open ocean toward Cinnabar.
const WATER_ORIGIN := Vector2(-32, 29)
const ROADS := [[Vector2(-24, -14), Vector2(22, -14)], [Vector2(8, -48), Vector2(8, 28)],
	[Vector2(8, 22), Vector2(30, 22)], [Vector2(-24, -14), Vector2(-24, 3)]]
func _cache_key() -> String:
	return "pallet_town_water" if water_battle else "pallet_town"
func _grass_key() -> String:
	return "pallet_town"
func _grid_rect() -> Rect2i:
	return Rect2i(-100, -90, 201, 201)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, WATER_ORIGIN]
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _coast(p: Vector2) -> float:
	return p.y - p.x - 30.0 + 2.0 * sin(p.x * 0.10)
func _wet(p: Vector2) -> bool:
	return _coast(p) > -3.0
func _height(x: float, z: float) -> float:
	var coast := _coast(Vector2(x, z))
	var hills := (3 * smoothstep(37, 43, -z) + 5 * smoothstep(52, 58, x) + 3 * smoothstep(63, 70, -z)) * (1 - smoothstep(-12, -4, coast))
	var depth := -WATER_LEVEL + WATER_DEPTH if water_battle else 2.0
	return BASE_HEIGHT + hills - depth * smoothstep(-2, 3, coast)
func _dirt(x: float, z: float) -> float:
	return maxf(maxf(1 - smoothstep(1.5, 2.5, _road(Vector2(x, z))), smoothstep(1, 3, _height(x, z) - BASE_HEIGHT)), smoothstep(-7, -1, _coast(Vector2(x, z))))
func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for home in [Vector2(-24, -22), Vector2(22, -26), Vector2(30, 21)]:
		if absf(x - home.x) < 6 and absf(z - home.y) < 6:
			return false
	return p.length() > 8 and not _wet(p) and _road(p) > 3 and (p.length() > 22 or sin(x * 0.3) + cos(z * 0.5) > 0.65)
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 2609271
	var scenery := _begin_town("PalletTownGarden", "pallet_town")
	var terraces := _group(scenery, "TownTerraces")
	_ledge(terraces, "NorthLedge", -36.75, -43.1, 3, 8, 0, 52)
	_ledge(terraces, "EastRidge", -51.75, -58.1, 5, 1000, -PI / 2, 65)
	_mountain_peaks(terraces, [Vector2(64, -54), Vector2(65, -35), Vector2(66, -16), Vector2(65, 5)])
	_tree_rows(scenery, [[-65, -48, 29, 4.5, 0], [-72, -57, 32, 4.5, 0], [-60, -40, 25, 0, 4.5], [-70, -45, 27, 0, 4.5], [44, -37, 24, 0, 4.5], [52, -40, 26, 0, 4.5], [-62, 62, 25, 4.5, 0], [-68, 73, 30, 4.5, 0]], _wet, _road)
	var close_trees: Node3D = scenery.get_node("RegionConifers")
	for p in [Vector2(-29, -9), Vector2(-31, -13), Vector2(-9, -29), Vector2(-13, -32), Vector2(29, 0), Vector2(33, 4), Vector2(10, 32), Vector2(14, 35)]:
		if not _wet(p):
			_plant_tree(close_trees, p, int(p.x))
	var props := _group(scenery, "RegionLandmarks")
	kit.town_house(props, _point(Vector2(-24, -22)), "PlayersHouse", Color("419ba0")).scale = Vector3.ONE * 1.35
	kit.town_house(props, _point(Vector2(22, -26)), "RivalsHouse", Color("419ba0")).scale = Vector3.ONE * 1.35
	kit.oaks_lab(props, _point(Vector2(30, 21)))
	props.get_child(-1).rotation.y = -PI / 2
	kit.stairs(props, _point(Vector2(8, -37)), 3, "NorthTownStairs")
	for row in [[-31, -18, -17], [16, 28, -20], [18, 34, 29], [-34, -28, -9]]:
		kit.fence(props, _point(Vector2(row[0], row[2])), row[1] - row[0])
	kit.bench(props, _point(Vector2(-25, 2)), PI)
	kit.signpost(props, _point(Vector2(21, 15)))
	props.get_child(-1).name = "LabSign"
	_rocks_and_flowers(scenery, [Vector2(-9, -7), Vector2(9, -8), Vector2(-9, 7), Vector2(10, 8), Vector2(-30, -17), Vector2(28, -20), Vector2(29, 29), Vector2(-31, -7)], [Vector2(-33, -11), Vector2(-12, 14), Vector2(37, -8)])
	var pier := _group(props, "FishingPier")
	for i in 12:
		kit._box(pier, "timber", Vector3(-24, BASE_HEIGHT + 0.05, 2 + i * 0.48), Vector3(2.7, 0.16, 0.43))
	for x in [-25.2, -22.8]:
		for z in [2, 7.5]:
			kit._box(pier, "timber", Vector3(x, -0.45, z), Vector3(0.18, 1.4, 0.18))
	_ocean(scenery)
	_grass(scenery)
	_finish_surface()
	return route_scene

func _ocean(parent: Node3D) -> void:
	var ocean := _group(parent, "PalletOcean")
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/maps/pallet_town/ocean_water.gdshader")
	material.set_shader_parameter("battle_shallows", water_battle)
	material.set_shader_parameter("battle_origin", WATER_ORIGIN)
	var surface: MeshInstance3D = kit.geo._put(ocean, plane, material, Vector3(0, BASE_HEIGHT + WATER_LEVEL, 0), Vector3.ONE)
	surface.name = "WaterSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A few low coastal rocks; the southern horizon stays open toward Cinnabar.
	for p in [Vector2(-53, 0), Vector2(-64, -8), Vector2(-76, -15)]:
		kit.geo._put(ocean, kit.geo._rock_mesh(int(-p.x)), rock_material, Vector3(p.x, -0.6, p.y), Vector3(2.1, 1.7, 2.2))
