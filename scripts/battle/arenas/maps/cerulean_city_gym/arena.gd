extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## Cerulean's pixel gym: indoor pool, yellow timber paths, lane floats and Misty's parasol.
func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "CeruleanGymArena"
	arena.set_meta("source_map", "kanto_cerulean_city_gym")
	arena.set_meta("surface_height", 0.0)
	var tiles := surface(Color("c5dedc"), Color("7ea8ac"), 0, 1.1)
	var blue := surface(Color("669eaf"), Color("528999"), 0, 1.3)
	var white := matte(Color("e7e7d6"))
	var navy := matte(Color("276478"))
	var float_yellow := matte(Color("e2c35d"))
	var yellow := surface(Color("d7b75e"), Color("947637"), 2, 1.1)
	var red := matte(Color("d65042"))
	var glow := matte(Color("d2edf1"), 0.45)
	hall(arena, blue, white, surface(Color("a4c2c8"), Color("7997a0"), 0, 3.0))
	box(arena, blue, Vector3(0, -1.3, 0), Vector3(52, 0.5, 62))
	var pool := group(arena, "SwimmingPool")
	var water := ShaderMaterial.new()
	water.shader = preload("res://scripts/battle/arenas/shared/gym_pool.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(44, 48)
	prop(pool, plane, water, Vector3(0, -0.28, 0))
	for x in [-24, 24]:
		box(pool, tiles, Vector3(x, -0.1, 0), Vector3(4, 0.2, 62))
		box(pool, white, Vector3(sign(x) * 22.1, 0.06, 0), Vector3(0.35, 0.12, 48.4))
	for z in [-27.5, 27.5]:
		box(pool, tiles, Vector3(0, -0.1, z), Vector3(44, 0.2, 7))
		box(pool, white, Vector3(0, 0.06, sign(z) * 24.1), Vector3(44, 0.12, 0.35))
	# Level dry battle island: grounded species retain the normal y=0 contact plane.
	var island := group(arena, "BattleIsland")
	box(island, navy, Vector3(0, -0.45, 0), Vector3(17.4, 0.8, 13.4))
	box(island, tiles, Vector3(0, -0.08, 0), Vector3(17, 0.16, 13))
	for x in [-8.35, 8.35]:
		box(island, white, Vector3(x, 0.013, 0), Vector3(0.2, 0.022, 13))
	for z in [-6.35, 6.35]:
		box(island, white, Vector3(0, 0.013, z), Vector3(16.9, 0.022, 0.2))
	emblem(island, matte(Color("8db8ba")), Vector3(0, 0.018, 0), 2.0)
	var paths := group(arena, "YellowBoardwalks")
	for z in [-16.4, 16.4]:
		box(paths, yellow, Vector3(0, -0.06, z), Vector3(3.0, 0.12, 20))
	for x in [-17, 17]:
		box(paths, yellow, Vector3(x, -0.06, 0), Vector3(2.6, 0.12, 45))
		for z in [-10, 10]:
			box(paths, yellow, Vector3(x * 0.5, -0.06, z), Vector3(17, 0.12, 2.6))
	# Floating blue/yellow lane ropes and rings are visible from either side.
	var lanes := group(arena, "LaneFloats")
	for x in [-12.3, 12.3]:
		for i in 43:
			cylinder(lanes, float_yellow if i % 2 == 0 else navy, Vector3(x, -0.17, -22 + i * 1.04), 0.17, 0.42).rotation.x = PI / 2
	for side in [-1, 1]:
		for z in [-20, -10, 0, 10, 20]:
			life_ring(arena, Vector3(side * 19.5, -0.16, z), red, white)
			var window := group(arena, "HighWindow", Vector3(side * 25.35, 9, z))
			window.rotation.y = -side * PI / 2
			box(window, white, Vector3.ZERO, Vector3(6.4, 6.8, 0.3))
			box(window, glow, Vector3(0, 0, 0.18), Vector3(5.9, 6.3, 0.15))
			box(window, white, Vector3(0, 0, 0.31), Vector3(0.16, 6.3, 0.14))
			box(window, white, Vector3(0, -0.8, 0.31), Vector3(5.9, 0.16, 0.14))
			lamp(arena, Vector3(side * 25.3, 4, z + 3.8), -side * PI / 2, navy, matte(Color("ffe1a0"), 0.6))
		for z in [-17, 4, 19]:
			bench(arena, Vector3(side * 24, 0, z), -side * PI / 2, yellow, navy)
	var dais := group(arena, "MistyDais", Vector3(0, 0, -27))
	box(dais, blue, Vector3(0, 0.625, 0), Vector3(14, 1.25, 6))
	box(dais, tiles, Vector3(0, 1.3, 0), Vector3(14.3, 0.1, 6.3))
	stairs(dais, tiles, Vector3(0, 0, 3.0), 5, 5)
	parasol(dais, Vector3(4.5, 1.35, -0.5), matte(Color("468fc5")), white)
	life_ring(dais, Vector3(-4.5, 1.5, 0), red, white)
	# Cascade Badge relief, windows and tiled bands complete both end walls.
	var badge := group(arena, "CascadeBadge", Vector3(0, 8.4, -30.25))
	var drop := SphereMesh.new()
	drop.radius = 1.6
	drop.height = 3.2
	prop(badge, drop, white, Vector3.ZERO, Vector3(1.15, 1.35, 0.2))
	prop(badge, drop, matte(Color("49c7e6")), Vector3(0, 0, 0.2), Vector3(0.9, 1.15, 0.2))
	cylinder(badge, matte(Color("49c7e6")), Vector3(0, 2.0, 0.22), 1.05, 2.6, 0.0).scale.z = 0.22
	for z in [-30.25, 30.25]:
		for x in [-16, 16]:
			var window := group(arena, "EndWindow", Vector3(x, 9.0, z))
			window.rotation.y = PI if z > 0 else 0.0
			box(window, white, Vector3.ZERO, Vector3(7, 6, 0.3))
			box(window, glow, Vector3(0, 0, 0.2), Vector3(6.5, 5.5, 0.15))
			box(window, white, Vector3(0, 0, 0.32), Vector3(0.2, 5.5, 0.15))
	var entrance := group(arena, "Entrance", Vector3(0, 0, 30.3))
	box(entrance, white, Vector3(0, 3.6, -0.2), Vector3(7.4, 7.2, 0.5))
	box(entrance, navy, Vector3(0, 3.4, -0.5), Vector3(6.8, 6.8, 0.3))
	box(entrance, white, Vector3(0, 3.4, -0.7), Vector3(0.15, 6.8, 0.15))
	box(arena, blue, Vector3(0, 0.02, 27.5), Vector3(6.5, 0.04, 5))
	for side in [-1, 1]:
		statue(arena, Vector3(side * 6, 0, 28), white, blue)
		for i in 3:
			var pos := Vector3(side * (11.0 + i * 4), 0, 25.5)
			box(arena, white, pos + Vector3(0, 0.45, 0), Vector3(1.7, 0.9, 1.8))
			box(arena, [red, navy, yellow][i], pos + Vector3(0, 0.95, 0), Vector3(2, 0.15, 2))
	return arena

func life_ring(parent: Node3D, pos: Vector3, red: Material, white: Material) -> void:
	var node := group(parent, "LifeRing", pos)
	ring(node, red, Vector3.ZERO, 0.55, 0.13)
	for angle in [0.0, PI / 2, PI, PI * 1.5]:
		var band := box(node, white, Vector3(sin(angle) * 0.55, 0.02, cos(angle) * 0.55), Vector3(0.24, 0.24, 0.27))
		band.rotation.y = angle

func bench(parent: Node3D, pos: Vector3, yaw: float, wood: Material, frame: Material) -> void:
	var node := group(parent, "PoolBench", pos)
	node.rotation.y = yaw
	box(node, wood, Vector3(0, 0.8, 0), Vector3(3.3, 0.15, 0.9))
	box(node, wood, Vector3(0, 1.3, -0.4), Vector3(3.3, 0.7, 0.12))
	for x in [-1.2, 1.2]:
		box(node, frame, Vector3(x, 0.4, 0), Vector3(0.12, 0.8, 0.7))

func parasol(parent: Node3D, pos: Vector3, blue: Material, white: Material) -> void:
	var node := group(parent, "MistyParasol", pos)
	cylinder(node, white, Vector3(0, 1.8, 0), 0.065, 3.6)
	cylinder(node, white, Vector3(0, 0.1, 0), 0.5, 0.2)
	for i in 8:
		var a := i * TAU / 8.0
		var b := (i + 1) * TAU / 8.0
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(Vector3(0, 4.0, 0))
		mesh.surface_add_vertex(Vector3(sin(b) * 2.2, 3.1, cos(b) * 2.2))
		mesh.surface_add_vertex(Vector3(sin(a) * 2.2, 3.1, cos(a) * 2.2))
		mesh.surface_end()
		var fabric := (blue if i % 2 == 0 else white).duplicate() as StandardMaterial3D
		fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
		prop(node, mesh, fabric, Vector3.ZERO)
