extends "res://scripts/battle/arenas/shared/mesh_grassland.gd"
## Art placement and capped ledges for wooded routes with movable battle cameras.
const RouteGeometry = preload("res://scripts/battle/arenas/shared/geometry.gd")

func _sized_asset(parent: Node3D, path: String, point: Vector3, size: Vector3, angle := 0.0) -> Node3D:
	var node := _asset(parent, path, Vector3.ZERO, Vector3.ONE)
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var bounds: AABB = boxes[0]
	for box: AABB in boxes:
		bounds = bounds.merge(box)
	node.scale = size / bounds.size
	node.rotation.y = angle
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	node.position = point - node.basis * pivot
	return node

func _orbit_centers() -> Array[Vector2]:
	return [Vector2.ZERO]

func _plant_tree(parent: Node3D, point: Vector2, index: int) -> void:
	# The full low-pitch, maximum-zoom orbit extends almost 20 units. The crown
	# needs additional clearance, including the separate pond battle origin.
	for center in _orbit_centers():
		if point.distance_to(center) < 24.0:
			return
	_sized_asset(parent, "trees/" + ["fir_tree_a", "spruce_tree_b", "fir_tree_c"][index % 3],
		Vector3(point.x, _height(point.x, point.y), point.y),
		Vector3(4.6, rng.randf_range(7.5, 10.0), 4.6), rng.randf() * TAU)

func _plant_beds(parent: Node3D, centers: Array[Vector2]) -> void:
	var shrubs := Node3D.new()
	shrubs.name = "ShrubBanks"
	parent.add_child(shrubs)
	var flowers := Node3D.new()
	flowers.name = "FlowerBeds"
	parent.add_child(flowers)
	for center in centers:
		for i in 3:
			var p := center + Vector2(i * 0.75 - 0.75, 0.55)
			_sized_asset(shrubs, "shrubs/" + ("boxwood_shrub" if i % 2 else "juniper_shrub"),
				Vector3(p.x, _height(p.x, p.y), p.y), Vector3(1.3, 0.8, 1.2), rng.randf() * TAU)
		for i in 12:
			var p := center + Vector2(rng.randf_range(-1.3, 1.3), rng.randf_range(-0.6, 0.3))
			_sized_asset(flowers, "flowers/" + ("lupine_flower" if i % 3 else "anemone_flower"),
				Vector3(p.x, _height(p.x, p.y), p.y), Vector3.ONE * rng.randf_range(0.35, 0.6), rng.randf() * TAU)

func _ledge(parent: Node3D, label: String, front: float, back: float, rise: float,
	gap: float, angle := 0.0, width := 58) -> void:
	var geo := RouteGeometry.new(route_scene)
	var material := geo._stone(Color("9b7657"))
	material.vertex_color_use_as_albedo = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-width, width):
		if x < gap + 3.6 and x + 1 > gap - 3.6:
			continue
		for band in 4:
			var vertices: Array[Vector3] = []
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var px: float = x + corner.x
				var level: float = (band + corner.y) / 4.0
				var foot := Vector3(px, 0, front).rotated(Vector3.UP, angle)
				var jitter := sin(px * 1.7) * 0.12 + cos(px * 0.83) * 0.08
				var p := Vector3(px, _height(foot.x, foot.z) + rise * level,
					front - level * 1.3 + jitter).rotated(Vector3.UP, angle)
				p.y = maxf(p.y, _height(p.x, p.z) + 0.025)
				vertices.append(p)
			st.set_color(Color(0.89, 0.86, 0.83) if band % 2 == 0 else Color(1, 0.98, 0.94))
			for i in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(vertices[i])
			if band == 3:
				var left := Vector3(x, vertices[2].y, back).rotated(Vector3.UP, angle)
				var right := Vector3(x + 1, vertices[3].y, back).rotated(Vector3.UP, angle)
				left.y = maxf(left.y, _height(left.x, left.z) + 0.025)
				right.y = maxf(right.y, _height(right.x, right.z) + 0.025)
				for p in [vertices[2], left, vertices[3], vertices[3], left, right]:
					st.add_vertex(p)
	st.generate_normals()
	var face := geo._put(parent, st.commit(), material, Vector3.ZERO, Vector3.ONE)
	face.name = label
