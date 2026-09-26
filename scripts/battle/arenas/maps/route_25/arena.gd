extends "res://scripts/battle/arenas/shared/cerulean_region.gd"
## Sea Cottage, forest paths and the mountain-backed southeastern ocean shore.
const WATER_ORIGIN := Vector2(30, 25)
const GARDEN_POND := Vector2(13, -18)
const GARDEN_RADII := Vector2(3.5, 3)
const ROADS := [[Vector2(-48, 10), Vector2(-13, 10)], [Vector2(-13, 10), Vector2(-13, -12)],
	[Vector2(-13, -12), Vector2(16, -12)], [Vector2(16, -12), Vector2(16, -29)],
	[Vector2(-13, 10), Vector2(3, 15)]]
func _cache_key() -> String:
	return "route_25_water" if water_battle else "route_25"
func _grass_key() -> String:
	return "route_25"
func _grid_rect() -> Rect2i:
	return Rect2i(-100, -95, 231, 221)
func _grass_rect() -> Rect2i:
	return Rect2i(-7, -7, 14, 14)
func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, WATER_ORIGIN]
func _road(p: Vector2) -> float:
	return _road_distance(p, ROADS)
func _coast(p: Vector2) -> float:
	return p.x + p.y - 24.0 + 2.0 * sin(p.y * 0.12)
func _wet(p: Vector2) -> bool:
	return _coast(p) > -2 or ((p - GARDEN_POND) / GARDEN_RADII).length() < 1.25
func _height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var north := 5.5 * smoothstep(36, 42, -z) + 5.0 * smoothstep(52, 59, -z)
	var west := 4.5 * smoothstep(35, 41, -x) + 5.0 * smoothstep(53, 60, -x)
	var south := 4.0 * smoothstep(36, 42, z)
	var east := 5.0 * smoothstep(41, 48, x)
	var coast := _coast(p)
	var hills := (north + west + south + east) * (1.0 - smoothstep(-16, -3, coast))
	var depth := -WATER_LEVEL + WATER_DEPTH if water_battle else 2.0
	return BASE_HEIGHT + hills - depth * smoothstep(-2, 3, coast) - _basin(p, GARDEN_POND, GARDEN_RADII, false)
func _dirt(x: float, z: float) -> float:
	return maxf(maxf(1 - smoothstep(1.3, 2.4, _road(Vector2(x, z))), smoothstep(2, 4, _height(x, z) - BASE_HEIGHT)), smoothstep(-5, -1, _coast(Vector2(x, z))))
func _has_grass(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return p.length() > 7 and not _wet(p) and _road(p) > 2.7 and _height(x, z) < BASE_HEIGHT + 1 and (p.length() > 23 or sin(x * 0.45) + cos(z * 0.5) > 0.8)
func build(_camera: Camera3D = null) -> Node3D:
	rng.seed = 252626
	var scenery := _begin_region("BillsCoastalGarden", "route_25")
	var mountains := _group(scenery, "MountainTerraces")
	# Capped shelves end at the headland rather than continuing into the ocean.
	_ledge(mountains, "NorthLowerCliff", -35.75, -42.1, 5.5, 1000, 0, 40)
	_ledge(mountains, "NorthUpperCliff", -51.75, -59.1, 5, 1000, 0, 55)
	_ledge(mountains, "WestLowerCliff", -34.75, -41.1, 4.5, 1000, PI / 2, 42)
	_ledge(mountains, "WestUpperCliff", -52.75, -60.1, 5, 1000, PI / 2, 55)
	_mountain_peaks(mountains, [Vector2(-63, -65), Vector2(-43, -65), Vector2(-24, -65), Vector2(-5, -65), Vector2(14, -64), Vector2(34, -65), Vector2(51, -64), Vector2(-65, -44), Vector2(-65, -23), Vector2(-64, -3), Vector2(-65, 17), Vector2(-65, 38), Vector2(-49, 54)])
	# Low overlapping outcrops merge into the cape instead of perched summit boulders.
	for i in 6:
		var p := Vector2(44 + sin(i * 0.7) * 3, -46 + i * 4)
		kit.geo._put(mountains, kit.geo._rock_mesh(980 + i), rock_material,
			_point(p) - Vector3.UP * 1.6, Vector3(6, 3.5, 5), i * 0.6)
	_tree_rows(scenery, [[-31, -29, 16, 4.5, 0], [-39, -45, 22, 4.5, 0],
		[-29, -25, 16, 0, 4.5], [-42, -33, 22, 0, 4.5], [-26, 30, 14, 4.5, 0],
		[39, -35, 10, 0, 4.5], [-28, -20, 4, 4.2, 0], [-29, 18, 4, 4.2, 0]], _wet, _road)
	var props := _group(scenery, "RegionLandmarks")
	kit.cottage(props, _point(Vector2(16, -30)), "BillsSeaCottage", 0, true)
	kit.signpost(props, _point(Vector2(21, -24)))
	props.get_child(-1).name = "SeaCottageSign"
	kit.bench(props, _point(Vector2(5, -22)), PI / 2)
	for spec in [[5, 11, -24], [21, 29, -24], [-28, -17, 24], [-27, -18, -24]]:
		kit.fence(props, _point(Vector2(spec[0], spec[2])), spec[1] - spec[0])
	_rocks_and_flowers(scenery, [Vector2(-8, -7), Vector2(7, -8), Vector2(-8, 7), Vector2(5, 10), Vector2(7, -25), Vector2(25, -27), Vector2(-24, 22), Vector2(1, 19)], [Vector2(-25, 24), Vector2(22, -9), Vector2(6, 18), Vector2(-8, 28), Vector2(35, -15)])
	_detail(scenery, "log", _point(Vector2(-27, -19)), Vector3(3.4, 0.8, 1), 0.4)
	_detail(scenery, "mushrooms", _point(Vector2(-26, -17)), Vector3(0.8, 0.5, 0.7))
	_pond(scenery, "CottageGardenPond", GARDEN_POND, GARDEN_RADII, false)
	_ocean(scenery)
	_grass(scenery)
	_finish_surface()
	return route_scene
func _ocean(parent: Node3D) -> void:
	var sea := _group(parent, "CeruleanCapeOcean")
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/maps/route_25/coast_water.gdshader")
	material.set_shader_parameter("battle_shallows", water_battle)
	material.set_shader_parameter("battle_origin", WATER_ORIGIN)
	var surface: MeshInstance3D = kit.geo._put(sea, plane, material, Vector3(0, BASE_HEIGHT + WATER_LEVEL, 0), Vector3.ONE)
	surface.name = "WaterSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Low offshore rocks carry the pixel map's rocky cape into the sea panorama.
	for i in 14:
		var p := Vector2(65 + i % 5 * 10 + sin(i * 2.3) * 5, -4 + i / 5 * 33 + cos(i * 1.7) * 8)
		kit.geo._put(sea, kit.geo._rock_mesh(920 + i), rock_material,
			Vector3(p.x, -0.7, p.y), Vector3(1.6 + i % 3, 1.5 + i % 2, 2.4), i * 0.7)
