extends "res://tools/sprite_factory/temperate_battle_review.gd"
## Original procedural chamber; no purchased environment assets required.
## Reuses the reviewed neutral actors, shadow quality and idle grounding sweep.

func _surface_height(_pos: Vector3) -> float:
	return 0.0

func _camera() -> void:
	distance = clampf(distance, 8.0, 15.5)
	elevation = minf(elevation, asin(8.0 / distance))
	super._camera()

func _credit_text() -> String:
	return "PokeAether · original cave study · Kanto-inspired\nOpen stone floor · neutral Pokémon materials · isolated preview"

func _stone(color: Color, floor_material := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic_specular = 0.12
	var noise := FastNoiseLite.new()
	noise.seed = 7341
	noise.frequency = 0.035 if floor_material else 0.018
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.89, 0.87, 0.83), Color(1, 0.97, 0.91)]) if floor_material else PackedColorArray([Color(0.75, 0.72, 0.68), Color(1, 0.97, 0.91)])
	texture.color_ramp = gradient
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (0.22 if floor_material else 0.3)
	return material

func _rock_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 12
	sphere.radius = 1.0
	sphere.height = 2.0
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.7
	for i in vertices.size():
		var v := vertices[i]
		vertices[i] = v * (1.0 + noise.get_noise_3dv(v) * 0.22)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _put(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size: Vector3, rotation_y := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = size
	node.rotation.y = rotation_y
	parent.add_child(node)
	return node

func _wall_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 97:
		var theta := TAU * i / 96.0
		for row in 17:
			var y := row * 0.65 - 0.3
			var radius := 18.0 + 0.85*sin(theta*11 + y*0.45) + 0.35*sin(theta*23 - y*1.5) + 0.6*sin(y*2.5)
			vertices.append(Vector3(sin(theta)*radius, y, cos(theta)*radius))
	for i in 96:
		for row in 16:
			if (i >= 41 and i <= 46 or i >= 69 and i <= 74) and row < 8:
				continue
			var a := i*17 + row
			var b := a + 1
			var c := a + 17
			indices.append_array(PackedInt32Array([a, c, b, c, c+1, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	return surface.commit()

func _make_forest() -> Node3D:
	# Both passes build the same deterministic chamber. Enclosing art does not
	# cast over the fighters; self/cast shadows on the Pokémon remain enabled.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in stage.world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0 / 3.0
		if child is WorldEnvironment:
			child.environment.background_color = Color("171619")
	var chamber := Node3D.new()
	chamber.name = "KantoCaveStudy"
	var stone := _stone(Color("68615c"))
	var lighter_stone := _stone(Color("81776a"))
	var ground := _stone(Color("8c7b65"), true)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 32
	floor_mesh.bottom_radius = 32
	floor_mesh.height = 0.5
	floor_mesh.radial_segments = 96
	_put(chamber, floor_mesh, ground, Vector3(0, -0.25, 0), Vector3.ONE)
	var rocks: Array[ArrayMesh] = []
	for i in 7:
		rocks.append(_rock_mesh(190 + i))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8917
	var wall := _put(chamber, _wall_mesh(), stone, Vector3.ZERO, Vector3.ONE)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ceiling := PlaneMesh.new()
	ceiling.size = Vector2(70, 70)
	var ceiling_material := _stone(Color("383431"))
	ceiling_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var roof := _put(chamber, ceiling, ceiling_material, Vector3(0, 10, 0), Vector3.ONE)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Receding stone arches surround dark, genuinely recessed tunnel ends.
	for center_index in [22, 36]:
		var theta: float = TAU * center_index / 48.0
		var outward := Vector3(sin(theta), 0, cos(theta))
		var sideways := Vector3(cos(theta), 0, -sin(theta))
		for depth in 5:
			var midpoint := outward * (18 + depth * 2.3)
			var tunnel_stone := _stone(Color("665d52") * (1.0 - depth * 0.15))
			for side in [-1, 1]:
				_put(chamber, rocks[depth % 7], tunnel_stone, midpoint + sideways * side * 3.5 + Vector3.UP*1.8, Vector3(1.4, 2.7, 2.0), theta)
			_put(chamber, rocks[(depth+2) % 7], tunnel_stone, midpoint + Vector3.UP*4.6, Vector3(4.1, 1.5, 1.8), theta)
		var dark := StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color("101013")
		var end := BoxMesh.new()
		_put(chamber, end, dark, outward*29 + Vector3.UP*2.3, Vector3(8, 6, 1), theta)
	# Peripheral rubble only: the radius-7 fighting area stays completely clear.
	for i in 85:
		var theta := rng.randf_range(0, TAU)
		var radius := rng.randf_range(10.5, 16)
		var size := rng.randf_range(0.18, 0.65)
		_put(chamber, rocks[i % 7], lighter_stone, Vector3(sin(theta)*radius, size*0.25, cos(theta)*radius), Vector3(size*1.5, size*0.65, size), theta)
	# Small worn stalagmites rather than fantasy crystals.
	for i in 12:
		var theta := TAU * (i + 0.35) / 12
		var spike := CylinderMesh.new()
		spike.top_radius = 0.08
		spike.bottom_radius = 0.45
		spike.height = rng.randf_range(0.8, 1.8)
		spike.radial_segments = 12
		_put(chamber, spike, stone, Vector3(sin(theta)*14.8, spike.height/2, cos(theta)*14.8), Vector3.ONE)
	print("CAVE_GEOMETRY_OK children=", chamber.get_child_count())
	return chamber
