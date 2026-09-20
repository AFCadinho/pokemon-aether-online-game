extends RefCounted
## Shared geometry helpers; no battle state or SceneTree ownership.
var stage: Dictionary

func _init(world: Node3D) -> void:
	stage = {"world": world}

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
