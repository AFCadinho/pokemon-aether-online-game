extends Node3D
## A small battle-local Substitute doll, using the textured model credited in assets/models/battle/substitute/SOURCE.md.
var clock := 0.0
var hit_left := 0.0
var body: Node3D
var visual_bounds := AABB()
var speed_provider: Callable
var idle_scale := 1.0

func build(height: float, speed: Callable) -> void:
	speed_provider = speed
	idle_scale = clampf(height * 0.72, 0.8, 1.6)
	body = Node3D.new()
	add_child(body)
	var model := preload("res://assets/models/battle/substitute/substitute_doll.fbx").instantiate() as Node3D
	body.add_child(model)
	# The downloaded doll is 1.4466 units tall, with its feet just below zero.
	# Match the former doll's one-unit envelope and retain the species-relative scale.
	model.scale = Vector3.ONE / 1.446603
	model.position.y = 0.013297 / 1.446603
	# Cache the normalized doll envelope in body space, independent of its pop-in/hit motion.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (body.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		visual_bounds = visual_bounds.merge(box) if visual_bounds.has_volume() else box
	body.scale = Vector3.ONE * idle_scale

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
