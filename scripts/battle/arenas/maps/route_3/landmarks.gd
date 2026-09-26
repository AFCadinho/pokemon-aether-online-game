extends RefCounted
## Original mesh landmarks adapted from Route 3's pixel-map silhouettes.
const Geometry = preload("res://scripts/battle/arenas/shared/geometry.gd")
var geo: RefCounted
var box := BoxMesh.new()
var materials: Dictionary = {}

func _init(world: Node3D) -> void:
	geo = Geometry.new(world)
	for pair in [["stone", "ab9b80"], ["cliff", "906b49"], ["timber", "79543b"],
		["white", "e5dfc9"], ["wall", "c3cbc4"], ["blue", "468aaf"],
		["glass", "214959"], ["red", "bc3d2b"], ["roof_edge", "ed7a48"], ["dark", "17252b"]]:
		materials[pair[0]] = geo._stone(Color(pair[1]))

func _group(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node

func _box(parent: Node3D, material: String, point: Vector3, size: Vector3) -> MeshInstance3D:
	return geo._put(parent, box, materials[material], point, size)

func stairs(parent: Node3D, base: Vector3, rise: float, label: String) -> void:
	var node := _group(parent, label, base)
	for i in 10:
		var height := (i + 1) * rise / 10.0
		var step := _box(node, "stone", Vector3(0, height * 0.5 + 0.015, -(i + 0.5) * 0.6), Vector3(4.3, height + 0.03, 0.6))
		step.name = "Step%d" % i
		for side in [-1, 1]:
			_box(node, "timber", Vector3(side * 2.28, height + 0.15, -(i + 0.5) * 0.6), Vector3(0.22, 0.3, 0.61))
	for side in [-1, 1]:
		for i in [0, 4, 9]:
			_box(node, "timber", Vector3(side * 2.28, (i + 1) * rise / 10.0 + 0.4, -(i + 0.5) * 0.6), Vector3(0.24, 0.8, 0.24))

func fence(parent: Node3D, base: Vector3, length: float) -> void:
	var node := _group(parent, "TerraceFence", base)
	for i in range(0, int(length) + 1, 2):
		_box(node, "timber", Vector3(i, 0.45, 0), Vector3(0.18, 0.9, 0.18))
	for y in [0.32, 0.66]:
		_box(node, "white", Vector3(length * 0.5, y, 0), Vector3(length, 0.11, 0.13))

func pokemon_center(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "PokemonCenter", base)
	# Cream chamfered building, blue frontage and stepped red roof from the map.
	geo._put(node, _bevel_prism(3.7, 2.4, 0.30, 0.30), materials.stone, Vector3(0, 0.05, 0), Vector3.ONE)
	geo._put(node, _bevel_prism(3.3, 2.1, 0.5, 2.6), materials.wall, Vector3(0, 0.30, 0), Vector3.ONE)
	for x in [-2.0, 2.0]:
		_box(node, "blue", Vector3(x, 1.40, 2.105), Vector3(1.65, 1.55, 0.12))
		_box(node, "glass", Vector3(x, 1.48, 2.19), Vector3(1.36, 1.05, 0.04))
		for dx in [-0.72, 0.0, 0.72]:
			_box(node, "white", Vector3(x + dx, 1.48, 2.23), Vector3(0.07, 1.2, 0.08))
		_box(node, "white", Vector3(x, 0.91, 2.23), Vector3(1.52, 0.09, 0.10))
		_box(node, "white", Vector3(x, 2.05, 2.23), Vector3(1.52, 0.09, 0.10))
	_box(node, "dark", Vector3(0, 1.28, 2.14), Vector3(1.46, 1.95, 0.15))
	for side in [-1, 1]:
		_box(node, "blue", Vector3(side * 0.33, 1.27, 2.25), Vector3(0.61, 1.83, 0.05))
		_box(node, "white", Vector3(side * 0.11, 1.18, 2.29), Vector3(0.04, 0.35, 0.06))
	_box(node, "stone", Vector3(0, 0.15, 2.63), Vector3(2.25, 0.30, 0.9))
	for tier in 3:
		var inset := tier * 0.18
		geo._put(node, _bevel_prism(3.65 - inset, 2.5 - inset, 0.6, 0.28),
			materials.roof_edge if tier == 0 else materials.red, Vector3(0, 2.90 + tier * 0.26, 0), Vector3.ONE)
	geo._put(node, _barrel_roof(), materials.red, Vector3(0, 3.4, 0), Vector3.ONE)
	# Roof seams and white fascia make the center legible at battle-camera scale.
	for x in [-3.05, -2.1, 2.1, 3.05]:
		_box(node, "roof_edge", Vector3(x, 3.48, 0), Vector3(0.055, 0.06, 3.65))
	_box(node, "red", Vector3(0, 2.87, 2.63), Vector3(2.2, 0.62, 0.24))
	_box(node, "white", Vector3(0, 2.54, 2.66), Vector3(6.7, 0.09, 0.14))
	_ball_emblem(node, Vector3(0, 2.9, 2.78))

func _ball_emblem(parent: Node3D, pos: Vector3) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = 0.30
	disk.bottom_radius = 0.30
	disk.height = 0.055
	disk.radial_segments = 24
	var outer: MeshInstance3D = geo._put(parent, disk, materials.white, pos, Vector3.ONE)
	outer.rotation_degrees.x = 90
	_box(parent, "dark", pos + Vector3(0, 0, 0.04), Vector3(0.60, 0.065, 0.04))
	var inner: MeshInstance3D = geo._put(parent, disk, materials.dark, pos + Vector3(0, 0, 0.07), Vector3(0.42, 1, 0.42))
	inner.rotation_degrees.x = 90
	var button: MeshInstance3D = geo._put(parent, disk, materials.white, pos + Vector3(0, 0, 0.11), Vector3(0.25, 1, 0.25))
	button.rotation_degrees.x = 90

func cave(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "MtMoonEntrance", base)
	for i in 3:
		geo._put(node, geo._rock_mesh(311 + i), materials.cliff,
			Vector3((i - 1) * 4.0, 1.8, -2.8), Vector3(3.7, 2.4, 3.0))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("101514")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector3] = [Vector3(-1.65, 0, 1.15), Vector3(1.65, 0, 1.15)]
	for i in 17:
		var angle := PI * i / 16.0
		outline.append(Vector3(cos(angle) * 1.65, 1.45 + sin(angle) * 1.65, 1.15))
	for i in range(1, outline.size() - 1):
		for v in [outline[0], outline[i], outline[i + 1]]:
			st.add_vertex(v)
	st.generate_normals()
	var opening: MeshInstance3D = geo._put(node, st.commit(), dark, Vector3.ZERO, Vector3.ONE)
	opening.name = "TunnelOpening"
	for i in 11:
		var angle := PI * i / 10.0
		geo._put(node, geo._rock_mesh(390 + i), materials.cliff,
			Vector3(cos(angle) * 2.03, 1.45 + sin(angle) * 2.03, 1.05), Vector3(0.60, 0.65, 0.7))
	for side in [-1, 1]:
		for i in 2:
			geo._put(node, geo._rock_mesh(410 + i), materials.cliff,
				Vector3(side * 2.02, 0.4 + i * 0.7, 1.05), Vector3(0.6, 0.6, 0.75))
	_box(node, "stone", Vector3(0, 0.045, 1.45), Vector3(3.3, 0.09, 1.0))

func signpost(parent: Node3D, base: Vector3) -> void:
	var node := _group(parent, "MtMoonSign", base)
	_box(node, "timber", Vector3(0, 0.70, 0), Vector3(0.18, 1.4, 0.18))
	_box(node, "timber", Vector3(0, 1.22, 0), Vector3(1.3, 0.65, 0.18))
	_box(node, "white", Vector3(0, 1.23, 0.105), Vector3(1.08, 0.46, 0.05))
	# A mountain pictogram remains readable in every UI language.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.4, 1.09, 0.14), Vector3(0, 1.40, 0.14), Vector3(0.4, 1.09, 0.14)]:
		st.add_vertex(v)
	st.generate_normals()
	geo._put(node, st.commit(), materials.cliff, Vector3.ZERO, Vector3.ONE)

func _bevel_prism(x: float, z: float, corner: float, height: float) -> ArrayMesh:
	var ring := [Vector2(-x + corner, -z), Vector2(x - corner, -z), Vector2(x, -z + corner), Vector2(x, z - corner),
		Vector2(x - corner, z), Vector2(-x + corner, z), Vector2(-x, z - corner), Vector2(-x, -z + corner)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		for v in [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(a.x, height, a.y),
			Vector3(b.x, 0, b.y), Vector3(b.x, height, b.y), Vector3(a.x, height, a.y),
			Vector3(0, height, 0), Vector3(a.x, height, a.y), Vector3(b.x, height, b.y)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _barrel_roof() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a := PI * i / 16.0
		var b := PI * (i + 1) / 16.0
		var p := Vector2(cos(a) * 1.20, sin(a) * 1.1)
		var q := Vector2(cos(b) * 1.20, sin(b) * 1.1)
		for v in [Vector3(p.x, p.y, 2.1), Vector3(q.x, q.y, 2.1), Vector3(p.x, p.y, -2.1),
			Vector3(q.x, q.y, 2.1), Vector3(q.x, q.y, -2.1), Vector3(p.x, p.y, -2.1),
			Vector3(0, 0, 2.1), Vector3(q.x, q.y, 2.1), Vector3(p.x, p.y, 2.1),
			Vector3(0, 0, -2.1), Vector3(p.x, p.y, -2.1), Vector3(q.x, q.y, -2.1)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
