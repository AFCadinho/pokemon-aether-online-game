extends "res://scripts/battle/arenas/shared/cerulean_landmarks.gd"
## Original exterior architecture interpreted from the three bundled town maps.
func town_house(parent: Node3D, base: Vector3, label: String, roof: Color, angle := 0.0) -> Node3D:
	var previous: Material = materials.blue
	materials.blue = geo._stone(roof)
	cottage(parent, base, label, angle)
	materials.blue = previous
	return parent.get_child(-1)

func oaks_lab(parent: Node3D, base: Vector3) -> void:
	var node := town_house(parent, base, "OaksLab", Color("c77732"))
	node.scale = Vector3(1.65, 1.25, 1.3)
	for x in [-2.55, -0.85, 0.85, 2.55]:
		_box(node, "timber", Vector3(x, 1.8, 2.4), Vector3(0.1, 3.0, 0.1))
	_box(node, "timber", Vector3(0, 2.75, 2.4), Vector3(5.5, 0.14, 0.1))
	_box(node, "white", Vector3(0, 3.55, 2.3), Vector3(1.1, 0.65, 0.15))
	_ball_emblem(node, Vector3(0, 3.57, 2.45))

func gym(parent: Node3D, base: Vector3, label: String, angle := 0.0) -> void:
	city_gym(parent, base, angle)
	var node: Node3D = parent.get_child(-1)
	node.name = label
	node.scale = Vector3(1.4, 1.3, 1.3)
	for side in [-1, 1]:
		for z in [-1.7, 0, 1.7]:
			_box(node, "white", Vector3(side * 4.04, 1.9, z), Vector3(0.13, 1.7, 1.1))
			_box(node, "glass", Vector3(side * 4.12, 1.9, z), Vector3(0.04, 1.4, 0.85))

func museum(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "PewterMuseum", base)
	_box(node, "stone", Vector3(0, 0.3, 0), Vector3(17.2, 0.6, 8.4))
	_box(node, "wall", Vector3(0, 2.6, 0), Vector3(16.5, 4.6, 7.5))
	_box(node, "white", Vector3(0, 4.85, 0), Vector3(17.1, 0.3, 8.1))
	for side in [-1, 1]:
		var roof := _box(node, "dark", Vector3(0, 5.5, side * 2.0), Vector3(17.4, 0.2, 4.6))
		roof.rotation.x = side * 0.3
	for x in [-6.6, -4.4, -2.2, 2.2, 4.4, 6.6]:
		for z in [-3.8, 3.8]:
			_box(node, "white", Vector3(x, 2.75, z), Vector3(1.6, 2.3, 0.16))
			_box(node, "glass", Vector3(x, 2.8, z * 1.03), Vector3(1.3, 1.95, 0.12))
	for x in [-7.2, -3.4, 3.4, 7.2]:
		_box(node, "white", Vector3(x, 2.3, 4.0), Vector3(0.4, 4.2, 0.45))
	_box(node, "stone", Vector3(0, 4.25, 4), Vector3(3.3, 8.5, 2.2))
	_box(node, "dark", Vector3(0, 1.65, 5.15), Vector3(1.9, 2.9, 0.15))
	_box(node, "white", Vector3(0, 8.6, 4), Vector3(3.8, 0.3, 2.6))
	clock_face(node, Vector3(0, 6.6, 5.2), 1.3)
	_box(node, "blue", Vector3(6.7, 2, 4.35), Vector3(2.5, 3.3, 0.9))
	for i in 5:
		_box(node, "white", Vector3(6.7, 0.65 + i * 0.55, 4.84), Vector3(2.4, 0.06, 0.08))

func school(parent: Node3D, base: Vector3, angle := 0.0) -> void:
	var node := town_house(parent, base, "TrainerSchool", Color("697278"), angle)
	node.scale = Vector3(1.3, 1.1, 1.2)
	_box(node, "stone", Vector3(0, 4.8, 0.5), Vector3(1.8, 3.4, 1.7))
	_box(node, "dark", Vector3(0, 6.5, 0.5), Vector3(2.1, 0.3, 2.0))
	clock_face(node, Vector3(0, 5.4, 1.4), 0.6)

func clock_face(parent: Node3D, base: Vector3, radius: float) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.12
	disk.radial_segments = 32
	geo._put(parent, disk, materials.gold, base, Vector3.ONE).rotation.x = PI / 2
	geo._put(parent, disk, materials.white, base + Vector3(0, 0, 0.1), Vector3(0.87, 1, 0.87)).rotation.x = PI / 2
	_box(parent, "dark", base + Vector3(0, radius * 0.25, 0.2), Vector3(0.06, radius * 0.55, 0.06))
	_box(parent, "dark", base + Vector3(radius * 0.18, 0, 0.2), Vector3(radius * 0.4, 0.06, 0.06))

func fountain(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "TownFountain", base)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.0
	ring.outer_radius = 2.45
	ring.rings = 8
	geo._put(node, ring, materials.stone, Vector3(0, 0.35, 0), Vector3(1, 0.8, 1))
	var disk := CylinderMesh.new()
	disk.top_radius = 2.1
	disk.bottom_radius = 2.1
	disk.height = 0.18
	disk.radial_segments = 32
	geo._put(node, disk, geo._stone(Color("65b5c1")), Vector3(0, 0.2, 0), Vector3.ONE)
	_box(node, "stone", Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 0.9))
	geo._put(node, geo._rock_mesh(42), materials.white, Vector3(0, 1.85, 0), Vector3(0.75, 1, 0.75))

func plaza_tree(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "TreeGarden", base)
	_box(node, "stone", Vector3(0, 0.15, 0), Vector3(6.4, 0.3, 6.4))
	_box(node, "green", Vector3(0, 0.32, 0), Vector3(6, 0.12, 6))
	_box(node, "timber", Vector3(0, 1.7, 0), Vector3(0.6, 3.1, 0.6))
	var leaf: Material = geo._stone(Color("41955a"))
	for i in 5:
		var angle := i * TAU / 5
		geo._put(node, geo._rock_mesh(54 + i), leaf, Vector3(sin(angle) * 1.2, 3.5 + (i % 2) * 0.5, cos(angle) * 1.2), Vector3(1.6, 1.6, 1.6))
	geo._put(node, geo._rock_mesh(63), leaf, Vector3(0, 5, 0), Vector3(1.8, 1.9, 1.8))

func ev_training_field(parent: Node3D, base: Vector3) -> void:
	# Long fenced western grass strip, with north/south gates as in the pixel map.
	var node := _group(parent, "EVTrainingField", base)
	for side in [-1, 1]:
		for z in range(-15, 16, 2):
			_box(node, "timber", Vector3(side * 5.5, 0.55, z), Vector3(0.18, 1.1, 0.18))
		for y in [0.35, 0.78]:
			_box(node, "white", Vector3(side * 5.5, y, 0), Vector3(0.12, 0.13, 30.2))
		for z in [-15, 15]:
			for y in [0.35, 0.78]:
				_box(node, "white", Vector3(side * 3.5, y, z), Vector3(4, 0.13, 0.12))
			_box(node, "timber", Vector3(side * 1.5, 0.55, z), Vector3(0.22, 1.1, 0.22))
	var sign := _group(node, "EVTrainingSign", Vector3(7.2, 0, 14))
	_box(sign, "timber", Vector3(0, 0.8, 0), Vector3(0.15, 1.6, 0.15))
	_box(sign, "timber", Vector3(0, 1.55, 0), Vector3(2.0, 1.05, 0.18))
	_box(sign, "white", Vector3(0, 1.55, 0.11), Vector3(1.8, 0.86, 0.07))
	var label := Label3D.new()
	label.text = "EV"
	label.font_size = 64
	label.pixel_size = 0.014
	label.modulate = Color("214959")
	label.outline_size = 0
	label.position = Vector3(0, 1.55, 0.16)
	sign.add_child(label)
