extends "res://scripts/battle/arenas/shared/wooded_route.gd"
## Map-specific Route 22 / Gary arena. Land and water share one authored layout.
const Framing = preload("res://scripts/battle/arenas/shared/framing.gd")
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
const BASE_HEIGHT := 0.037750244140625
const POND_CENTER := Vector2(Framing.ROUTE_22_POND_ORIGIN.x, Framing.ROUTE_22_POND_ORIGIN.z)
const POND_RADII := Vector2(4.8, 6.5)
const SOUTH_POND := Vector2(-17, 21)
const SOUTH_RADII := Vector2(5, 4)
const WATER_LEVEL := -0.22
const FIGHT_WATER_DEPTH := 0.22
var water_battle := false
var rock_materials := {}

func _cache_key() -> String:
	return "route_22_water" if water_battle else "route_22"
func _grass_key() -> String:
	return "route_22"

func _grid_rect() -> Rect2i:
	return Rect2i(-76, -70, 153, 141)

func _grass_rect() -> Rect2i:
	return Rect2i(-5, -5, 10, 10)

func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO, POND_CENTER]

func _border_height(x: float, z: float) -> float:
	return (3.2 * smoothstep(30, 33, z) + 4.0 * smoothstep(43, 47, z)
		+ 3.5 * smoothstep(34, 38, -x) + 4.0 * smoothstep(48, 53, -x)
		+ 3.5 * smoothstep(42, 46, x) + 4.0 * smoothstep(56, 61, x))

func build(_camera: Camera3D, _scene_path := "") -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 220464
	_start_scene("Route22ShallowWater" if water_battle else "Route22RivalMeadow")
	route_scene.set_meta("source_map", "kanto_route_22")
	var scenery := Node3D.new()
	scenery.name = "Route22Scenery"
	route_scene.add_child(scenery)
	_terraces(scenery)
	_trees(scenery)
	_landmarks(scenery)
	_flowers(scenery)
	_water(scenery)
	_grass(scenery)
	if water_battle:
		ground_height += WATER_LEVEL - FIGHT_WATER_DEPTH
	route_scene.set_meta("surface_height", ground_height)
	return route_scene

func _height(x: float, z: float) -> float:
	var north := lerpf(4.2 * clampf((-z - 23.0) / 8.4, 0, 1),
		4.2 * smoothstep(26.0, 28.0, -z), smoothstep(1.8, 3.3, absf(x + 5.0)))
	north += 3.5 * smoothstep(36.0, 39.0, -z)
	var depth := -WATER_LEVEL + FIGHT_WATER_DEPTH if water_battle else 1.2
	var basin := depth * (1.0 - smoothstep(1.0 if water_battle else 0.8, 1.15, _pond_distance(x, z)))
	var south_basin := 1.2 * (1.0 - smoothstep(0.8, 1.15, ((Vector2(x, z) - SOUTH_POND) / SOUTH_RADII).length()))
	return BASE_HEIGHT + north + _border_height(x, z) - basin - south_basin

func _path_distance(x: float, z: float) -> float:
	var road := minf(absf(z - _route_z(x)), absf(x + 5.0) if z < -11 and z > -34 else 100.0)
	# Southern footpath crosses the small pond, then returns along the east bank.
	for segment in [[Vector2(-29, -11), Vector2(-29, 24)], [Vector2(-29, 24), Vector2(22, 24)],
		[Vector2(22, 24), Vector2(22, -10)]]:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var p := a + (b - a) * clampf((Vector2(x, z) - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
		road = minf(road, p.distance_to(Vector2(x, z)))
	return road

func _dirt(x: float, z: float) -> float:
	return maxf(1.0 - smoothstep(1.0, 2.0, _path_distance(x, z)),
		1.0 - smoothstep(1.0, 1.16, _pond_distance(x, z)))

func _has_grass(x: float, z: float) -> bool:
	if Vector2(x, z).length() < 6 or _pond_distance(x, z) < 1.20 or _path_distance(x, z) < 1.8:
		return false
	if ((Vector2(x, z) - SOUTH_POND) / SOUTH_RADII).length() < 1.25:
		return false
	if absf(x + 19.0) < 2.5 and z >= -16 and z <= 5:
		return false
	if absf(z + 27) < 1.5 or absf(z + 37.5) < 2 or absf(z - 31.5) < 2:
		return false
	for patch in [Rect2(-16, -9, 8, 14), Rect2(-5, -9, 7, 3), Rect2(-6, 8, 13, 8),
		Rect2(17, 5, 4, 13), Rect2(-27, 6, 7, 7), Rect2(-14, -34, 12, 4)]:
		if patch.has_point(Vector2(x, z)):
			return true
	return Vector2(x, z).length() > 25 and sin(x * 0.52) + cos(z * 0.43) > 0.45

func _pond_distance(x: float, z: float) -> float:
	return ((Vector2(x, z) - POND_CENTER) / POND_RADII).length()

func _route_z(x: float) -> float:
	return -11.0 + 1.2 * sin(x * 0.12)

func _terraces(parent: Node3D) -> void:
	var cliffs := Node3D.new()
	cliffs.name = "NorthernRockTerraces"
	parent.add_child(cliffs)
	_ledge(cliffs, "NorthLowerLedge", -25.75, -28.1, 4.2, -5.0)
	_ledge(cliffs, "NorthUpperLedge", -35.75, -39.1, 3.5, 1000.0)
	for spec in [[PI, -29.75, -33.1, 3.2], [PI, -42.75, -47.1, 4.0],
		[PI / 2, -33.75, -38.1, 3.5], [PI / 2, -47.75, -53.1, 4.0],
		[-PI / 2, -41.75, -46.1, 3.5], [-PI / 2, -55.75, -61.1, 4.0]]:
		_ledge(cliffs, "OuterLedge%d" % cliffs.get_child_count(), spec[1], spec[2], spec[3], 1000.0, spec[0])
	for i in 64:
		var p := Vector2(rng.randf_range(-48, 55), rng.randf_range(-49, 49))
		if p.y > -32 and p.y < 34 and p.x > -38 and p.x < 47:
			continue
		var size := rng.randf_range(1.5, 4.5)
		var rock := _sized_asset(cliffs, "rocks/rock_object_" + ["a", "c", "e"][i % 3],
			Vector3(p.x, _height(p.x, p.y) - 0.15, p.y), Vector3(size, size * 0.8, size), rng.randf() * TAU)
		_tint_rock(rock)

func _tint_rock(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var source: ShaderMaterial = node.material_override
		var key := source.get_instance_id()
		if not rock_materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("albedo", Color("a88b6a"))
			material.set_shader_parameter("uv_scale", Vector3.ONE * 2.0)
			rock_materials[key] = material
		node.material_override = rock_materials[key]
	for child in node.get_children():
		_tint_rock(child)

func _trees(parent: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "RouteConifers"
	parent.add_child(trees)
	for row in [[-32.0, -30.0, 13, 0, 4.5], [-38.0, -30.0, 16, 0, 4.5],
		[37.0, -25.0, 14, 0, 4.5], [43.0, -25.0, 15, 0, 4.5],
		[-27.0, 29.0, 13, 4.5, 0], [-29.0, 38.0, 16, 4.5, 0],
		[-37.0, -36.0, 18, 4.5, 0], [-40.0, -43.0, 19, 4.5, 0]]:
		for i in int(row[2]):
			var p := Vector2(row[0] + i * row[3], row[1] + i * row[4])
			p += Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
			_plant_tree(trees, p, i)

func _landmarks(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Route22Landmarks"
	parent.add_child(props)
	var geo = Geometry.new(route_scene)
	var box := BoxMesh.new()
	var steps = geo._stone(Color("aaa393"))
	var timber = geo._stone(Color("79543a"))
	var rails = geo._stone(Color("d1d4bb"))
	for i in 14:
		var height := (i + 1) * 0.30
		var z: float = -23.3 - i * 0.60
		geo._put(props, box, steps, Vector3(-5, ground_height + height * 0.5 + 0.03, z), Vector3(3.2, height, 0.61))
		for side in [-1, 1]:
			geo._put(props, box, timber, Vector3(-5 + side * 1.73, ground_height + height + 0.13, z), Vector3(0.18, 0.26, 0.61))
	for side in [-1, 1]:
		for i in [0, 6, 13]:
			geo._put(props, box, timber, Vector3(-5 + side * 1.73, ground_height + (i + 1) * 0.30 + 0.45, -23.3 - i * 0.60), Vector3(0.22, 0.95, 0.22))
	for x in [-9.5, 5.6]:
		for i in 5:
			geo._put(props, box, rails, Vector3(x, ground_height + 0.36, -4.0 + i * 0.65), Vector3(0.12, 0.72, 0.12))
		for y in [0.25, 0.55]:
			geo._put(props, box, rails, Vector3(x, ground_height + y, -2.7), Vector3(0.10, 0.10, 2.9))
	var paving = geo._stone(Color("7a7c76"), true)
	geo._put(props, box, paving, Vector3(-19.0, ground_height + 0.035, -6), Vector3(4.5, 0.07, 22))
	for side in [-1, 1]:
		geo._put(props, box, steps, Vector3(-19.0 + side * 2.35, ground_height + 0.08, -6), Vector3(0.20, 0.16, 22))

	_league_gate(props, geo)
	_south_bridge(props, geo)

func _flowers(parent: Node3D) -> void:
	var flowers := Node3D.new()
	flowers.name = "RouteFlowers"
	parent.add_child(flowers)
	_plant_beds(flowers, [Vector2(-7.8, -5.5), Vector2(3, -8), Vector2(-7.5, 4.2),
		Vector2(6, 7), Vector2(-5, 8), Vector2(-23, 7), Vector2(-24, 17), Vector2(-9, 19),
		Vector2(16, 15), Vector2(19, -15), Vector2(-13, -13), Vector2(13, -24)])

func _league_gate(parent: Node3D, geo: RefCounted) -> void:
	var gate := Node3D.new()
	gate.name = "LeagueApproachGate"
	gate.position = Vector3(-24, _height(-24, -14), -14)
	parent.add_child(gate)
	var box := BoxMesh.new()
	var cream: Material = geo._stone(Color("c8c9b6"))
	var trim: Material = geo._stone(Color("e4e0cf"))
	var roof: Material = geo._stone(Color("448252"))
	# Open passage with solid piers and a stepped green roof, visible from all sides.
	for side in [-1, 1]:
		geo._put(gate, box, cream, Vector3(side * 2.5, 2.1, 0), Vector3(1.3, 4.2, 3.4))
		geo._put(gate, box, trim, Vector3(side * 2.5, 0.3, 0), Vector3(1.6, 0.6, 3.7))
	geo._put(gate, box, trim, Vector3(0, 4.1, 0), Vector3(6.5, 0.6, 3.8))
	for tier in 4:
		geo._put(gate, box, roof, Vector3(0, 4.55 + tier * 0.28, 0), Vector3(6.7 - tier * 0.8, 0.3, 4.2 - tier * 0.35))
	geo._put(parent, box, geo._stone(Color("7a7c76"), true), Vector3(-21.5, ground_height + 0.035, -13), Vector3(9, 0.07, 4))

func _south_bridge(parent: Node3D, geo: RefCounted) -> void:
	var bridge := Node3D.new()
	bridge.name = "SouthernFootbridge"
	bridge.position = Vector3(SOUTH_POND.x, BASE_HEIGHT + 0.16, 24)
	parent.add_child(bridge)
	var wood: Material = geo._stone(Color("936a42"))
	var rail: Material = geo._stone(Color("cfbb8e"))
	var box := BoxMesh.new()
	for i in 24:
		geo._put(bridge, box, wood, Vector3(-5.75 + i * 0.5, 0, 0), Vector3(0.47, 0.18, 2.4))
	for side in [-1, 1]:
		for i in 7:
			geo._put(bridge, box, wood, Vector3(-6 + i * 2, 0.3, side * 1.2), Vector3(0.17, 1.2, 0.17))
		geo._put(bridge, box, rail, Vector3(0, 0.8, side * 1.2), Vector3(12, 0.13, 0.15))

func _water(parent: Node3D) -> void:
	_pond_surface(parent, "EasternPond", POND_CENTER, POND_RADII, water_battle)
	_pond_surface(parent, "SouthernPond", SOUTH_POND, SOUTH_RADII, false)

func _pond_surface(parent: Node3D, label: String, center: Vector2, radii: Vector2, shallows: bool) -> void:
	# Eastern pond from the overworld, kept outside the shared battle clearing.
	# The surface meets a sculpted basin; it is not laid over an intact grass floor.
	var shore := Node3D.new()
	shore.name = label
	parent.add_child(shore)
	var plane := PlaneMesh.new()
	plane.size = radii * 2.5
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/maps/route_22/water.gdshader")
	material.set_shader_parameter("pond_center", center)
	material.set_shader_parameter("pond_radii", radii)
	material.set_shader_parameter("battle_shallows", shallows)
	var geo = Geometry.new(route_scene)
	var surface: MeshInstance3D = geo._put(shore, plane, material,
		Vector3(center.x, ground_height + WATER_LEVEL, center.y), Vector3.ONE)
	surface.name = "WaterSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shoreline_rng := RandomNumberGenerator.new()
	shoreline_rng.seed = 22022
	for i in 18:
		var angle := TAU * i / 18.0
		var point := center + Vector2(cos(angle), sin(angle)) * radii * 1.12
		var rock := _asset(shore, "rocks/rock_object_a",
			Vector3(point.x, _height(point.x, point.y) - 0.03, point.y),
			Vector3(0.45, 0.30, 0.40) * shoreline_rng.randf_range(0.7, 1.3), angle)
		_tint_rock(rock)
