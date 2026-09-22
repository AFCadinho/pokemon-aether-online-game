extends "res://scripts/battle/arenas/route_22_arena.gd"
## Review alternative: same authored landmarks and art, ordinary mesh terrain.
## No Terrain3D instance, native extension, terrain regions or runtime painting.
const BASE_HEIGHT := 0.037750244140625
static var ground_meshes: Dictionary = {}
static var grass_batches: Array[MultiMesh] = []
static var grass_material: Material

func build(_camera: Camera3D, _scene_path := "") -> Node3D:
	ground_height = BASE_HEIGHT
	rng.seed = 220464
	route_scene = Node3D.new()
	route_scene.name = "Route22MeshWater" if water_battle else "Route22MeshMeadow"
	route_scene.set_meta("source_map", "kanto_route_22")
	route_scene.set_meta("terrain_backend", "mesh")
	var skylight := DirectionalLight3D.new()
	skylight.rotation_degrees = Vector3(-72, 150, 0)
	skylight.light_color = Color("c9e6ff")
	skylight.light_energy = 0.52
	skylight.shadow_enabled = false
	route_scene.add_child(skylight)
	var ground := MeshInstance3D.new()
	ground.name = "MeshTerrain"
	ground.mesh = _ground_mesh()
	route_scene.add_child(ground)
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
	var north := 4.2 * smoothstep(18.0, 20.0, -z) + 3.5 * smoothstep(28.0, 31.0, -z)
	var depth := -WATER_LEVEL + FIGHT_WATER_DEPTH if water_battle else 1.2
	var basin := depth * (1.0 - smoothstep(1.0 if water_battle else 0.8, 1.15, _pond_distance(x, z)))
	return BASE_HEIGHT + north - basin

func _clear_grass(_terrain, _pos: Vector3, _radius: float) -> void:
	pass # Grass exclusion is applied once when generating the shared batches.

func _path_distance(x: float, z: float) -> float:
	return minf(absf(z - _route_z(x)), absf(x - 5.0) if z < -11 else 100.0)

func _ground_mesh() -> ArrayMesh:
	if ground_meshes.has(water_battle):
		return ground_meshes[water_battle]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	for z in range(-55, 41):
		for x in range(-60, 61):
			vertices.append(Vector3(x, _height(x, z), z))
			var dx := (_height(x + 0.1, z) - _height(x - 0.1, z)) / 0.2
			var dz := (_height(x, z + 0.1) - _height(x, z - 0.1)) / 0.2
			normals.append(Vector3(-dx, 1, -dz).normalized())
			var tangent := Vector3(1, dx, 0).normalized()
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1]))
			var dirt := maxf(1.0 - smoothstep(1.0, 2.0, _path_distance(x, z)),
				1.0 - smoothstep(1.0, 1.16, _pond_distance(x, z)))
			colors.append(Color(dirt, 0, 0))
	for z in 95:
		for x in 120:
			var a := z * 121 + x
			indices.append_array(PackedInt32Array([a, a + 1, a + 121, a + 1, a + 122, a + 121]))
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
	material.shader = preload("res://scripts/battle/arenas/route_22_mesh_ground.gdshader")
	material.set_shader_parameter("ground_albedo", load("res://entities/nature/ground/groundA_albedo.png"))
	material.set_shader_parameter("ground_normal", load("res://entities/nature/ground/groundA_normal.png"))
	mesh.surface_set_material(0, material)
	ground_meshes[water_battle] = mesh
	return mesh

func _grass(parent: Node3D) -> void:
	if grass_batches.is_empty():
		var source: Node3D = load("res://entities/nature/grass/grass_3_faces.tscn").instantiate()
		var card: MeshInstance3D = source.find_child("Card", true, false)
		assert(card != null)
		grass_material = card.get_active_material(0)
		var grass_rng := RandomNumberGenerator.new()
		grass_rng.seed = 22046477
		# Spatial batches allow normal engine frustum culling, without an addon.
		for bz in range(-4, 3):
			for bx in range(-4, 4):
				var transforms: Array[Transform3D] = []
				for iz in 28:
					for ix in 28:
						var x := bx * 12.0 + (ix + grass_rng.randf()) * 12.0 / 28.0
						var z := bz * 12.0 + (iz + grass_rng.randf()) * 12.0 / 28.0
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
	var grass := Node3D.new()
	grass.name = "SharedForestGrass"
	parent.add_child(grass)
	for batch in grass_batches:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = grass_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grass.add_child(instance)

func _has_grass(x: float, z: float) -> bool:
	return (Vector2(x, z).length() > 6.0 and _pond_distance(x, z) > 1.20
		and _path_distance(x, z) > 1.8
		and not (absf(x + 19.0) < 2.4 and z >= -16 and z <= 5))
