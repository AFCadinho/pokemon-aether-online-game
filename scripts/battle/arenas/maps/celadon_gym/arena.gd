extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## Erika's conservatory: garden court, timber screens and perimeter planting.
var foliage_mesh := SphereMesh.new()

func build() -> Node3D:
	foliage_mesh.radius = 1.0
	foliage_mesh.height = 2.0
	foliage_mesh.radial_segments = 12
	foliage_mesh.rings = 6
	var arena := Node3D.new()
	arena.name = "CeladonGymArena"
	arena.set_meta("source_map", "kanto_celadon_gym")
	arena.set_meta("surface_height", 0.0)
	var plaster := matte(Color("454d3e"))
	var timber := matte(Color("4a382b"))
	var stone := surface(Color("575947"), Color("343c30"), 0, 2.0)
	var moss := _stone(Color("2d3f29"), true)
	var soil := matte(Color("28291f"))
	var leaf := matte(Color("355f3b"))
	var light_leaf := matte(Color("587344"))
	var rose := matte(Color("995d75"))
	var cream := matte(Color("9c9262"))
	var glass := matte(Color("3b5855"), 0.07)
	var brass := matte(Color("7c6944"))
	var lantern := matte(Color("ba9a5b"), 0.3)
	hall(arena, plaster, timber, matte(Color("303d33")))
	box(arena, stone, Vector3(0, -0.34, 0), Vector3(52, 0.6, 62))
	var court := group(arena, "GardenCourt")
	box(court, moss, Vector3(0, -0.02, 0), Vector3(29, 0.04, 35))
	for x in [-14.5, 14.5]:
		box(court, timber, Vector3(x, 0.008, 0), Vector3(0.15, 0.016, 35))
	for z in [-17.5, 17.5]:
		box(court, timber, Vector3(0, 0.008, z), Vector3(29, 0.016, 0.15))
	var lines := matte(Color("505e3c"))
	emblem(court, lines, Vector3(0, 0.016, 0), 3.0)
	for x in [-9, 9]:
		box(court, lines, Vector3(x, 0.01, 0), Vector3(0.07, 0.02, 16))
	var windows := group(arena, "ConservatoryWindows")
	for side in [-1, 1]:
		for z in [-21, -7, 7, 21]:
			_window(windows, Vector3(side * 25.2, 0, z), -side * PI / 2, timber, glass)
		for x in [11, 21]:
			_window(windows, Vector3(side * x, 0, -30.2), 0, timber, glass)
		for z in [-26, 0, 26]:
			lamp(arena, Vector3(side * 25.1, 5, z), -side * PI / 2, timber, lantern)
	var beds := group(arena, "FlowerBeds")
	for side in [-1, 1]:
		for z in [-18, 0, 18]:
			var bed := group(beds, "GardenBed", Vector3(side * 23.4, 0, z))
			box(bed, timber, Vector3(0, 0.35, 0), Vector3(3.7, 0.7, 9.6))
			box(bed, soil, Vector3(0, 0.71, 0), Vector3(3.3, 0.04, 9.2))
			for i in 4:
				var origin := Vector3(0, 0.8, -3.3 + i * 2.2)
				_shrub(bed, origin, leaf, light_leaf)
				_flower(bed, origin + Vector3(-side * 0.55, 0.65, 0.3), rose if i % 2 == 0 else cream, brass)
		for z in [-25, 25]:
			var tree := group(arena, "PottedTree", Vector3(side * 21, 0, z))
			cylinder(tree, timber, Vector3(0, 0.65, 0), 1.1, 1.3, 1.35)
			cylinder(tree, soil, Vector3(0, 1.32, 0), 1.2, 0.04)
			cylinder(tree, timber, Vector3(0, 2.5, 0), 0.22, 2.5)
			for i in 3:
				prop(tree, foliage_mesh, light_leaf if i == 2 else leaf, Vector3((i - 1) * 1.0, 3.9 + (i % 2) * 1.2, 0), Vector3(1.4, 1.3, 1.4))
	var dais := group(arena, "ErikaDais", Vector3(0, 0, -27))
	box(dais, timber, Vector3(0, 0.45, 0), Vector3(13, 0.9, 5))
	box(dais, surface(Color("5c5940"), Color("363a2b"), 2, 2), Vector3(0, 0.95, 0), Vector3(13.4, 0.1, 5.4))
	stairs(dais, timber, Vector3(0, 0, 2.7), 6, 4)
	for x in [-8, 8]:
		var planter := group(dais, "FlowerUrn", Vector3(x, 0, 0))
		cylinder(planter, brass, Vector3(0, 0.7, 0), 0.8, 1.4, 1.1)
		_shrub(planter, Vector3(0, 1.4, 0), leaf, light_leaf)
		_flower(planter, Vector3(0, 2.1, 0), rose, cream)
	# A timber garden screen and eight-petal Rainbow Badge identify Erika's end.
	var screen := group(arena, "ErikaScreen", Vector3(0, 0, -30.1))
	box(screen, timber, Vector3(0, 4.4, 0), Vector3(13, 8.8, 0.4))
	box(screen, moss, Vector3(0, 4.4, 0.25), Vector3(12.4, 8.2, 0.2))
	for x in [-5, -3, 3, 5]:
		box(screen, timber, Vector3(x, 4.4, 0.4), Vector3(0.12, 8.2, 0.15))
	var badge := group(screen, "RainbowBadge", Vector3(0, 5.8, 0.5))
	var petal_colors := ["876448", "9b7c48", "7a8148", "4d784d", "417878", "536b86", "756083", "965c75"]
	for i in 8:
		var angle := i * TAU / 8.0
		var petal := prop(badge, foliage_mesh, matte(Color(petal_colors[i])), Vector3(sin(angle), cos(angle), 0) * 1.1, Vector3(0.58, 1.0, 0.18))
		petal.rotation.z = -angle
	var center := cylinder(badge, brass, Vector3(0, 0, 0.22), 0.5, 0.16)
	center.rotation.x = PI / 2
	var door := group(arena, "GardenEntrance", Vector3(0, 0, 30.1))
	box(door, timber, Vector3(0, 3.8, 0), Vector3(8, 7.6, 0.5))
	box(door, glass, Vector3(0, 3.6, -0.35), Vector3(7.4, 7.2, 0.2))
	for x in [-2, 0, 2]:
		box(door, timber, Vector3(x, 3.6, -0.5), Vector3(0.12, 7.2, 0.1))
	for y in [1.8, 3.6, 5.4]:
		box(door, timber, Vector3(0, y, -0.5), Vector3(7.4, 0.12, 0.1))
	return arena

func _window(parent: Node3D, pos: Vector3, yaw: float, timber: Material, glass: Material) -> void:
	var window := group(parent, "GreenhouseWindow", pos)
	window.rotation.y = yaw
	box(window, timber, Vector3(0, 7, 0), Vector3(8.6, 9, 0.3))
	box(window, glass, Vector3(0, 7, 0.2), Vector3(8.1, 8.5, 0.12))
	for x in [-2, 0, 2]:
		box(window, timber, Vector3(x, 7, 0.3), Vector3(0.1, 8.5, 0.12))
	for y in [5, 8, 11]:
		box(window, timber, Vector3(0, y, 0.3), Vector3(8.1, 0.1, 0.12))

func _shrub(parent: Node3D, pos: Vector3, leaf: Material, highlight: Material) -> void:
	for i in 3:
		prop(parent, foliage_mesh, highlight if i == 1 else leaf, pos + Vector3((i - 1) * 0.7, 0.35 + (i % 2) * 0.2, 0), Vector3(0.7, 0.65, 0.85))

func _flower(parent: Node3D, pos: Vector3, petals: Material, center: Material) -> void:
	for i in 5:
		var angle := i * TAU / 5.0
		prop(parent, foliage_mesh, petals, pos + Vector3(sin(angle), 0, cos(angle)) * 0.28, Vector3(0.24, 0.12, 0.3))
	prop(parent, foliage_mesh, center, pos + Vector3(0, 0.08, 0), Vector3(0.15, 0.1, 0.15))
