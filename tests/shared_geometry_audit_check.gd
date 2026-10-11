extends SceneTree
const Geometry = preload("res://tools/sprite_factory/model_geometry_audit.gd")
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

func mesh_with(uv: float, color: Color) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(uv, 0), Vector2.UP])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.surface_set_material(0, material)
	return mesh

func library_with(time: float) -> AnimationLibrary:
	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("Skeleton3D:bone"))
	animation.position_track_insert_key(track, time, Vector3.ONE)
	var library := AnimationLibrary.new()
	library.add_animation("idle", animation)
	return library

func _init() -> void:
	var normal := mesh_with(1.0, Color.RED)
	var shiny := mesh_with(1.0, Color.BLUE)
	assert(Geometry.mesh_key(normal) == Geometry.mesh_key(shiny))
	assert(Audit.signature(normal) != Audit.signature(shiny))
	assert(Geometry.mesh_key(normal) != Geometry.mesh_key(mesh_with(0.5, Color.RED)), "UV changes cannot disappear")
	var stripped := Geometry.bare_mesh(normal)
	assert(stripped.surface_get_material(0) == null and normal.surface_get_material(0) != null)
	assert(Geometry.mesh_key(normal) == Geometry.mesh_key(stripped))
	stripped.resource_local_to_scene = true
	assert(Geometry.mesh_key(normal) != Geometry.mesh_key(stripped), "Per-instance ownership must remain in the key")
	var library := library_with(0.0)
	assert(Audit.signature(library) == Audit.signature(library_with(0.0)))
	assert(Audit.signature(library) != Audit.signature(library_with(0.1)), "Animation timing remains exact")
	var actor := Node3D.new()
	var player := AnimationPlayer.new()
	actor.add_child(player)
	player.owner = actor
	player.add_animation_library("", library)
	var scene := PackedScene.new()
	assert(scene.pack(actor) == OK)
	assert(Geometry.bindings(scene).libraries.size() == 1, "Godot serializes libraries as libraries/NAME properties")
	actor.free()
	assert(Geometry.sensitive_tracks(library).is_empty())
	library.get_animation("idle").track_set_path(0, NodePath("Body:mesh:surface_0/material:albedo_color"))
	assert(Geometry.sensitive_tracks(library).size() == 1)
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var other := skin.duplicate() as Skin
	other.set_bind_pose(0, Transform3D(Basis.IDENTITY, Vector3.UP))
	assert(Audit.signature(skin) != Audit.signature(other), "Bind poses remain exact")
	print("SHARED_GEOMETRY_AUDIT_CHECK_OK material_only=true uv_mutation=true ownership=true animation_timing=true sensitive_tracks=true bind_pose=true")
	quit()
