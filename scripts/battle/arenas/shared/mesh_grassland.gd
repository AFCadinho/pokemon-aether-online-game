extends RefCounted
## Shared ordinary mesh terrain, art placement and batched grass. No native addon.
var ground_height := 0.037750244140625
var route_scene: Node3D
var rng := RandomNumberGenerator.new()
static var ground_meshes: Dictionary = {}
static var grass_cache: Dictionary = {}

func _cache_key() -> String:
	return "grassfield"
func _grass_key() -> String:
	return _cache_key()
func _grid_rect() -> Rect2i:
	return Rect2i(-60, -55, 121, 96)
func _height(_x: float, _z: float) -> float:
	return ground_height
func _dirt(_x: float, _z: float) -> float:
	return 0.0
func _has_grass(x: float, z: float) -> bool:
	return Vector2(x, z).length() > 6.0
func _grass_rect() -> Rect2i:
	return Rect2i(-4, -4, 8, 7)

func _start_scene(scene_name: String) -> void:
	route_scene = Node3D.new()
	route_scene.name = scene_name
	route_scene.set_meta("terrain_backend", "mesh")
	route_scene.set_meta("mesh_grid", _grid_rect())
	var skylight := DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-72, 150, 0)
	skylight.light_color = Color("c9e6ff")
	skylight.light_energy = 0.52
	route_scene.add_child(skylight)
	var ground := MeshInstance3D.new()
	ground.name = "MeshTerrain"
	ground.mesh = _ground_mesh()
	route_scene.add_child(ground)

func _ground_mesh() -> ArrayMesh:
	if ground_meshes.has(_cache_key()) and ground_meshes[_cache_key()].get_ref() != null:
		return ground_meshes[_cache_key()].get_ref()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	var grid := _grid_rect()
	for z in range(grid.position.y, grid.end.y):
		for x in range(grid.position.x, grid.end.x):
			vertices.append(Vector3(x, _height(x, z), z))
			var dx := (_height(x + 0.1, z) - _height(x - 0.1, z)) / 0.2
			var dz := (_height(x, z + 0.1) - _height(x, z - 0.1)) / 0.2
			normals.append(Vector3(-dx, 1, -dz).normalized())
			var tangent := Vector3(1, dx, 0).normalized()
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1]))
			colors.append(Color(_dirt(x, z), 0, 0))
	for z in grid.size.y - 1:
		for x in grid.size.x - 1:
			var width := grid.size.x
			var a := z * width + x
			indices.append_array(PackedInt32Array([a, a + 1, a + width, a + 1, a + width + 1, a + width]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/shared/grassland_ground.gdshader")
	material.set_shader_parameter("ground_albedo", load("res://entities/nature/ground/groundA_albedo.png"))
	material.set_shader_parameter("ground_normal", load("res://entities/nature/ground/groundA_normal.png"))
	mesh.surface_set_material(0, material)
	ground_meshes[_cache_key()] = weakref(mesh)
	return mesh

func _grass(parent: Node3D) -> void:
	var grass_batches: Array[MultiMesh] = []
	var grass_material: Material
	if grass_cache.has(_grass_key()):
		for reference in grass_cache[_grass_key()].batches:
			var batch = reference.get_ref()
			if batch != null:
				grass_batches.append(batch)
		grass_material = grass_cache[_grass_key()].material.get_ref()
		if grass_batches.size() != grass_cache[_grass_key()].batches.size() or grass_material == null:
			grass_batches.clear()
	if grass_batches.is_empty():
		var source: Node3D = load("res://entities/nature/grass/grass_3_faces.tscn").instantiate()
		_strip_runtime_helpers(source)
		var card: MeshInstance3D = source.find_child("Card", true, false)
		assert(card != null)
		grass_material = card.get_active_material(0)
		var grass_rng := RandomNumberGenerator.new()
		grass_rng.seed = 22046477
		# Spatial batches allow normal engine frustum culling, without an addon.
		var rect := _grass_rect()
		for bz in range(rect.position.y, rect.end.y):
			for bx in range(rect.position.x, rect.end.x):
				var transforms: Array[Transform3D] = []
				var density := 28 if Vector2(bx * 12, bz * 12).length() < 65 else 12
				for iz in density:
					for ix in density:
						var x := bx * 12.0 + (ix + grass_rng.randf()) * 12.0 / float(density)
						var z := bz * 12.0 + (iz + grass_rng.randf()) * 12.0 / float(density)
						if not _has_grass(x, z):
							continue
						var size := grass_rng.randf_range(0.65, 1.05)
						var basis := Basis(Vector3.UP, grass_rng.randf() * TAU).scaled(Vector3.ONE * size)
						transforms.append(Transform3D(basis, Vector3(x, _height(x, z), z)))
				var batch := MultiMesh.new()
				batch.transform_format = MultiMesh.TRANSFORM_3D
				batch.mesh = card.mesh
				batch.instance_count = transforms.size()
				for i in transforms.size():
					batch.set_instance_transform(i, transforms[i])
				grass_batches.append(batch)
		source.free()
		var references: Array[WeakRef] = []
		for batch in grass_batches:
			references.append(weakref(batch))
		grass_cache[_grass_key()] = {"batches": references, "material": weakref(grass_material)}
	var grass := Node3D.new()
	grass.name = "SharedForestGrass"
	parent.add_child(grass)
	for batch in grass_batches:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = grass_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass.add_child(instance)


func _asset(parent: Node3D, path: String, point: Vector3, size: Vector3, angle := 0.0) -> Node3D:
	var node: Node3D = load("res://entities/nature/" + path + ".tscn").instantiate()
	_strip_runtime_helpers(node)
	node.position = point
	node.scale = size
	node.rotation.y = angle
	parent.add_child(node)
	return node

func _strip_runtime_helpers(node: Node) -> void:
	# Placement/collision helpers have no role in a battle presentation scene.
	node.set_script(null)
	for child in node.get_children():
		if child is CollisionObject3D:
			node.remove_child(child)
			child.free()
		else:
			_strip_runtime_helpers(child)


func _bounds(node: Node, accumulated: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(accumulated * node.get_aabb())
	for child in node.get_children():
		_bounds(child, accumulated, boxes)

func _shades_battle(node: Node3D) -> bool:
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var sun_ray := Basis.from_euler(Vector3(-45, -30, 0) * PI / 180.0) * Vector3.FORWARD
	for box: AABB in boxes:
		var shadow := Rect2()
		for corner in 8:
			var p := box.get_endpoint(corner)
			p += sun_ray * maxf(0.0, (ground_height - p.y) / sun_ray.y)
			var projected := Vector2(p.x, p.z)
			shadow = Rect2(projected, Vector2.ZERO) if corner == 0 else shadow.expand(projected)
		if shadow.intersects(Rect2(-6, -4, 12, 8)):
			return true
	return false
