extends "res://tools/sprite_factory/phase5_godot_review.gd"
## A hidden source accessory must not change framing; enabling it must.
func _run() -> void:
 var model := Node3D.new()
 root.add_child(model)
 var body := MeshInstance3D.new()
 body.mesh = BoxMesh.new()
 model.add_child(body)
 var accessory_root := Node3D.new()
 model.add_child(accessory_root)
 var accessory := MeshInstance3D.new()
 accessory.mesh = BoxMesh.new()
 accessory.position.x = 100.0
 accessory_root.add_child(accessory)
 accessory_root.hide()
 var hidden := _bounds(model)
 assert(hidden.size.is_equal_approx(Vector3.ONE), "Hidden parent expanded review bounds")
 accessory_root.show()
 var visible := _bounds(model)
 assert(visible.size.x > 100.0, "Visible accessory was excluded")
 accessory.hide()
 assert(_bounds(model).size.is_equal_approx(hidden.size), "Hidden mesh expanded review bounds")
 assert(_axis_aligned(Basis.from_euler(Vector3(PI / 2.0, 0, 0))))
 assert(not _axis_aligned(Basis.from_euler(Vector3(0, 0.37, 0))))
 # A triangle's rotated AABB overestimates it; arbitrary rotations must still
 # be measured from vertices, otherwise a false floor error can result.
 var triangle := ArrayMesh.new()
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(2,0,0), Vector3(0,1,0)])
 triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 body.mesh = triangle
 body.rotation.z = 0.37
 var measured := _bounds(model)
 var expected := AABB(body.global_transform * Vector3.ZERO, Vector3.ZERO)
 for v in [Vector3(2,0,0), Vector3(0,1,0)]:expected = expected.expand(body.global_transform * v)
 assert(measured.position.is_equal_approx(expected.position) and measured.size.is_equal_approx(expected.size))
 model.free()
 print("REVIEW_VISIBLE_BOUNDS_PASS")
 quit()
