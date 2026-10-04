extends Node3D
## A small battle-local Substitute doll, built from native geometry.
var clock := 0.0
var hit_left := 0.0
var body: Node3D
var speed_provider: Callable
var idle_scale := 1.0

func build(height: float, speed: Callable) -> void:
	speed_provider = speed
	idle_scale = clampf(height * 0.72, 0.8, 1.6)
	body = Node3D.new()
	add_child(body)
	var green := _material(Color("5cbd9c"))
	var belly := _material(Color("e5e4b3"))
	var dark := _material(Color("24383a"))
	_sphere(Vector3(0,0.42,0),Vector3(0.7,0.8,0.65),green)
	_sphere(Vector3(0,0.8,0.13),Vector3(0.65,0.52,0.56),green)
	_sphere(Vector3(0,0.38,0.26),Vector3(0.52,0.55,0.15),belly)
	_sphere(Vector3(0,0.7,0.4),Vector3(0.49,0.23,0.21),green)
	for side in [-1.0,1.0]:
		_sphere(Vector3(side*0.3,0.13,0.17),Vector3(0.33,0.24,0.4),green)
		_sphere(Vector3(side*0.32,0.46,0.08),Vector3(0.24,0.33,0.27),green)
		_sphere(Vector3(side*0.18,0.86,0.373),Vector3(0.075,0.095,0.035),dark)
		var ear := CylinderMesh.new()
		ear.top_radius = 0.02
		ear.bottom_radius = 0.13
		ear.height = 0.3
		ear.radial_segments = 8
		_part(ear,Vector3(side*0.21,1.06,0.07),Vector3.ONE,green)
	_sphere(Vector3(0,0.22,-0.38),Vector3(0.32,0.28,0.66),green)
	body.scale = Vector3.ONE * idle_scale

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _sphere(point: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	_part(mesh,point,dimensions,material)

func _part(mesh: Mesh, point: Vector3, dimensions: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = point
	node.scale = dimensions
	body.add_child(node)

func hit() -> void:
	hit_left = 0.18

func cancel_motion() -> void:
	hit_left = 0.0
	if is_instance_valid(body): body.position = Vector3.ZERO

func _process(delta: float) -> void:
	if not is_instance_valid(body): return
	var speed := maxf(float(speed_provider.call()),0.0) if speed_provider.is_valid() else 1.0
	clock += maxf(delta,0.0) * speed
	hit_left = maxf(0.0,hit_left - delta * speed)
	body.position.x = sin(hit_left * 100.0) * 0.08 if hit_left > 0.0 else 0.0
	body.scale = Vector3.ONE * idle_scale * lerpf(0.75,1.0,clampf(clock / 0.15,0.0,1.0))
