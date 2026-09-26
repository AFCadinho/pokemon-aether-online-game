extends "res://scripts/battle/arenas/shared/route_landmarks.gd"
## Map-native architecture for the city, golden bridge and Sea Cottage.
func _init(world: Node3D) -> void:
	super(world)
	for pair in [["gold", "d9ae45"], ["gold_light", "f2d57a"], ["green", "448c77"],
		["brick", "957b61"], ["paving", "b3bec5"]]:
		materials[pair[0]] = geo._stone(Color(pair[1]))

func nugget_bridge(parent: Node3D, base: Vector3, length: float) -> void:
	var node := _group(parent, "NuggetBridge", base)
	# Broad golden planks, dark structural beams, capped posts and two rail levels.
	_box(node, "timber", Vector3(0, -0.42, 0), Vector3(5.9, 0.7, length))
	for i in int(length):
		_box(node, "gold", Vector3(0, -0.035, -length * 0.5 + i + 0.5), Vector3(5.8, 0.18, 0.94))
	for side in [-1, 1]:
		_box(node, "gold_light", Vector3(side * 2.95, 0.10, 0), Vector3(0.22, 0.24, length))
		for y in [0.55, 1.18]:
			_box(node, "gold", Vector3(side * 3.05, y, 0), Vector3(0.16, 0.17, length))
		for i in range(0, int(length) + 1, 3):
			var z := -length * 0.5 + i
			_box(node, "gold", Vector3(side * 3.05, 0.65, z), Vector3(0.33, 1.6, 0.33))
			_box(node, "gold_light", Vector3(side * 3.05, 1.42, z), Vector3(0.46, 0.18, 0.46))
		for z in [-length * 0.5, length * 0.5]:
			_box(node, "gold", Vector3(side * 3.05, 0.83, z), Vector3(0.68, 1.9, 0.68))
			var sphere := SphereMesh.new()
			sphere.radius = 0.38
			sphere.height = 0.76
			geo._put(node, sphere, materials.gold_light, Vector3(side * 3.05, 2.04, z), Vector3.ONE)
		for z in [-length * 0.28, length * 0.28]:
			_box(node, "stone", Vector3(side * 2.2, -1.1, z), Vector3(0.85, 2.2, 1.2))

func cottage(parent: Node3D, base: Vector3, label: String, angle := 0.0, sea_cottage := false) -> void:
	var blue: Material = materials.blue
	if sea_cottage:
		materials.blue = materials.green
	house(parent, base)
	materials.blue = blue
	var node: Node3D = parent.get_child(-1)
	node.name = label
	node.rotation.y = angle
	# Rear and side windows keep homes finished when seen from the orbit's reverse side.
	for x in [-1.8, 1.8]:
		_box(node, "white", Vector3(x, 1.95, -2.2), Vector3(1.25, 1.4, 0.15))
		_box(node, "glass", Vector3(x, 1.95, -2.29), Vector3(1.0, 1.16, 0.04))
	for side in [-1, 1]:
		for z in [-1.1, 1.1]:
			_box(node, "white", Vector3(side * 2.87, 1.95, z), Vector3(0.15, 1.4, 1.1))
			_box(node, "glass", Vector3(side * 2.96, 1.95, z), Vector3(0.04, 1.15, 0.85))
	if sea_cottage:
		# Bill's map silhouette: green roof, tall chimney, enclosed front garden.
		_box(node, "stone", Vector3(1.8, 5.0, -0.8), Vector3(0.82, 1.8, 0.82))
		_box(node, "white", Vector3(0, 2.85, 2.28), Vector3(1.8, 0.4, 0.12))
		_ball_emblem(node, Vector3(0, 2.87, 2.4))

func lamp(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "RiverLamp", base)
	_box(node, "stone", Vector3(0, 0.16, 0), Vector3(0.55, 0.32, 0.55))
	_box(node, "blue", Vector3(0, 1.4, 0), Vector3(0.17, 2.8, 0.17))
	_box(node, "white", Vector3(0, 2.8, 0), Vector3(0.5, 0.65, 0.5))
	_box(node, "blue", Vector3(0, 3.18, 0), Vector3(0.65, 0.15, 0.65))

func bench(parent: Node3D, base: Vector3, angle := 0.0) -> void:
	var node := _group(parent, "ParkBench", base)
	node.rotation.y = angle
	for x in [-0.85, 0.85]:
		_box(node, "dark", Vector3(x, 0.35, 0), Vector3(0.12, 0.7, 0.65))
	for z in [-0.25, 0, 0.25]:
		_box(node, "timber", Vector3(0, 0.65, z), Vector3(2.2, 0.12, 0.20))
	for y in [1.0, 1.26]:
		_box(node, "timber", Vector3(0, y, -0.32), Vector3(2.2, 0.2, 0.13))

func city_gym(parent: Node3D, base: Vector3, angle: float) -> void:
	var node := _group(parent, "CeruleanGym", base)
	node.rotation.y = angle
	_box(node, "stone", Vector3(0, 0.2, 0), Vector3(8.4, 0.4, 5.8))
	_box(node, "wall", Vector3(0, 1.85, 0), Vector3(8, 3.3, 5.4))
	for x in [-2.7, 2.7]:
		_box(node, "blue", Vector3(x, 1.8, 2.73), Vector3(2.05, 2.0, 0.16))
		_box(node, "glass", Vector3(x, 1.85, 2.83), Vector3(1.72, 1.55, 0.06))
		_box(node, "white", Vector3(x, 1.85, 2.88), Vector3(0.10, 1.6, 0.04))
	_box(node, "blue", Vector3(0, 1.5, 2.76), Vector3(1.65, 2.5, 0.16))
	for tier in 3:
		geo._put(node, _bevel_prism(4.45 - tier * 0.17, 3.05 - tier * 0.17, 0.5, 0.28), materials.gold,
			Vector3(0, 3.45 + tier * 0.28, 0), Vector3.ONE)
	_box(node, "white", Vector3(0, 3.08, 2.98), Vector3(2.1, 0.7, 0.16))
	_ball_emblem(node, Vector3(0, 3.10, 3.1))
