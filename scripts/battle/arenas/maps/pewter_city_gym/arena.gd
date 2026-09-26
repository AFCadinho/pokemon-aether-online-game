extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## Pewter's pixel gym: sand, boulder gardens, stone pillars and Brock's raised dais.
func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "PewterGymArena"
	arena.set_meta("source_map", "kanto_pewter_city_gym")
	arena.set_meta("surface_height", 0.0)
	var sandstone := surface(Color("b89a70"), Color("827258"), 1, 1.6)
	var trim := _stone(Color("b9ac91"))
	var paving := surface(Color("b6ad94"), Color("8c8675"), 0, 1.5)
	var earth := _stone(Color("aa8b59"), true)
	var rock := _stone(Color("847059"))
	var dark := matte(Color("403c35"))
	var bronze := matte(Color("736044"))
	var amber := matte(Color("ffd68b"), 0.8)
	hall(arena, sandstone, trim, surface(Color("766750"), Color("5c5343"), 1, 3.0))
	box(arena, paving, Vector3(0, -0.34, 0), Vector3(52, 0.6, 62))
	var court := group(arena, "SandyBattleCourt")
	box(court, earth, Vector3(0, -0.06, 0), Vector3(28, 0.12, 34))
	var lines := matte(Color("d2bd91"))
	for x in [-7.8, 7.8]:
		box(court, lines, Vector3(x, 0.012, 0), Vector3(0.1, 0.02, 12))
	for z in [-6.0, 6.0]:
		box(court, lines, Vector3(0, 0.012, z), Vector3(15.7, 0.02, 0.1))
	emblem(court, lines, Vector3(0, 0.02, 0), 2.0)
	# Low, irregular rock clusters break up the sandy margins on every side.
	var margins := group(arena, "SandyMargins")
	var leaves := matte(Color("677c43"))
	for i in 12:
		var angle := i * TAU / 12.0
		var center := Vector3(sin(angle) * 11.8, 0, cos(angle) * 13.8)
		for j in 3:
			var size := Vector3(0.65 + j * 0.2, 0.25 + (i % 3) * 0.16, 0.6 + j * 0.15)
			prop(margins, _rock_mesh(980 + i * 3 + j), rock, center + Vector3(j * 0.65, size.y * 0.5, sin(j + i) * 0.6), size)
		for j in 3:
			var sprig := prop(margins, _rock_mesh(111 + j), leaves, center + Vector3(-0.65 + j * 0.25, 0.2, 0.5), Vector3(0.14, 0.28, 0.12))
			sprig.rotation.z = (j - 1) * 0.35
	# Low gardens frame the combatants without obstructing the free camera.
	var gardens := group(arena, "BoulderGardens")
	for side in [-1, 1]:
		for i in 7:
			var z := -19.0 + i * 6.0
			box(gardens, sandstone, Vector3(side * 18.6, 0.12, z), Vector3(8.0, 0.24, 5.3))
			box(gardens, earth, Vector3(side * 18.6, 0.26, z), Vector3(7.6, 0.12, 4.9))
			for j in 3:
				var rock_size := Vector3(1.15 + j * 0.25, 0.7 + ((i + j) % 3) * 0.38, 1.05)
				var boulder := prop(gardens, _rock_mesh(510 + i * 3 + j), rock, Vector3(side * (16.5 + j * 1.8), rock_size.y * 0.65, z + (j % 2) * 1.0), rock_size)
				boulder.rotation.y = i * 1.7 + j
		for z in [-24, -12, 0, 12, 24]:
			var column := group(arena, "StonePier", Vector3(side * 24, 0, z))
			box(column, trim, Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 2.6))
			box(column, sandstone, Vector3(0, 7, 0), Vector3(1.6, 13, 1.6))
			box(column, trim, Vector3(0, 13.4, 0), Vector3(2.7, 0.8, 2.7))
			lamp(arena, Vector3(side * 25.2, 6.3, z + 4.5), -side * PI / 2, bronze, amber)
	var dais := group(arena, "BrockDais", Vector3(0, 0, -26))
	box(dais, sandstone, Vector3(0, 0.75, 0), Vector3(15, 1.5, 7))
	box(dais, paving, Vector3(0, 1.56, 0), Vector3(15.4, 0.12, 7.4))
	stairs(dais, paving, Vector3(0, 0, 3.5), 7, 6)
	for side in [-1, 1]:
		for z in [-2.5, 0, 2.5]:
			box(dais, bronze, Vector3(side * 7.0, 2.2, z), Vector3(0.2, 1.3, 0.2))
		box(dais, bronze, Vector3(side * 7.0, 2.8, 0), Vector3(0.25, 0.2, 5.5))
	for x in [-9.5, 9.5]:
		prop(dais, _rock_mesh(782), rock, Vector3(x, 2, 0), Vector3(2.4, 3.8, 2.0))
	# A stone Boulder Badge relief makes the north end immediately recognizable.
	var badge := group(arena, "BoulderBadge", Vector3(0, 7.8, -30.3))
	var shield := CylinderMesh.new()
	shield.top_radius = 2.5
	shield.bottom_radius = 2.5
	shield.height = 0.4
	shield.radial_segments = 8
	var relief := prop(badge, shield, bronze, Vector3.ZERO)
	relief.rotation.x = PI / 2
	var core := prop(badge, shield, trim, Vector3(0, 0, 0.28), Vector3(0.78, 1, 0.78))
	core.rotation.x = PI / 2
	for x in [-12, 12]:
		lamp(arena, Vector3(x, 7, -30.3), 0, bronze, amber)
	var entrance := group(arena, "Entrance", Vector3(0, 0, 30.25))
	box(entrance, trim, Vector3(0, 3.9, -0.15), Vector3(7.4, 7.8, 0.7))
	box(entrance, dark, Vector3(0, 3.5, -0.6), Vector3(6, 7, 0.4))
	box(entrance, bronze, Vector3(0, 3.5, -0.86), Vector3(0.1, 7, 0.12))
	box(arena, surface(Color("8b6449"), Color("674a37"), 2), Vector3(0, 0.02, 24), Vector3(7, 0.04, 9))
	for x in [-6.5, 6.5]:
		statue(arena, Vector3(x, 0, 26), trim, sandstone)
		lamp(arena, Vector3(x, 6, 30.2), PI, bronze, amber)
	return arena
