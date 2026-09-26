extends "res://scripts/battle/arenas/shared/geometry.gd"
## Authored gym architecture, shared by the main and material-response viewports.
## Walls/roof do not occlude the locked neutral actor lighting.
const Surface = preload("res://scripts/battle/arenas/shared/gym_surface.gdshader")
var unit_box := BoxMesh.new()

func group(parent: Node3D, label: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = pos
	parent.add_child(node)
	return node

func matte(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic_specular = 0.18
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func surface(color: Color, joints: Color, pattern := 0, cell := 1.2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Surface
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("joint_color", joints)
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("cell_size", cell)
	return material

func box(parent: Node3D, material: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	return prop(parent, unit_box, material, pos, size)

func prop(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size := Vector3.ONE) -> MeshInstance3D:
	var node := _put(parent, mesh, material, pos, size)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func cylinder(parent: Node3D, material: Material, pos: Vector3, radius: float, height: float, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 24
	return prop(parent, mesh, material, pos)

func ring(parent: Node3D, material: Material, pos: Vector3, radius: float, thickness: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 8
	return prop(parent, mesh, material, pos)

func beam(parent: Node3D, material: Material, a: Vector3, b: Vector3, thickness: float) -> void:
	var node := box(parent, material, (a + b) * 0.5, Vector3(thickness, a.distance_to(b), thickness))
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func emblem(parent: Node3D, material: Material, pos: Vector3, radius: float) -> void:
	var node := group(parent, "LeagueEmblem", pos)
	ring(node, material, Vector3.ZERO, radius, 0.055).scale.y = 0.15
	box(node, material, Vector3.ZERO, Vector3(radius * 2.0, 0.014, 0.10))
	cylinder(node, material, Vector3(0, 0.012, 0), radius * 0.23, 0.022)

func hall(parent: Node3D, wall: Material, trim: Material, ceiling: Material) -> void:
	var shell := group(parent, "EnclosedHall")
	box(shell, wall, Vector3(-26, 9.5, 0), Vector3(1, 20, 62))
	box(shell, wall, Vector3(26, 9.5, 0), Vector3(1, 20, 62))
	box(shell, wall, Vector3(0, 9.5, -31), Vector3(52, 20, 1))
	box(shell, wall, Vector3(0, 9.5, 31), Vector3(52, 20, 1))
	box(shell, ceiling, Vector3(0, 20, 0), Vector3(53, 0.6, 63))
	for y in [0.3, 4.4, 13.8, 19.2]:
		box(shell, trim, Vector3(-25.35, y, 0), Vector3(0.35, 0.35, 61))
		box(shell, trim, Vector3(25.35, y, 0), Vector3(0.35, 0.35, 61))
		box(shell, trim, Vector3(0, y, -30.35), Vector3(51, 0.35, 0.35))
		box(shell, trim, Vector3(0, y, 30.35), Vector3(51, 0.35, 0.35))
	for z in [-24, -12, 0, 12, 24]:
		box(shell, trim, Vector3(0, 19.3, z), Vector3(51, 0.8, 0.6))

func lamp(parent: Node3D, pos: Vector3, yaw: float, metal: Material, glow: Material) -> void:
	var node := group(parent, "WallLantern", pos)
	node.rotation.y = yaw
	box(node, metal, Vector3(0, 0, -0.15), Vector3(0.65, 1.3, 0.2))
	box(node, glow, Vector3(0, 0, 0.18), Vector3(0.4, 0.8, 0.4))
	for y in [-0.5, 0.5]:
		box(node, metal, Vector3(0, y, 0.18), Vector3(0.7, 0.18, 0.65))

func stairs(parent: Node3D, material: Material, pos: Vector3, width: float, count: int) -> void:
	var node := group(parent, "DaisStair", pos)
	for i in count:
		var height := (count - i) * 0.25
		box(node, material, Vector3(0, height * 0.5, i * 0.6), Vector3(width, height, 0.62))

func statue(parent: Node3D, pos: Vector3, stone: Material, pedestal: Material) -> void:
	var node := group(parent, "LeagueGuardian", pos)
	box(node, pedestal, Vector3(0, 0.35, 0), Vector3(2.4, 0.7, 2.2))
	box(node, pedestal, Vector3(0, 0.9, 0), Vector3(1.7, 0.5, 1.5))
	prop(node, _rock_mesh(19), stone, Vector3(0, 1.9, 0), Vector3(0.7, 1.0, 0.65))
	prop(node, _rock_mesh(31), stone, Vector3(0, 2.8, 0.1), Vector3(0.55, 0.5, 0.55))
	for side in [-1, 1]:
		var wing := PrismMesh.new()
		wing.size = Vector3(1.4, 1.9, 0.32)
		var sculpture := prop(node, wing, stone, Vector3(side * 0.9, 2.4, -0.25))
		sculpture.rotation.z = side * -0.4
		cylinder(node, stone, Vector3(side * 0.3, 3.35, 0), 0.18, 0.55, 0.0)
